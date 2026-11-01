<?php

namespace App\Http\Controllers\Api;

use App\Support\BrandedEmail;
use App\Support\UploadStorage;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;
use PragmaRX\Google2FA\Google2FA;

class ProfileController
{
    public function sendEmailChangeCode(Request $request)
    {
        $user = $request->user();
        $data = $request->validate([
            'email' => ['required', 'email', 'max:190', 'unique:users,email,'.$user->id],
        ]);
        $email = mb_strtolower(trim($data['email']));
        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
        try {
            BrandedEmail::send(
                $email,
                'Verify your new Mekenet Ekub email',
                'Verify your new email',
                'Enter this one-time code to confirm your new email address. It expires in 10 minutes. Do not share it.',
                $code,
            );
        } catch (\Throwable) {
            return response()->json(['message' => 'Could not send a verification code. Check the email settings and try again.'], 503);
        }
        Cache::put('profile_email_change:'.$user->id, [
            'email' => $email,
            'hash' => Hash::make($code),
            'attempts' => 0,
        ], now()->addMinutes(10));

        return response()->json(['message' => 'A verification code was sent to the new email address.']);
    }

    public function verifyEmailChange(Request $request)
    {
        $user = $request->user();
        $data = $request->validate([
            'email' => ['required', 'email', 'max:190'],
            'code' => ['required', 'digits:6'],
        ]);
        $key = 'profile_email_change:'.$user->id;
        $challenge = Cache::get($key);
        $email = mb_strtolower(trim($data['email']));
        if (! is_array($challenge) || ($challenge['email'] ?? null) !== $email) {
            return response()->json(['message' => 'Request a new code for this email address.'], 422);
        }
        if (($challenge['attempts'] ?? 0) >= 5) {
            Cache::forget($key);
            return response()->json(['message' => 'Too many incorrect codes. Request a new code.'], 429);
        }
        if (! Hash::check($data['code'], (string) ($challenge['hash'] ?? ''))) {
            $challenge['attempts'] = (int) $challenge['attempts'] + 1;
            Cache::put($key, $challenge, now()->addMinutes(10));
            return response()->json(['message' => 'That code is incorrect or expired.'], 422);
        }
        if (DB::table('users')->where('email', $email)->where('id', '!=', $user->id)->exists()) {
            Cache::forget($key);
            return response()->json(['message' => 'That email address is already in use.'], 422);
        }
        DB::table('users')->where('id', $user->id)->update([
            'email' => $email,
            'email_verified_at' => now(),
        ]);
        Cache::forget($key);

        return response()->json(['message' => 'New email verified and saved.']);
    }

    public function updateProfile(Request $request)
    {
        $user = $request->user();
        if ($user->kyc_status === 'approved') {
            return response()->json(['message' => 'Your profile information is locked after identity verification. You can still change your profile picture.'], 422);
        }

        if ($request->has('email') && mb_strtolower(trim((string) $request->input('email'))) !== mb_strtolower((string) $user->email)) {
            return response()->json(['message' => 'Verify your new email address before saving it.'], 422);
        }
        $data = $request->validate([
            'first_name' => ['required', 'string', 'max:80'],
            'last_name' => ['required', 'string', 'max:80'],
            'username' => ['required', 'string', 'min:3', 'max:30', 'regex:/^[A-Za-z0-9_.]{3,30}$/', 'unique:users,username,'.$user->id],
            'phone' => ['required', 'string', 'max:40'],
        ]);

        $phone = preg_replace('/\D+/', '', trim($data['phone']));
        if (str_starts_with($phone, '251')) $phone = substr($phone, 3);
        if (str_starts_with($phone, '0')) $phone = substr($phone, 1);
        if (preg_match('/^9\d{8}$/', $phone) !== 1) {
            return response()->json(['message' => 'Enter a valid Ethiopian phone number.'], 422);
        }
        if (DB::table('users')->where('phone', '+251'.$phone)->where('id', '!=', $user->id)->exists()) {
            return response()->json(['message' => 'That phone number is already in use.'], 422);
        }

        DB::table('users')->where('id', $user->id)->update([
            'first_name' => trim($data['first_name']),
            'last_name' => trim($data['last_name']),
            'username' => trim($data['username']),
            'phone' => '+251'.$phone,
        ]);

        return response()->json(['message' => 'Profile information updated.']);
    }

