<?php

namespace App\Http\Controllers\Api;

use App\Support\UploadStorage;
use App\Models\User;
use App\Support\BrandedEmail;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Validation\ValidationException;
use PragmaRX\Google2FA\Google2FA;
use Throwable;

class AuthController
{
    public function register(Request $request)
    {
        $data = $request->validate([
            'first_name' => ['required', 'string', 'max:80'],
            'last_name' => ['required', 'string', 'max:80'],
            'username' => ['required', 'string', 'min:3', 'max:30', 'regex:/^[A-Za-z0-9._]+$/'],
            'phone' => ['required', 'string', 'max:30'],
            'email' => ['required', 'email', 'max:190', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'terms_accepted' => ['accepted'],
            'device_name' => ['nullable', 'string', 'max:100'],
        ]);

        if (! $this->strongPassword($data['password'])) {
            throw ValidationException::withMessages([
                'password' => ['Use at least eight characters, including one uppercase letter, one number, and one symbol.'],
            ]);
        }

        $phone = $this->normalizedPhone($data['phone']);
        if (! $phone) {
            throw ValidationException::withMessages([
                'phone' => ['Enter a valid Ethiopian mobile number.'],
            ]);
        }

        $username = trim($data['username']);
        $email = mb_strtolower(trim($data['email']));
        $duplicate = DB::table('users')
            ->where('username', $username)
            ->orWhere('phone', $phone)
            ->when($email, fn ($query) => $query->orWhere('email', $email))
            ->exists();

        if ($duplicate) {
            throw ValidationException::withMessages([
                'username' => ['That username, phone, or email is already registered.'],
            ]);
        }

        $userId = DB::table('users')->insertGetId([
            'first_name' => trim($data['first_name']),
            'last_name' => trim($data['last_name']),
            'username' => $username,
            'phone' => $phone,
            'email' => $email,
            'password_hash' => Hash::make($data['password']),
            'role' => 'member',
            'status' => 'active',
            'kyc_status' => 'not_submitted',
            'first_login' => true,
            'twofa_method' => 'authenticator',
            'twofa_enabled' => false,
            'created_at' => now(),
        ]);

        $user = User::query()->findOrFail($userId);

        return response()->json([
            'message' => 'Account created. Sign in to continue, then complete identity verification before joining an Ekub.',
            'user' => $this->userPayload($user),
        ], 201);
    }

    public function forgotPassword(Request $request)
    {
        $data = $request->validate([
            'email' => ['required', 'email', 'max:190'],
        ]);
        $email = mb_strtolower(trim($data['email']));
        $rateKey = 'mobile-api-password-reset:'.sha1($email.'|'.$request->ip());

        if (RateLimiter::tooManyAttempts($rateKey, 3)) {
            return response()->json(['message' => 'Wait before requesting another password code.'], 429);
        }
        RateLimiter::hit($rateKey, 3600);

        $user = User::query()
            ->whereRaw('LOWER(email) = ?', [$email])
            ->where('role', 'member')
            ->first();

        if ($user) {
            $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
            try {
                BrandedEmail::send(
                    $user->email,
                    'Reset your Mekenet Ekub password',
                    'Password reset code',
                    'Use this one-time code to reset your password. It expires in 10 minutes. If you did not request this, you can ignore this email.',
                    $code,
                );
                Cache::put($this->passwordResetKey($email), [
                    'user_id' => (int) $user->id,
                    'code_hash' => Hash::make($code),
                    'attempts' => 0,
                    'expires_at' => now()->addMinutes(10)->timestamp,
                ], now()->addMinutes(10));
            } catch (Throwable $exception) {
                report($exception);
            }
        }

        return response()->json([
            'message' => 'If an account uses that email, a reset code has been sent. Check your inbox.',
        ]);
    }

    public function resetPassword(Request $request)
    {
        $data = $request->validate([
            'email' => ['required', 'email', 'max:190'],
            'code' => ['required', 'regex:/^\d{6}$/'],
            'password' => ['required', 'string', 'min:8', 'max:200', 'confirmed'],
        ]);
        if (! $this->strongPassword($data['password'])) {
            throw ValidationException::withMessages([
                'password' => ['Use at least eight characters, including one uppercase letter, one number, and one symbol.'],
            ]);
        }

        $email = mb_strtolower(trim($data['email']));
        $key = $this->passwordResetKey($email);
        $challenge = Cache::get($key);
        if (! is_array($challenge) || (int) ($challenge['expires_at'] ?? 0) < now()->timestamp) {
            Cache::forget($key);
            return response()->json(['message' => 'That reset code expired or is incorrect. Request a new code.'], 422);
        }
        if ((int) ($challenge['attempts'] ?? 0) >= 5) {
            Cache::forget($key);
            return response()->json(['message' => 'Too many incorrect codes. Request a new reset code.'], 429);
        }
        if (! Hash::check($data['code'], (string) ($challenge['code_hash'] ?? ''))) {
            $challenge['attempts'] = (int) ($challenge['attempts'] ?? 0) + 1;
            $ttl = max(1, (int) $challenge['expires_at'] - now()->timestamp);
            Cache::put($key, $challenge, now()->addSeconds($ttl));
            return response()->json(['message' => 'That reset code is incorrect or expired.'], 422);
        }

        $user = User::query()->whereKey((int) $challenge['user_id'])
            ->whereRaw('LOWER(email) = ?', [$email])
            ->where('role', 'member')
            ->first();
        if (! $user) {
            Cache::forget($key);
            return response()->json(['message' => 'That reset code expired or is incorrect. Request a new code.'], 422);
        }

        DB::transaction(function () use ($user, $data): void {
            DB::table('users')->where('id', $user->id)->update([
                'password_hash' => Hash::make($data['password']),
            ]);
            $user->tokens()->delete();
        });
        Cache::forget($key);

        return response()->json(['message' => 'Password updated. Sign in with your new password.']);
    }

    public function login(Request $request)
    {
        $data = $request->validate([
            'login' => ['required', 'string', 'max:190'],
            'password' => ['required', 'string', 'max:200'],
            'device_name' => ['nullable', 'string', 'max:100'],
        ]);

        $login = trim($data['login']);
        $limitKey = 'mobile-api-login:'.sha1(mb_strtolower($login).'|'.$request->ip());

        if (RateLimiter::tooManyAttempts($limitKey, 8)) {
            return response()->json([
                'message' => 'Too many sign-in attempts. Please wait before trying again.',
            ], 429);
        }

        RateLimiter::hit($limitKey, 60);

        $user = DB::table('users')
            ->where('username', $login)
            ->orWhere('phone', $login)
            ->orWhere('email', mb_strtolower($login))
            ->first();

        if (! $user || ! Hash::check($data['password'], (string) $user->password_hash)) {
            throw ValidationException::withMessages([
                'login' => ['The sign-in details are incorrect.'],
            ]);
        }

        if ($user->status !== 'active') {
            return response()->json(['message' => 'This account is suspended. Contact the site administrator.'], 403);
        }

        if ($user->role !== 'member') {
            return response()->json(['message' => 'Use the website admin or partner portal for this account.'], 403);
        }

        if (! (bool) $user->twofa_enabled) {
            RateLimiter::clear($limitKey);

            return $this->issueToken((int) $user->id, $data['device_name'] ?? null);
        }

        $methods = [];
        $twoFactorSetting = (string) ($user->twofa_method ?? 'authenticator');

        if (in_array($twoFactorSetting, ['email', 'both'], true)
            && filter_var((string) $user->email, FILTER_VALIDATE_EMAIL)) {
            $methods[] = 'email';
        }

        if (in_array($twoFactorSetting, ['authenticator', 'both'], true)
            && trim((string) $user->totp_secret) !== '') {
            $methods[] = 'authenticator';
        }

        if (! $methods) {
            return response()->json([
                'message' => 'Two-step verification is enabled but not configured. Sign in on the website and repair your security settings.',
            ], 422);
        }

        $challengeId = bin2hex(random_bytes(32));
        $challenge = [
            'user_id' => (int) $user->id,
            'methods' => $methods,
            'device_name' => $this->deviceName($data['device_name'] ?? null),
            'attempts' => 0,
            'expires_at' => now()->addMinutes(10)->timestamp,
            'email_hash' => null,
            'resend_after' => 0,
        ];

        if (in_array('email', $methods, true)) {
            try {
                $this->sendEmailCode($challenge);
            } catch (Throwable $exception) {
                report($exception);

                return response()->json([
                    'message' => 'Could not send the email verification code. Check the site email settings and try again.',
                ], 503);
            }
        }

        Cache::put($this->challengeKey($challengeId), $challenge, now()->addMinutes(10));
        RateLimiter::clear($limitKey);

        return response()->json([
            'two_factor_required' => true,
            'challenge_id' => $challengeId,
            'methods' => $methods,
            'email_hint' => in_array('email', $methods, true) ? $this->maskedEmail((string) $user->email) : null,
            'email_notice' => in_array('email', $methods, true)
                ? (config('mail.default') === 'log'
                    ? 'Local mail logging is enabled. Check storage/logs/laravel.log for the code.'
                    : 'A verification code was sent to the email on your account.')
                : null,
            'expires_in_seconds' => 600,
        ]);
    }

    public function verifyTwoFactor(Request $request)
    {
        $data = $request->validate([
            'challenge_id' => ['required', 'string', 'size:64'],
            'method' => ['required', 'in:email,authenticator'],
            'code' => ['required', 'string', 'max:20'],
        ]);

        $key = $this->challengeKey($data['challenge_id']);
        $challenge = Cache::get($key);

        if (! is_array($challenge) || (int) ($challenge['expires_at'] ?? 0) < now()->timestamp) {
            Cache::forget($key);

            return response()->json(['message' => 'This sign-in challenge expired. Sign in again.'], 422);
        }

        if (! in_array($data['method'], $challenge['methods'] ?? [], true)) {
            return response()->json(['message' => 'That verification method is not enabled for this account.'], 422);
        }

        if ((int) ($challenge['attempts'] ?? 0) >= 5) {
            Cache::forget($key);

            return response()->json(['message' => 'Too many incorrect codes. Sign in again to request a new code.'], 429);
        }

        $user = DB::table('users')->where('id', $challenge['user_id'])->first();
        if (! $user || $user->status !== 'active' || $user->role !== 'member') {
            Cache::forget($key);

            return response()->json(['message' => 'This member account is not active.'], 403);
        }

        $code = trim($data['code']);
        $valid = false;

        if ($data['method'] === 'email') {
            $valid = preg_match('/^\d{6}$/', $code) === 1
                && is_string($challenge['email_hash'] ?? null)
                && Hash::check($code, $challenge['email_hash']);
        } else {
            $valid = (new Google2FA())->verifyKey((string) $user->totp_secret, $code);
        }

        if (! $valid) {
            $challenge['attempts'] = (int) ($challenge['attempts'] ?? 0) + 1;
            $ttl = max(1, (int) $challenge['expires_at'] - now()->timestamp);
            Cache::put($key, $challenge, now()->addSeconds($ttl));

            return response()->json([
                'message' => 'That verification code is incorrect or expired.',
                'attempts_remaining' => max(0, 5 - $challenge['attempts']),
            ], 422);
        }

        Cache::forget($key);

        return $this->issueToken((int) $user->id, $challenge['device_name'] ?? null);
    }

    public function resendEmailCode(Request $request)
    {
        $data = $request->validate(['challenge_id' => ['required', 'string', 'size:64']]);
        $key = $this->challengeKey($data['challenge_id']);
        $challenge = Cache::get($key);

        if (! is_array($challenge) || (int) ($challenge['expires_at'] ?? 0) < now()->timestamp) {
            Cache::forget($key);

            return response()->json(['message' => 'This sign-in challenge expired. Sign in again.'], 422);
        }

        if (! in_array('email', $challenge['methods'] ?? [], true)) {
            return response()->json(['message' => 'Email verification is not enabled for this account.'], 422);
        }

        if ((int) ($challenge['resend_after'] ?? 0) > now()->timestamp) {
            return response()->json(['message' => 'Wait before requesting another code.'], 429);
        }

        $rateKey = 'mobile-api-otp-resend:'.$challenge['user_id'];
        if (RateLimiter::tooManyAttempts($rateKey, 5)) {
            return response()->json(['message' => 'Too many codes requested. Try again later.'], 429);
        }

        RateLimiter::hit($rateKey, 3600);

        try {
            $this->sendEmailCode($challenge);
        } catch (Throwable $exception) {
            report($exception);

            return response()->json(['message' => 'Could not send a new email code. Check the site email settings.'], 503);
        }

        $ttl = max(1, (int) $challenge['expires_at'] - now()->timestamp);
        Cache::put($key, $challenge, now()->addSeconds($ttl));

        return response()->json([
            'message' => config('mail.default') === 'log'
                ? 'Local mail logging is enabled. Check storage/logs/laravel.log for the code.'
                : 'A new verification code was sent.',
        ]);
    }

    public function me(Request $request)
    {
        return response()->json(['user' => $this->userPayload($request->user())]);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()?->delete();

        return response()->json(['message' => 'Signed out.']);
    }

    private function issueToken(int $userId, ?string $deviceName)
    {
        $user = User::query()->findOrFail($userId);
        $token = $user->createToken($this->deviceName($deviceName), ['member'], now()->addDays(30));
        DB::table('users')->where('id', $userId)->update(['first_login' => false]);

        return response()->json([
            'token_type' => 'Bearer',
            'access_token' => $token->plainTextToken,
            'expires_at' => now()->addDays(30)->toISOString(),
            'user' => $this->userPayload($user->refresh()),
        ]);
    }

    private function sendEmailCode(array &$challenge): void
    {
        $user = DB::table('users')->where('id', $challenge['user_id'])->first();
        $email = trim((string) ($user->email ?? ''));

        if (! filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new \RuntimeException('The account has no valid email address.');
        }

        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
        BrandedEmail::send(
            $email,
            'Your Mekenet Ekub verification code',
            'Your sign-in code',
            'Enter this one-time code in the Mekenet Ekub app to finish signing in. It expires in 10 minutes. Do not share it with anyone.',
            $code,
        );
        $challenge['email_hash'] = Hash::make($code);
        $challenge['resend_after'] = now()->addSeconds(60)->timestamp;
    }

    private function userPayload(User $user): array
    {
        return [
            'id' => (int) $user->id,
            'first_name' => $user->first_name,
            'last_name' => $user->last_name,
            'username' => $user->username,
            'phone' => $user->phone,
            'email' => $user->email,
            'profile_picture_url' => $user->profile_picture ? app(UploadStorage::class)->url($user->profile_picture) : null,
            'kyc_status' => $user->kyc_status,
            'two_factor_enabled' => (bool) $user->twofa_enabled,
        ];
    }

    private function passwordResetKey(string $email): string
    {
        return 'mobile_api_password_reset:'.hash('sha256', $email);
    }

    private function challengeKey(string $id): string
    {
        return 'mobile_api_login:'.hash('sha256', $id);
    }

    private function deviceName(?string $name): string
    {
        $name = trim((string) $name);

        return $name !== '' ? mb_substr($name, 0, 100) : 'Mekenet Ekub mobile';
    }

    private function normalizedPhone(string $value): ?string
    {
        $digits = preg_replace('/\D+/', '', trim($value));

        if (str_starts_with($digits, '251')) {
            $digits = substr($digits, 3);
        }

        if (str_starts_with($digits, '0')) {
            $digits = substr($digits, 1);
        }

        return preg_match('/^9\d{8}$/', $digits) ? '+251'.$digits : null;
    }

    private function strongPassword(string $password): bool
    {
        return strlen($password) >= 8
            && preg_match('/[A-Z]/', $password) === 1
            && preg_match('/\d/', $password) === 1
            && preg_match('/[^A-Za-z0-9]/', $password) === 1;
    }

    private function maskedEmail(string $email): string
    {
        [$name, $domain] = array_pad(explode('@', $email, 2), 2, '');

        return mb_substr($name, 0, 1).str_repeat('*', max(3, mb_strlen($name) - 1)).'@'.$domain;
    }
}