    public function updateProfilePicture(Request $request)
    {
        $data = $request->validate([
            'profile_picture' => ['required', 'image', 'mimes:jpg,jpeg,png,webp,gif', 'max:5120'],
        ]);
        $user = $request->user();
        $oldPicture = $user->profile_picture;
        $picture = $this->storeUpload($data['profile_picture'], 'profile');
        DB::table('users')->where('id', $user->id)->update(['profile_picture' => $picture]);

        if ($oldPicture && str_starts_with($oldPicture, 'profile/')) {
            app(UploadStorage::class)->delete($oldPicture);
        }

        return response()->json(['message' => 'Profile picture updated.']);
    }

    public function paymentMethods(Request $request)
    {
        $rows = DB::table('payment_methods')->where('user_id', $request->user()->id)
            ->orderByDesc('is_default')->orderBy('id')->get()
            ->map(fn ($row) => [
                'id' => (int) $row->id,
                'bank_name' => $row->bank_name,
                'account_name' => $row->account_name,
                'account_number' => str_repeat('•', max(0, strlen($row->account_number) - 4)).substr($row->account_number, -4),
                'is_default' => (bool) $row->is_default,
            ])->values();

        return response()->json(['data' => $rows, 'banks' => config('ekub.banks')]);
    }

    public function addPaymentMethod(Request $request)
    {
        $data = $request->validate([
            'bank_name' => ['required', 'string', 'in:'.implode(',', config('ekub.banks'))],
            'account_number' => ['required', 'string', 'min:6', 'max:26'],
            'account_name' => ['required', 'string', 'min:3', 'max:120'],
        ]);
        $number = preg_replace('/\D/', '', $data['account_number']);
        if (strlen($number) < 6 || strlen($number) > 26) {
            return response()->json(['message' => 'Enter an account number with 6 to 26 digits.'], 422);
        }
        $userId = (int) $request->user()->id;

        if (DB::table('payment_methods')->where('user_id', $userId)->count() >= 5) {
            return response()->json(['message' => 'You can save up to 5 payment methods.'], 422);
        }

        if (DB::table('payment_methods')->where('user_id', $userId)->where('bank_name', $data['bank_name'])->where('account_number', $number)->exists()) {
            return response()->json(['message' => 'That payment method is already saved.'], 422);
        }

        $first = ! DB::table('payment_methods')->where('user_id', $userId)->exists();
        $id = DB::table('payment_methods')->insertGetId([
            'user_id' => $userId,
            'bank_name' => $data['bank_name'],
            'account_number' => $number,
            'account_name' => trim($data['account_name']),
            'is_default' => $first,
            'created_at' => now(),
        ]);

        return response()->json(['message' => 'Payment method saved.', 'id' => (int) $id], 201);
    }

    public function defaultPaymentMethod(Request $request, int $id)
    {
        $userId = (int) $request->user()->id;
        $exists = DB::table('payment_methods')->where('id', $id)->where('user_id', $userId)->exists();
        if (! $exists) return response()->json(['message' => 'Payment method not found.'], 404);

        DB::transaction(function () use ($userId, $id): void {
            DB::table('payment_methods')->where('user_id', $userId)->update(['is_default' => false]);
            DB::table('payment_methods')->where('user_id', $userId)->where('id', $id)->update(['is_default' => true]);
        });

        return response()->json(['message' => 'Default payment method updated.']);
    }

    public function deletePaymentMethod(Request $request, int $id)
    {
        $userId = (int) $request->user()->id;
        $deleted = DB::table('payment_methods')->where('user_id', $userId)->where('id', $id)->delete();
        if (! $deleted) return response()->json(['message' => 'Payment method not found.'], 404);

        $remaining = DB::table('payment_methods')->where('user_id', $userId)->orderBy('id')->get();
        if ($remaining->isNotEmpty() && ! $remaining->contains(fn ($row) => (bool) $row->is_default)) {
            DB::table('payment_methods')->where('id', $remaining->first()->id)->update(['is_default' => true]);
        }

        return response()->json(['message' => 'Payment method removed.']);
    }

    public function applications(Request $request)
    {
        return response()->json([
            'data' => DB::table('ekub_applications')->where('user_id', $request->user()->id)->orderByDesc('id')->get(),
            'categories' => config('ekub.categories'),
            'frequencies' => config('ekub.frequencies'),
        ]);
    }

    public function applyEkub(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:80'],
            'category' => ['required', 'string', 'in:'.implode(',', config('ekub.categories'))],
            'frequency' => ['required', 'string', 'in:'.implode(',', config('ekub.frequencies'))],
            'base_amount' => ['required', 'numeric', 'gt:0'],
            'duration' => ['required', 'integer', 'between:2,500'],
            'note' => ['nullable', 'string', 'max:500'],
        ]);
        $userId = (int) $request->user()->id;
        if (DB::table('ekub_applications')->where('user_id', $userId)->where('status', 'pending')->whereRaw('LOWER(name) = ?', [mb_strtolower(trim($data['name']))])->exists()) {
            return response()->json(['message' => 'You already have a pending application with this name.'], 422);
        }

        $id = DB::table('ekub_applications')->insertGetId([
            'user_id' => $userId,
            'name' => trim($data['name']),
            'category' => $data['category'],
            'frequency' => $data['frequency'],
            'base_amount' => $data['base_amount'],
            'duration' => $data['duration'],
            'note' => trim((string) ($data['note'] ?? '')) ?: null,
            'status' => 'pending',
            'created_at' => now(),
        ]);

        return response()->json(['message' => 'Your Ekub application was sent for review.', 'id' => (int) $id], 201);
    }

    public function finishedEkubs(Request $request)
    {
        $userId = (int) $request->user()->id;
        $rows = DB::table('ekubs')->where('status', 'finished')
            ->whereIn('id', DB::table('ekub_members')->where('user_id', $userId)->select('ekub_id'))
            ->orderByDesc('finished_at')->orderByDesc('id')->get();

        $data = $rows->map(function ($ekub) use ($userId): array {
            $winners = DB::table('payouts as p')->join('ekub_members as m', 'm.id', '=', 'p.winner_member_id')
                ->join('users as u', 'u.id', '=', 'm.user_id')->where('p.ekub_id', $ekub->id)
                ->orderBy('p.period_no')->get(['p.period_no', 'p.net_amount', 'u.username'])
                ->map(fn ($winner) => (array) $winner)->values();

            return [
                'id' => (int) $ekub->id, 'name' => $ekub->name, 'category' => $ekub->category,
                'frequency' => $ekub->frequency, 'base_amount' => (float) $ekub->base_amount,
                'duration' => (int) $ekub->duration, 'finished_at' => $ekub->finished_at,
                'member_count' => (int) DB::table('ekub_members')->where('ekub_id', $ekub->id)->count(),
                'winners' => $winners,
                'new_ekub_id' => DB::table('ekubs')->where('recreated_from', $ekub->id)->value('id'),
            ];
        })->values();

        return response()->json(['data' => $data]);
    }

    public function fullEkubs(Request $request)
    {
        $userId = (int) $request->user()->id;
        $rows = DB::table('ekubs')->where('status', '!=', 'finished')
            ->whereIn('id', DB::table('ekub_members')->where('user_id', $userId)->select('ekub_id'))
            ->orderByDesc('id')->get();

        $data = $rows->filter(function ($ekub): bool {
            $used = (float) DB::table('ekub_members')->where('ekub_id', $ekub->id)->sum('share_fraction');
            return (float) $ekub->duration - $used <= 0.000001;
        })->map(function ($ekub): array {
            return [
                'id' => (int) $ekub->id,
                'name' => $ekub->name,
                'category' => $ekub->category,
                'frequency' => $ekub->frequency,
                'base_amount' => (float) $ekub->base_amount,
                'duration' => (int) $ekub->duration,
                'status' => $ekub->status,
                'current_period' => (int) $ekub->current_period,
                'member_count' => (int) DB::table('ekub_members')->where('ekub_id', $ekub->id)->count(),
            ];
        })->values();

        return response()->json(['data' => $data]);
    }

    public function kyc(Request $request)
    {
        $user = $request->user();
        $row = DB::table('kyc_verifications')->where('user_id', $user->id)->first();
        if ($request->isMethod('get')) {
            return response()->json([
                'status' => $user->kyc_status,
                'verification' => $row ? [
                    'full_name' => $row->full_name, 'dob' => $row->dob, 'gender' => $row->gender,
                    'id_type' => $row->id_type, 'id_number' => $row->id_number, 'status' => $row->status,
                    'rejection_reason' => $row->rejection_reason, 'submitted_at' => $row->submitted_at,
                    'liveness_verified' => (bool) ($row->liveness_verified ?? false),
                ] : null,
            ]);
        }
        if ($user->kyc_status === 'approved') return response()->json(['message' => 'Your identity has already been verified.'], 422);

        // Mobile clients may send day/month dates from their locale's date input.
        // Normalize supported entry formats before validating and persisting ISO dates.
        $rawDob = trim((string) $request->input('dob'));
        foreach (['Y-m-d', 'd/m/Y', 'd-m-Y', 'd.m.Y', 'Y/m/d', 'Y-n-j', 'j/n/Y', 'j-n-Y'] as $dobFormat) {
            $parsedDob = \DateTimeImmutable::createFromFormat('!'.$dobFormat, $rawDob);
            $dateErrors = \DateTimeImmutable::getLastErrors();
            if ($parsedDob && ($dateErrors === false || ($dateErrors['warning_count'] === 0 && $dateErrors['error_count'] === 0)) && $parsedDob->format($dobFormat) === $rawDob) {
                $request->merge(['dob' => $parsedDob->format('Y-m-d')]);
                break;
            }
        }

        $data = $request->validate([
            'full_name' => ['required', 'string', 'max:160'],
            'dob' => ['required', 'date_format:Y-m-d', 'before:today'],
            'gender' => ['required', 'in:Male,Female,Other'],
            'id_type' => ['required', 'in:National ID,Passport'],
            'id_number' => ['required', 'string', 'max:80'],
            'personal_photo' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:10240'],
            'id_front' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:10240'],
            'id_back' => ['required_if:id_type,National ID', 'nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:10240'],
            'liveness_verified' => ['required', 'accepted'],
            'video_agreement' => ['required', 'file', 'mimes:mp4,mov,webm', 'max:51200'],
        ]);
        $saved = [];
        try {
            $saved['personal_photo'] = $this->storeUpload($request->file('personal_photo'));
            $saved['id_front'] = $this->storeUpload($request->file('id_front'));
            $saved['id_back'] = $request->file('id_back') ? $this->storeUpload($request->file('id_back')) : null;
            $saved['video_agreement'] = $this->storeUpload($request->file('video_agreement'));
            DB::table('kyc_verifications')->updateOrInsert(['user_id' => $user->id], [
                'full_name' => trim($data['full_name']), 'dob' => $data['dob'], 'gender' => $data['gender'],
                'id_type' => $data['id_type'], 'id_number' => trim($data['id_number']),
                'id_front' => $saved['id_front'], 'id_back' => $saved['id_back'],
                'liveness_verified' => true, 'liveness_video' => null,
                'video_agreement' => $saved['video_agreement'],
                'personal_photo' => $saved['personal_photo'],
                'status' => 'pending', 'rejection_reason' => null, 'submitted_at' => now(), 'reviewed_at' => null, 'approved_by' => null,
            ]);
            DB::table('users')->where('id', $user->id)->update(['kyc_status' => 'pending']);
        } catch (\Throwable $exception) {
            foreach ($saved as $file) if ($file) app(UploadStorage::class)->delete($file);
            throw $exception;
        }

        return response()->json(['message' => 'Identity verification submitted for review.', 'status' => 'pending']);
    }

    private function storeUpload(?UploadedFile $file, string $folder = 'kyc'): string
    {
        if (! $file || ! $file->isValid()) throw ValidationException::withMessages(['files' => ['Choose a valid file.']]);
        $extension = strtolower($file->getClientOriginalExtension() ?: $file->extension());
        $name = bin2hex(random_bytes(16)).'.'.$extension;
        return app(UploadStorage::class)->put($file, $folder.'/'.$name);
    }

    public function security(Request $request)
    {
        $user = $request->user();
        return response()->json([
            'enabled' => (bool) $user->twofa_enabled,
            'method' => $user->twofa_method ?? 'authenticator',
            'email_enabled' => in_array($user->twofa_method, ['email', 'both'], true) && filter_var($user->email, FILTER_VALIDATE_EMAIL),
            'authenticator_enabled' => in_array($user->twofa_method, ['authenticator', 'both'], true) && filled($user->totp_secret),
            'email_hint' => $this->maskedEmail((string) $user->email),
        ]);
    }

    public function securityAction(Request $request, string $action)
    {
        $user = $request->user();
        if ($action === 'send-email-code') {
            if (! filter_var((string) $user->email, FILTER_VALIDATE_EMAIL)) return response()->json(['message' => 'Add a valid email address to your account first.'], 422);
            $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
            BrandedEmail::send(
                $user->email,
                'Enable email verification · Mekenet Ekub',
                'Enable email verification',
                'Enter this one-time code in the app to enable email verification. It expires in 10 minutes. Do not share it.',
                $code,
            );
            Cache::put('profile_2fa_email:'.$user->id, Hash::make($code), now()->addMinutes(10));

            return response()->json(['message' => config('mail.default') === 'log' ? 'Code generated. Check storage/logs/laravel.log.' : 'Verification code sent to '.$this->maskedEmail((string) $user->email).'.']);
        }
        if ($action === 'verify-email') {
            $data = $request->validate(['code' => ['required', 'digits:6']]);
            $hash = Cache::get('profile_2fa_email:'.$user->id);
            if (! is_string($hash) || ! Hash::check($data['code'], $hash)) return response()->json(['message' => 'That code is invalid or expired. Request a new one.'], 422);
            Cache::forget('profile_2fa_email:'.$user->id);
            $method = filled($user->totp_secret) ? 'both' : 'email';
            DB::table('users')->where('id', $user->id)->update(['twofa_method' => $method, 'twofa_enabled' => true]);

            return response()->json(['message' => 'Email verification enabled.', 'method' => $method, 'enabled' => true]);
        }
        if ($action === 'start-authenticator') {
            $secret = (new Google2FA())->generateSecretKey();
            Cache::put('profile_2fa_totp:'.$user->id, $secret, now()->addMinutes(10));

            return response()->json(['secret' => $secret, 'otpauth_url' => (new Google2FA())->getQRCodeUrl('Mekenet Ekub', $user->email ?: $user->username, $secret)]);
        }
        if ($action === 'verify-authenticator') {
            $data = $request->validate(['code' => ['required', 'digits:6']]);
            $secret = Cache::get('profile_2fa_totp:'.$user->id);
            if (! is_string($secret) || ! (new Google2FA())->verifyKey($secret, $data['code'])) return response()->json(['message' => 'That authenticator code is invalid or expired.'], 422);
            Cache::forget('profile_2fa_totp:'.$user->id);
            $method = in_array($user->twofa_method, ['email', 'both'], true) ? 'both' : 'authenticator';
            DB::table('users')->where('id', $user->id)->update(['totp_secret' => $secret, 'twofa_method' => $method, 'twofa_enabled' => true]);

            return response()->json(['message' => 'Authenticator enabled.', 'method' => $method, 'enabled' => true]);
        }
        if ($action === 'disable') {
            $data = $request->validate(['password' => ['required', 'string', 'max:200']]);
            if (! Hash::check($data['password'], (string) $user->password_hash)) return response()->json(['message' => 'The password is incorrect.'], 422);
            DB::table('users')->where('id', $user->id)->update(['twofa_enabled' => false, 'twofa_method' => 'authenticator', 'totp_secret' => null]);
            Cache::forget('profile_2fa_email:'.$user->id);
            Cache::forget('profile_2fa_totp:'.$user->id);

            return response()->json(['message' => 'Two-step verification disabled.', 'enabled' => false]);
        }

        return response()->json(['message' => 'Security action not found.'], 404);
    }

    public function changePassword(Request $request)
    {
        $data = $request->validate([
            'current_password' => ['required', 'string', 'max:200'],
            'new_password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);
        $user = $request->user();
        if (! Hash::check($data['current_password'], (string) $user->password_hash)) return response()->json(['message' => 'The current password is incorrect.'], 422);
        $password = $data['new_password'];
        if (preg_match('/[A-Z]/', $password) !== 1 || preg_match('/[0-9]/', $password) !== 1 || preg_match('/[^A-Za-z0-9]/', $password) !== 1) {
            return response()->json(['message' => 'Use at least 8 characters, one uppercase letter, one number, and one symbol.'], 422);
        }
        DB::table('users')->where('id', $user->id)->update(['password_hash' => Hash::make($password)]);

        return response()->json(['message' => 'Password updated.']);
    }

    public function deleteAccount(Request $request)
    {
        $data = $request->validate([
            'password' => ['required', 'string', 'max:200'],
            'reason' => ['required', 'string', 'in:'.implode(',', config('ekub.delete_reasons'))],
            'details' => ['nullable', 'string', 'max:1000'],
        ]);
        $user = $request->user();
        if ($user->role !== 'member') return response()->json(['message' => 'Only member accounts can be deleted here.'], 403);
        if (! Hash::check($data['password'], (string) $user->password_hash)) return response()->json(['message' => 'The password is incorrect.'], 422);
        if ($data['reason'] === 'Other' && blank($data['details'])) return response()->json(['message' => 'Please explain the reason for Other.'], 422);
        $active = DB::table('ekub_members as m')->join('ekubs as e', 'e.id', '=', 'm.ekub_id')
            ->where('m.user_id', $user->id)->where('e.status', 'started')->value('e.name');
        if ($active) return response()->json(['message' => 'You cannot delete your account while you are part of the running Ekub "'.$active.'".'], 422);

        DB::transaction(function () use ($user, $data, $request): void {
            DB::table('deleted_accounts')->insert([
                'user_id' => $user->id, 'full_name' => trim($user->first_name.' '.$user->last_name),
                'username' => $user->username, 'phone' => $user->phone, 'email' => $user->email,
                'role' => $user->role, 'reason' => $data['reason'],
                'details' => trim((string) ($data['details'] ?? '')) ?: null, 'deleted_at' => now(),
            ]);
            $request->user()->tokens()->delete();
            DB::table('users')->where('id', $user->id)->delete();
        });

        return response()->json(['message' => 'Account deleted.', 'account_deleted' => true]);
    }

    private function maskedEmail(string $email): ?string
    {
        if (! filter_var($email, FILTER_VALIDATE_EMAIL)) return null;
        [$name, $domain] = explode('@', $email, 2);

        return (strlen($name) < 2 ? '*' : substr($name, 0, 1).str_repeat('*', max(3, strlen($name) - 1))).'@'.$domain;
    }
}

