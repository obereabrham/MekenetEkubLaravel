<?php
namespace App\Http\Controllers;

use App\Support\BrandedEmail;
use App\Support\EkubService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Storage;
use PragmaRX\Google2FA\Google2FA;
use Throwable;

class WebsiteController
{
    public function __construct(private EkubService $ekubs) {}

    private function page(string $name, array $data = []) { return view($name, $data); }
    private function row($row): ?array { return $row ? (array) $row : null; }
    private function rows($rows): array { return collect($rows)->map(fn ($row) => (array) $row)->all(); }
    private function flash(string $message, string $type = 'message'): void
    {
        $messages = session()->get('_flashes', []);
        $messages[] = ['type' => $type, 'message' => $message];
        session()->flash('_flashes', $messages);
    }
    private function go(string $endpoint, array $params = []) { return redirect(route_url($endpoint, $params)); }
    public function currentUser(): ?array
    {
        $id = session('user_id');
        if (! $id) return null;
        $user = $this->row(DB::table('users')->where('id', $id)->first());
        return $user && $user['status'] === 'active' ? $user : null;
    }
    private function normalizedPhone(string $value): ?string
    {
        $digits = preg_replace('/\D+/', '', trim($value));
        if (str_starts_with($digits, '251')) $digits = substr($digits, 3);
        if (str_starts_with($digits, '0')) $digits = substr($digits, 1);
        return preg_match('/^9\d{8}$/', $digits) ? '+251'.$digits : null;
    }
    private function validPassword(string $password): bool
    {
        return strlen($password) >= 8 && preg_match('/[A-Z]/', $password) && preg_match('/\d/', $password) && preg_match('/[^A-Za-z0-9]/', $password);
    }
    private function emailOtpKey(string $purpose): string { return 'email_otp_'.$purpose; }
    private function emailOtpDeliveryNotice(?string $email, string $kind = 'verification'): string
    {
        if (config('mail.default') === 'log') {
            return 'Local mail logging is enabled, so no email was sent. Find the '.$kind.' code in storage/logs/laravel.log (or the current dated log file), or configure SMTP to deliver it to '.$this->maskedEmail($email).'.';
        }

        return 'A '.$kind.' code was sent to '.$this->maskedEmail($email).'.';
    }
    private function hasEmailOtp(array $user): bool
    {
        return in_array($user['twofa_method'] ?? 'authenticator', ['email', 'both'], true)
            && !empty($user['email'])
            && (bool)filter_var($user['email'], FILTER_VALIDATE_EMAIL);
    }
    private function hasAuthenticator(array $user): bool
    {
        return in_array($user['twofa_method'] ?? 'authenticator', ['authenticator', 'both'], true)
            && !empty($user['totp_secret']);
    }

    private function notifyEkubCreated(int $ekubId, bool $newRound = false): void
    {
        $ekub = DB::table('ekubs')->where('id', $ekubId)->first();
        if (! $ekub) return;
        $recipients = DB::table('users')->where('status', 'active')
            ->whereIn('role', ['member', 'admin'])->get(['id', 'email']);
        $title = $newRound ? 'A new Ekub round is open' : 'A new Ekub is available';
        $amount = (float) $ekub->base_amount;
        $periods = (int) $ekub->duration;
        $memberCount = (int) DB::table('ekub_members')->where('ekub_id', $ekubId)->count();
        $memberCapacity = $periods;
        $body = $newRound
            ? "A new round of {$ekub->name} is open for joining. Review the Ekub details and participation rules below before joining."
            : "{$ekub->name} has been created and is open for joining. Review the Ekub details and participation rules below before joining.";
        $details = [
            ['label' => 'Ekub name', 'value' => (string) $ekub->name],
            ['label' => 'Category', 'value' => (string) $ekub->category],
            ['label' => 'Frequency', 'value' => (string) $ekub->frequency],
            ['label' => 'Contribution per period', 'value' => number_format($amount, 2).' ETB'],
            ['label' => 'Expected pool per period', 'value' => number_format($amount * $memberCapacity, 2).' ETB'],
            ['label' => 'Periods', 'value' => (string) $periods],
            ['label' => 'Members', 'value' => $memberCount.' / '.$memberCapacity.' joined'],
            ['label' => 'Status', 'value' => 'Open for joining'],
            ['label' => 'Created', 'value' => \Illuminate\Support\Carbon::parse($ekub->created_at)->format('d M Y, H:i')],
        ];
        $rules = [
            'Identity verification must be approved before joining an Ekub.',
            'Join while the Ekub is open. Once it starts, new members cannot join that round.',
            'Pay the contribution shown for each period. A payment is counted only after an administrator approves it.',
            'The administrator selects the period winner after every member has fully paid that period.',
            'A 2% service fee is deducted from the verified pool; the winner receives the remaining 98%.',
            'Late unpaid balances accrue a 1% daily penalty under the current Ekub rules.',
        ];
        foreach ($recipients as $recipient) {
            $userId = (int) $recipient->id;
            $inserted = DB::table('member_notifications')->insertOrIgnore([
                'user_id' => $userId,
                'type' => 'ekub_created',
                'title' => $title,
                'body' => $body,
                'event_key' => 'ekub.created:'.$ekubId.':'.$userId,
                'created_at' => now(),
            ]);
            if (! $inserted) continue;
            if (! filter_var($recipient->email, FILTER_VALIDATE_EMAIL)) continue;
            try {
                BrandedEmail::send(
                    $recipient->email,
                    $title.' · Mekenet Ekub',
                    $title,
                    $body,
                    null,
                    $details,
                    $rules,
                );
            } catch (Throwable $exception) {
                Log::warning('Could not email Ekub announcement.', ['user_id' => $userId, 'exception' => $exception->getMessage()]);
            }
        }
    }

    private function notifyWinner(int $ekubId, int $periodNo): void
    {
        $payout = DB::table('payouts as p')->join('ekubs as e', 'e.id', '=', 'p.ekub_id')
            ->join('ekub_members as m', 'm.id', '=', 'p.winner_member_id')
            ->join('users as w', 'w.id', '=', 'm.user_id')->where('p.ekub_id', $ekubId)
            ->where('p.period_no', $periodNo)
            ->first(['p.id', 'p.winner_member_id', 'p.net_amount', 'e.name as ekub_name', 'w.id as winner_user_id', 'w.username as winner_username']);
        if (! $payout) return;
        $members = DB::table('users as u')->join('ekub_members as m', 'm.user_id', '=', 'u.id')
            ->where('m.ekub_id', $ekubId)->where('u.status', 'active')->get(['u.id', 'u.email']);
        $admins = DB::table('users')->where('role', 'admin')->where('status', 'active')->get(['id', 'email']);
        $recipients = $members->concat($admins)->unique('id');
        $winnerName = '@'.$payout->winner_username;
        foreach ($recipients as $recipient) {
            $userId = (int) $recipient->id;
            $isWinner = $userId === (int) $payout->winner_user_id;
            $title = $isWinner ? 'You won an Ekub period!' : 'An Ekub winner was selected';
            $body = $isWinner
                ? "You won {$payout->ekub_name}, Period {$periodNo}. Your payout is ".number_format((float) $payout->net_amount, 2).' ETB. The Mekenet Ekub team will contact you about payout.'
                : "{$winnerName} won {$payout->ekub_name}, Period {$periodNo}. The payout is ".number_format((float) $payout->net_amount, 2).' ETB.';
            $inserted = DB::table('member_notifications')->insertOrIgnore([
                'user_id' => $userId,
                'type' => 'winner',
                'title' => $title,
                'body' => $body,
                'event_key' => 'payout.winner:'.$payout->id.':'.$userId,
                'created_at' => now(),
            ]);
            if (! $inserted) continue;
            if (! filter_var($recipient->email, FILTER_VALIDATE_EMAIL)) continue;
            try {
                BrandedEmail::send($recipient->email, $title.' · Mekenet Ekub', $title, $body);
            } catch (Throwable $exception) {
                Log::warning('Could not email Ekub winner update.', ['user_id' => $userId, 'payout_id' => $payout->id, 'exception' => $exception->getMessage()]);
            }
        }
    }

    private function notifyMemberEvent(int $userId, string $type, string $title, string $body, string $eventKey): void
    {
        $user = DB::table('users')->where('id', $userId)->where('status', 'active')->first(['id', 'email']);
        if (! $user) return;
        $inserted = DB::table('member_notifications')->insertOrIgnore([
            'user_id' => $userId,
            'type' => $type,
            'title' => $title,
            'body' => $body,
            'event_key' => $eventKey,
            'created_at' => now(),
        ]);
        if (! $inserted) return;
        if (! filter_var($user->email, FILTER_VALIDATE_EMAIL)) return;
        try {
            BrandedEmail::send($user->email, $title.' · Mekenet Ekub', $title, $body);
        } catch (Throwable $exception) {
            Log::warning('Could not email member notification.', ['user_id' => $userId, 'event_key' => $eventKey, 'exception' => $exception->getMessage()]);
        }
    }

    private function notifyEkubMembers(int $ekubId, string $type, string $title, string $body, string $eventPrefix): void
    {
        $memberIds = DB::table('ekub_members')->where('ekub_id', $ekubId)->pluck('user_id');
        foreach ($memberIds as $memberId) {
            $userId = (int) $memberId;
            $this->notifyMemberEvent($userId, $type, $title, $body, $eventPrefix.':'.$userId);
        }
    }

    private function issueEmailOtp(array $user, string $purpose): void
    {
        $email=trim((string)($user['email'] ?? ''));
        if (!$email || !filter_var($email,FILTER_VALIDATE_EMAIL)) throw new \RuntimeException('Add a valid email address to your profile before enabling email OTP.');
        $key=$this->emailOtpKey($purpose); $existing=session($key);
        if (is_array($existing) && (int)($existing['resend_after'] ?? 0)>now()->timestamp) throw new \RuntimeException('Please wait 60 seconds before requesting another email code.');
        $limitKey='mekenet_email_otp_send_'.$user['id'];
        if (RateLimiter::tooManyAttempts($limitKey,5)) throw new \RuntimeException('Too many email codes were requested. Please try again in about an hour.');
        RateLimiter::hit($limitKey,3600);
        $code=str_pad((string)random_int(0,999999),6,'0',STR_PAD_LEFT);
        $label=match($purpose){'setup'=>'enable email verification','sensitive'=>'confirm an account security change',default=>'sign in'};
        BrandedEmail::send(
            $email,
            'Your Mekenet Ekub verification code',
            'Your verification code',
            'Enter this one-time code to '.$label.'. It expires in 10 minutes. Do not share it with anyone.',
            $code,
        );
        session()->put($key,['user_id'=>(int)$user['id'],'hash'=>Hash::make($code),'expires_at'=>now()->addMinutes(10)->timestamp,'resend_after'=>now()->addSeconds(60)->timestamp,'attempts'=>0]);
    }
    private function verifyEmailOtp(array $user, string $code, string $purpose): bool
    {
        $key=$this->emailOtpKey($purpose); $challenge=session($key);
        if (!is_array($challenge) || (int)($challenge['user_id'] ?? 0)!==(int)$user['id']) return false;
        if ((int)($challenge['expires_at'] ?? 0)<now()->timestamp) { session()->forget($key); return false; }
        $limitKey='mekenet_email_otp_verify_'.$user['id'].'_'.$purpose;
        if (RateLimiter::tooManyAttempts($limitKey,10)) return false;
        RateLimiter::hit($limitKey,600);
        $challenge['attempts']=(int)($challenge['attempts'] ?? 0)+1;
        if ($challenge['attempts']>5) { session()->forget($key); return false; }
        session()->put($key,$challenge);
        if (!preg_match('/^\d{6}$/',$code) || !Hash::check($code,(string)($challenge['hash'] ?? ''))) {
            if ($challenge['attempts']>=5) session()->forget($key);
            return false;
        }
        session()->forget($key); RateLimiter::clear($limitKey); return true;
    }
    private function maskedEmail(?string $email): string
    {
        if (!$email || !str_contains($email,'@')) return '';
        [$name,$domain]=explode('@',$email,2);
        return mb_substr($name,0,1).str_repeat('*',max(3,mb_strlen($name)-1)).'@'.$domain;
    }
    private function saveUpload(?\Illuminate\Http\UploadedFile $file, ?string $folder = null, ?string $base = null, ?array $allowed = null): ?string
    {
        if (! $file || ! $file->isValid()) return null;
        $extension = strtolower($file->getClientOriginalExtension());
        $allowed ??= config('ekub.upload_extensions');
        if (! in_array($extension, $allowed, true)) throw new \RuntimeException('Unsupported file type.');
        if ($file->getSize() > 50 * 1024 * 1024) throw new \RuntimeException('File size must be 50 MB or less.');
        $directory = 'static/uploads'.($folder ? '/'.trim($folder, '/') : '');
        if (! is_dir(public_path($directory))) mkdir(public_path($directory), 0775, true);
        $slug = $base ? trim(preg_replace('/[^\pL\pN_-]+/u', '-', $base), '-_') : bin2hex(random_bytes(16));
        $slug = mb_substr($slug ?: 'file', 0, 70);
        $name = $slug.'.'.$extension; $n = 2;
        while (file_exists(public_path($directory.'/'.$name))) $name = $slug.'_'.($n++).'.'.$extension;
        $file->move(public_path($directory), $name);
        return ($folder ? trim($folder, '/').'/' : '').$name;
    }
    private function imageUpload(?\Illuminate\Http\UploadedFile $file, ?string $folder = null, ?string $base = null): ?string
    {
        return $this->saveUpload($file, $folder, $base, ['png','jpg','jpeg','webp','gif']);
    }
    private function insertEkub(string $name, string $category, string $frequency, float $amount, int $duration, bool $isItem, array $images = [], ?int $recreatedFrom = null): int
    {
        $id = DB::table('ekubs')->insertGetId([
            'name'=>$name,'category'=>$category,'frequency'=>$frequency,'base_amount'=>$amount,'duration'=>$duration,
            'status'=>'open','is_item'=>$isItem,'product1'=>$images[0] ?? null,'product2'=>$images[1] ?? null,'product3'=>$images[2] ?? null,
            'recreated_from'=>$recreatedFrom,'created_at'=>now(),
        ]);
        foreach ($images as $position => $image) DB::table('ekub_images')->insert(['ekub_id'=>$id,'image'=>$image,'position'=>$position,'created_at'=>now()]);
        return (int) $id;
    }
    private function joinable(?array $user = null): bool { return $user && ($user['role'] === 'admin' || $user['role'] === 'partner' || $user['kyc_status'] === 'approved'); }
    private function partnerAllowed(string $permission): bool
    {
        $user = $this->currentUser();
        if (! $user) return false;
        if ($user['role'] === 'admin') return true;
        if ($user['role'] !== 'partner') return false;
        $permissions = DB::table('partners')->where('user_id', $user['id'])->value('permissions') ?? '';
        return in_array($permission, explode(',', $permissions), true);
    }

    public function home() { return $this->page('index'); }
    public function homePage() { return $this->go('home'); }
    public function about() { return $this->page('about'); }
    public function contact() { return $this->page('contact'); }
    public function terms() { return $this->page('terms'); }
    public function privacy() { return $this->page('privacy'); }

    public function ekubsIndex()
    {
        $user = $this->currentUser();
        if ($user && in_array($user['role'], ['admin','partner'], true)) return $this->go($user['role'] === 'admin' ? 'admin_dashboard' : 'partner_dashboard');
        $data = $this->rows(DB::table('ekubs')->whereIn('status', ['open','started'])->orderByDesc('id')->get());
        $joined = $user ? DB::table('ekub_members')->where('user_id', $user['id'])->pluck('ekub_id')->all() : [];
        foreach ($data as &$ekub) {
            $used = $this->ekubs->usedCapacity((int) $ekub['id']);
            $ekub['joined'] = in_array($ekub['id'], $joined);
            $ekub['member_count'] = floor($used) === $used ? (int) $used : round($used, 2);
            $ekub['max_members'] = (int) $ekub['duration'];
            $ekub['is_full'] = (float) $ekub['duration'] - $used <= 0.000001;
        }
        unset($ekub);
        return $this->page('ekubs', ['ekubs'=>$data]);
    }

    public function ekubDetail(int $ekubId)
    {
        $ekub = $this->row(DB::table('ekubs')->where('id', $ekubId)->first());
        if (! $ekub) return response()->view('error', ['code'=>404,'message'=>'Ekub not found.'], 404);
        $members = $this->rows(DB::table('ekub_members as em')->join('users as u','u.id','=','em.user_id')->where('em.ekub_id',$ekubId)->orderBy('em.id')->get(['em.*','u.first_name','u.last_name','u.username','u.phone']));
        $user = $this->currentUser();
        $alreadyJoined = $user && collect($members)->contains(fn ($m) => (int) $m['user_id'] === (int) $user['id']);
        $canSeeWinners = $user && ($user['role'] === 'admin' || $alreadyJoined);
        return $this->page('ekub_detail', [
            'ekub'=>$ekub,'members'=>$members,'item_images'=>$this->ekubs->images($ekub),'is_full'=>$this->ekubs->isFull($ekub),
            'already_joined'=>$alreadyJoined,'net'=>round($ekub['base_amount']*$ekub['duration']*0.98,2),
            'winners'=>$canSeeWinners ? $this->ekubs->winners($ekubId) : [],'can_see_winners'=>$canSeeWinners,
        ]);
    }

    public function register(Request $request)
    {
        if ($request->isMethod('post')) {
            $first=trim((string)$request->input('first_name')); $last=trim((string)$request->input('last_name')); $username=trim((string)$request->input('username'));
            $phone=$this->normalizedPhone((string)$request->input('phone')); $email=mb_strtolower(trim((string)$request->input('email'))); $password=(string)$request->input('password');
            if (! $first || ! $last || ! $username || ! $request->input('phone') || ! $password || ! $request->input('confirm_password')) $this->flash('All required fields must be completed.','error');
            elseif (! $phone) $this->flash('Phone must be a valid Ethiopian 09/9 number.','error');
            elseif (! filter_var($email, FILTER_VALIDATE_EMAIL)) $this->flash('Enter a valid email address.','error');
            elseif (! $this->validPassword($password)) $this->flash('Password must be at least 8 characters and contain an uppercase letter, number, and special character.','error');
            elseif ($password !== $request->input('confirm_password')) $this->flash('Passwords do not match.','error');
            elseif (! in_array($request->input('agree'), ['yes','1'], true) && $request->input('terms') !== '1') $this->flash('You must agree to the terms.','error');
            elseif (DB::table('users')->where('username',$username)->orWhere('phone',$phone)->when($email,fn($q)=>$q->orWhere('email',$email))->exists()) $this->flash('Username, phone, or email already exists.','error');
            else {
                DB::table('users')->insert(['first_name'=>$first,'last_name'=>$last,'username'=>$username,'phone'=>$phone,'email'=>$email,'password_hash'=>Hash::make($password),'role'=>'member','status'=>'active','kyc_status'=>'not_submitted','first_login'=>1,'twofa_method'=>'authenticator','twofa_enabled'=>0,'created_at'=>now()]);
                $this->flash('Account created successfully. Please sign in with your password.','success');
                return $this->go('login', ['registered'=>1]);
            }
        }
        return $this->page('register');
    }

    public function login(Request $request)
    {
        if ($request->isMethod('post')) {
            $ident=trim((string)$request->input('identifier')); $password=(string)$request->input('password');
            if (! $ident || ! $password) $this->flash('Username, phone or email and password are required.','error');
            else {
                $user=$this->row(DB::table('users')->where('username',$ident)->orWhere('phone',$ident)->orWhere('email',$ident)->first());
                if (! $user || ! Hash::check($password,$user['password_hash'])) $this->flash('Invalid login credentials.','error');
                elseif ($user['status'] !== 'active') $this->flash('This account is suspended.','error');
                elseif ($user['twofa_enabled']) {
                    $emailAvailable=$this->hasEmailOtp($user); $authenticatorAvailable=$this->hasAuthenticator($user);
                    if (!$emailAvailable && !$authenticatorAvailable) { $this->flash('Two-factor sign-in is not configured correctly. Contact the site administrator.','error'); return $this->go('login'); }
                    if ($emailAvailable && !$authenticatorAvailable) {
                        try { $this->issueEmailOtp($user,'login'); $this->flash($this->emailOtpDeliveryNotice($user['email'] ?? null,'sign-in'),'message'); }
                        catch (Throwable $e) { session()->forget(['pending_2fa_user','email_otp_login']); $this->flash($e instanceof \RuntimeException ? $e->getMessage() : 'Could not send a sign-in code. Check the email settings and try again.','error'); return $this->go('login'); }
                    }
                    session()->put('pending_2fa_user',$user['id']);
                    return $this->go('verify_login');
                }
                else return $this->finishLogin($user);
            }
        }
        return $this->page('login', ['registered'=>(bool)$request->query('registered')]);
    }
    private function finishLogin(array $user)
    {
        session()->regenerate(); session()->put(['user_id'=>$user['id'],'role'=>$user['role'],'username'=>$user['username'],'welcome'=>$user['first_login'] ? 'Welcome' : 'Welcome back']);
        session()->forget(['pending_2fa_user','pending_totp_secret','email_otp_login','email_otp_setup','email_otp_sensitive','pending_2fa_method']);
        DB::table('users')->where('id',$user['id'])->update(['first_login'=>false]);
        return $this->go(match($user['role']) {'admin'=>'admin_dashboard','partner'=>'partner_dashboard',default=>'dashboard'});
    }
    public function verifyLogin(Request $request)
    {
        $user=$this->row(DB::table('users')->where('id',session('pending_2fa_user'))->first());
        if (! $user || ! $user['twofa_enabled']) return $this->go('login');
        $method=$user['twofa_method'] ?? 'authenticator';
        $emailAvailable=$this->hasEmailOtp($user); $authenticatorAvailable=$this->hasAuthenticator($user);
        if (!$emailAvailable && !$authenticatorAvailable) { session()->forget(['pending_2fa_user','email_otp_login']); $this->flash('Two-factor sign-in is not configured correctly. Contact the site administrator.','error'); return $this->go('login'); }
        if ($request->isMethod('post')) {
            $action=(string)$request->input('action');
            if ($emailAvailable && in_array($action,['send_email','resend'],true)) {
                try { $this->issueEmailOtp($user,'login'); $this->flash($this->emailOtpDeliveryNotice($user['email'] ?? null,'sign-in'),'success'); }
                catch (Throwable $e) { $this->flash($e instanceof \RuntimeException ? $e->getMessage() : 'Could not send an email code. Check the mail settings and try again.','error'); }
            } elseif ($emailAvailable && ($action==='verify_email' || ($method==='email' && $action==='')) && $this->verifyEmailOtp($user,trim((string)$request->input('code')),'login')) return $this->finishLogin($user);
            elseif ($authenticatorAvailable && ($action==='verify_authenticator' || ($method==='authenticator' && $action==='')) && (new Google2FA())->verifyKey($user['totp_secret'],trim((string)$request->input('code')))) return $this->finishLogin($user);
            elseif (in_array($action,['verify_email','verify_authenticator'],true) || ($method==='email' && $action==='') || ($method==='authenticator' && $action==='')) $this->flash($action==='verify_email' || $method==='email' ? 'The email code is invalid or expired. Request a new code and try again.' : 'Invalid authenticator code. Please try again.','error');
        }
        $emailChallenge=session('email_otp_login');
        $emailPending=is_array($emailChallenge)&&(int)($emailChallenge['user_id']??0)===(int)$user['id'];
        return $this->page('verify_login',['method'=>$emailAvailable&&$authenticatorAvailable?'both':($emailAvailable?'email':'authenticator'),'email'=>$emailAvailable?$this->maskedEmail($user['email']):null,'email_pending'=>$emailPending]);
    }
    public function security2fa(Request $request)
    {
        $user=$this->currentUser(); if (! $user) return $this->go('login');
        if ($request->isMethod('post')) {
            if ($request->input('action') === 'disable') {
                DB::table('users')->where('id',$user['id'])->update(['twofa_enabled'=>0,'totp_secret'=>null,'twofa_method'=>'authenticator']);
                session()->forget(['pending_totp_secret','email_otp_setup']);
                $this->flash('Two-factor sign-in has been disabled. Password sign-in is active.','success');
                return $this->go('security_2fa');
            }
            if ($request->input('action')==='email') {
                session()->forget('pending_totp_secret');
                try { $this->issueEmailOtp($user,'setup'); $this->flash($this->emailOtpDeliveryNotice($user['email'] ?? null),'success'); }
                catch (Throwable $e) { $this->flash($e instanceof \RuntimeException ? $e->getMessage() : 'Could not send an email code. Check the mail settings and try again.','error'); }
                return $this->go('security_2fa');
            }
            if ($request->input('action')==='resend_email') {
                try { $this->issueEmailOtp($user,'setup'); $this->flash($this->emailOtpDeliveryNotice($user['email'] ?? null),'success'); }
                catch (Throwable $e) { $this->flash($e instanceof \RuntimeException ? $e->getMessage() : 'Could not send an email code. Check the mail settings and try again.','error'); }
                return $this->go('security_2fa');
            }
            session()->forget('email_otp_setup');
            $secret=(new Google2FA())->generateSecretKey(); session()->put('pending_totp_secret',$secret);
            return $this->go('security_2fa');
        }
        $secret=session('pending_totp_secret'); $uri=$secret?(new Google2FA())->getQRCodeUrl('Mekenet Ekub',$user['email'] ?: $user['username'],$secret):null;
        $pending=session('email_otp_setup'); $emailPending=is_array($pending)&&(int)($pending['user_id']??0)===(int)$user['id'];
        return $this->page('security_2fa',['secret'=>$secret,'uri'=>$uri,'enabled'=>(bool)$user['twofa_enabled'],'method'=>$user['twofa_method']??'authenticator','authenticator_enabled'=>$this->hasAuthenticator($user),'email_enabled'=>$this->hasEmailOtp($user),'email'=>$this->maskedEmail($user['email']??null),'email_pending'=>$emailPending]);
    }
    public function confirm2fa(Request $request)
    {
        $user=$this->currentUser();
        if ($user && $this->verifyEmailOtp($user,trim((string)$request->input('code')),'setup')) {
            $nextMethod=$this->hasAuthenticator($user)?'both':'email';
            DB::table('users')->where('id',$user['id'])->update(['twofa_method'=>$nextMethod,'twofa_enabled'=>1]);
            session()->forget('pending_totp_secret');
            $this->flash($nextMethod==='both'?'Email OTP and your authenticator app are both enabled. Choose either one at sign-in.':'Email OTP is enabled. Future sign-ins will require a code sent to your email.','success');
        } elseif ($user && ($secret=session('pending_totp_secret')) && (new Google2FA())->verifyKey($secret,trim((string)$request->input('code')))) {
            $nextMethod=$this->hasEmailOtp($user)?'both':'authenticator';
            DB::table('users')->where('id',$user['id'])->update(['twofa_method'=>$nextMethod,'totp_secret'=>$secret,'twofa_enabled'=>1]);
            session()->forget('pending_totp_secret');
            $this->flash($nextMethod==='both'?'Authenticator app verified. Email OTP and authenticator are both enabled; choose either at sign-in.':'Authenticator verified and enabled. Future sign-ins will require your password and authenticator code.','success');
        } else $this->flash('Code did not match or has expired. Try again or request a new email code.','error');
        return $this->go('security_2fa');
    }
    public function logout() { session()->invalidate(); session()->regenerateToken(); return $this->go('home'); }

    public function dashboardStats()
    {
        $id=session('user_id');
        return response()->json(['available_ekubs'=>DB::table('ekubs')->whereIn('status',['open','started'])->count(),'joined_ekubs'=>DB::table('ekub_members')->where('user_id',$id)->where('status','joined')->count(),'total_paid'=>(float)DB::table('payments')->where('user_id',$id)->where('status','approved')->sum('approved_amount')]);
    }
    public function dashboard()
    {
        $user=$this->currentUser();
        if ($user['role']==='admin') return $this->go('admin_dashboard');
        if ($user['role']==='partner') return $this->go('partner_dashboard');
        $available=$this->rows(DB::table('ekubs')->whereIn('status',['open','started'])->orderByDesc('id')->get());
        $joined=$this->rows(DB::table('ekub_members as m')->join('ekubs as e','e.id','=','m.ekub_id')->where('m.user_id',$user['id'])->orderByDesc('m.id')->get(['e.*','m.share_type','m.share_fraction','m.contribution_amount','m.id as member_id']));
        $celebrate=$this->rows(DB::table('payouts as p')->join('ekub_members as m','m.id','=','p.winner_member_id')->join('ekubs as e','e.id','=','p.ekub_id')->where('m.user_id',$user['id'])->where('p.celebrated',0)->orderBy('p.id')->get(['p.id','p.period_no','p.net_amount','e.name as ekub_name']));
        if ($celebrate) DB::table('payouts')->whereIn('id',array_column($celebrate,'id'))->update(['celebrated'=>1]);
        $groups=[]; foreach($available as $e) $groups[$e['category'] ?: 'Other'][]=$e;
        $categories=array_map(fn($name,$items)=>['name'=>$name,'ekubs'=>$items],array_keys($groups),array_values($groups));
        $counts=['available_ekubs'=>count($available),'joined_ekubs'=>count($joined),'total_paid'=>(float)DB::table('payments')->where('user_id',$user['id'])->where('status','approved')->sum('approved_amount')];
        $fullIds=[]; foreach($available as $e) if($this->ekubs->isFull($e)) $fullIds[]=$e['id'];
        return $this->page('dashboard',array_merge($counts,['full_ids'=>$fullIds,'available'=>$available,'joined'=>$joined,'paid'=>$counts['total_paid'],'ekubs'=>$available,'ekub_categories'=>$categories,'user'=>$user,'celebrate'=>$celebrate]));
    }
    public function profile() { return $this->page('profile',['user'=>$this->currentUser(),'edit_field'=>request()->query('edit')]); }
    public function profileEdit(string $field, Request $request)
    {
        $user=$this->currentUser(); $allowed=['first_name','last_name','username','email','phone']; $value=trim((string)$request->input('value'));
        if ($user['kyc_status']==='approved') { $this->flash('Your profile information is locked after KYC approval. Only the profile picture can be changed.','error'); return $this->go('profile'); }
        if (!in_array($field,$allowed,true)) { $this->flash('This profile field cannot be edited here.','error'); return $this->go('profile'); }
        if ($field==='email') { if($value && !preg_match('/^[A-Z0-9._%+-]+@gmail\.com$/i',$value)){ $this->flash('Enter a valid Gmail address.','error'); return $this->go('profile',['edit'=>$field]); } $value=$value ?: null; }
        elseif($field==='phone'){ $value=$this->normalizedPhone($value); if(!$value){$this->flash('Enter a valid Ethiopian phone number.','error');return $this->go('profile',['edit'=>$field]);} }
        elseif(!$value){$this->flash('This field cannot be empty.','error');return $this->go('profile',['edit'=>$field]);}
        if(DB::table('users')->where($field,$value)->where('id','!=',$user['id'])->exists()){$this->flash("That {$field} is already in use.",'error');return $this->go('profile',['edit'=>$field]);}
        DB::table('users')->where('id',$user['id'])->update([$field=>$value]); $this->flash('Profile information updated.','success'); return $this->go('profile');
    }
    public function profilePicture(Request $request)
    {
        try { $picture=$this->imageUpload($request->file('profile_picture')); if(!$picture) throw new \RuntimeException('Choose an image first.'); DB::table('users')->where('id',session('user_id'))->update(['profile_picture'=>$picture]); $this->flash('Profile picture updated.','success'); }
        catch(Throwable $e){$this->flash($e->getMessage(),'error');}
        return $this->go('profile');
    }

    public function kyc(Request $request)
    {
        $user=$this->currentUser();
        if($user['kyc_status']==='approved') return $this->page('kyc',['locked'=>true]);
        if($request->isMethod('post')) {
            $saved=[]; $name=trim((string)$request->input('full_name')); $idType=(string)$request->input('id_type');
            try {
                if(!in_array($idType,['National ID','Passport'],true)) throw new \RuntimeException('Please choose an ID type.');
                if((string)$request->input('liveness_verified')!=='1') throw new \RuntimeException('Pass the in-page live face check before submitting.');
                $base=preg_replace('/\D/','',(string)$user['phone']);
                $photo=$this->imageUpload($request->file('personal_photo'),'personal_photo',$name.'_'.$base.'_photo'); if($photo)$saved[]=$photo;
                $front=$this->imageUpload($request->file('id_front'),'id_passport',$name.'_'.$base.($idType==='Passport'?'_passport':'_id-front')); if($front)$saved[]=$front;
                $back=$idType==='National ID' ? $this->imageUpload($request->file('id_back'),'id_passport',$name.'_'.$base.'_id-back') : null; if($back)$saved[]=$back;
                $video=$this->saveUpload($request->file('video_agreement'),'video',$name.'_'.$base.'_video',['mp4','mov','webm']); if($video)$saved[]=$video;
                if(!$photo) throw new \RuntimeException('Personal photo is required.');
                if(!$front || ($idType==='National ID' && !$back)) throw new \RuntimeException($idType==='National ID'?'National ID requires both the front and back images.':'Passport requires one image.');
                if(!$video) throw new \RuntimeException('Video agreement is required.');
                DB::table('kyc_verifications')->updateOrInsert(['user_id'=>$user['id']],['full_name'=>$name,'dob'=>$request->input('dob'),'gender'=>$request->input('gender'),'id_type'=>$idType,'id_number'=>$request->input('id_number'),'id_front'=>$front,'id_back'=>$back,'liveness_verified'=>true,'liveness_video'=>null,'video_agreement'=>$video,'personal_photo'=>$photo,'status'=>'pending','rejection_reason'=>null,'submitted_at'=>now(),'reviewed_at'=>null]);
                DB::table('users')->where('id',$user['id'])->update(['kyc_status'=>'pending']);
                $this->flash('KYC submitted. Please wait for approval.','success'); return $this->go('kyc');
            } catch(Throwable $e) { foreach($saved as $file) @unlink(public_path('static/uploads/'.$file)); $this->flash($e->getMessage(),'error'); }
        }
        return $this->page('kyc',['kyc'=>$this->row(DB::table('kyc_verifications')->where('user_id',$user['id'])->first()),'locked'=>false]);
    }

    public function joinEkub(int $ekubId, Request $request)
    {
        $user=$this->currentUser(); if($user['kyc_status']!=='approved') return $this->page('kyc_required');
        $ekub=$this->row(DB::table('ekubs')->where('id',$ekubId)->first()); if(!$ekub)return response()->view('error',['code'=>404,'message'=>'Ekub not found'],404);
        if($request->isMethod('post')) {
            $share=$ekub['is_item'] ? 'full' : (string)$request->input('share_type','full'); $fraction=['full'=>1.0,'half'=>0.5,'quarter'=>0.25][$share] ?? 0;
            if(!$fraction || ($ekub['is_item'] && $share!=='full')) {$this->flash('Invalid share selection.','error');return $this->go('join_ekub',['ekub_id'=>$ekubId]);}
            try { DB::transaction(function() use($ekub,$ekubId,$user,$share,$fraction) {
                $locked=DB::table('ekubs')->where('id',$ekubId)->lockForUpdate()->first();
                if($locked->status!=='open') throw new \RuntimeException('This Ekub has already started or is closed.');
                if(DB::table('ekub_members')->where('ekub_id',$ekubId)->where('user_id',$user['id'])->exists()) throw new \RuntimeException('You already joined this Ekub.');
                $used=(float)DB::table('ekub_members')->where('ekub_id',$ekubId)->sum('share_fraction');
                if($used+$fraction>(float)$locked->duration) throw new \RuntimeException('This Ekub is full or does not have enough remaining capacity.');
                DB::table('ekub_members')->insert(['ekub_id'=>$ekubId,'user_id'=>$user['id'],'share_type'=>$share,'share_fraction'=>$fraction,'contribution_amount'=>round((float)$locked->base_amount*$fraction,2),'status'=>'joined','joined_at'=>now()]);
            }); $this->flash('You joined the Ekub successfully.','success'); return $this->go('dashboard'); }
            catch(Throwable $e){$this->flash($e->getMessage(),'error');return $this->go('ekub_detail',['ekub_id'=>$ekubId]);}
        }
        if($ekub['status']!=='open' || $this->ekubs->isFull($ekub)) { $this->flash($ekub['status']!=='open'?'This Ekub has already started or is closed.':'This Ekub is full. No more members can be added.','error'); return $this->go('ekub_detail',['ekub_id'=>$ekubId]); }
        return $this->page('join_ekub',['ekub'=>$ekub]);
    }
    public function joinLegacy(Request $request)
    {
        $id=(int)$request->input('ekub_id'); if(!$id){$this->flash('Please select an Ekub.','error');return $this->go('ekubs');}
        if(!$this->currentUser()) return $this->go('login');
        return $this->joinEkub($id,$request);
    }
    public function myEkubs()
    {
        $user=$this->currentUser(); if(in_array($user['role'],['admin','partner'],true)) return $this->go($user['role']==='admin'?'admin_dashboard':'partner_dashboard');
        return $this->page('my_ekubs',['rows'=>$this->rows(DB::table('ekub_members as em')->join('ekubs as e','e.id','=','em.ekub_id')->where('em.user_id',$user['id'])->orderByDesc('em.id')->get(['e.*','em.id as member_id','em.share_type','em.share_fraction','em.contribution_amount','em.status as member_status']))]);
    }
    public function leaveEkub(int $ekubId)
    {
        $user=$this->currentUser(); if($user['role']!=='member'){$this->flash('Only members can leave Ekubs.','error');return $this->go('dashboard');}
        $ekub=$this->row(DB::table('ekubs')->where('id',$ekubId)->first());
        if(!$ekub){$this->flash('Ekub not found.','error');return $this->go('my_ekubs');}
        if(!in_array($ekub['status'],['pending','open'],true)){$this->flash('You cannot leave after the Ekub has started.','error');return $this->go('my_ekubs');}
        DB::table('ekub_members')->where('ekub_id',$ekubId)->where('user_id',$user['id'])->delete(); $this->flash('You have successfully left the Ekub.','success'); return $this->go('my_ekubs');
    }
    public function status()
    {
        $user=$this->currentUser(); if(in_array($user['role'],['admin','partner'],true))return $this->go($user['role']==='admin'?'admin_dashboard':'partner_dashboard');
        $members=$this->rows(DB::table('ekub_members as em')->join('ekubs as e','e.id','=','em.ekub_id')->where('em.user_id',$user['id'])->get(['e.*','em.id as member_id','em.share_type','em.contribution_amount']));
        $data=[];$drawn=[];
        foreach($members as $member){$payments=$this->rows(DB::table('payments')->where('user_id',$user['id'])->where('ekub_id',$member['id'])->orderBy('period_no')->get());$data[]=[$member,$payments];$drawn[$member['id']]=DB::table('payouts')->where('ekub_id',$member['id'])->pluck('period_no')->map(fn($x)=>(int)$x)->all();}
        return $this->page('status',['data'=>$data,'drawn'=>$drawn]);
    }
    public function myStatus() { return $this->status(); }
    public function pay(int $ekubId, int $periodNo, Request $request)
    {
        $user = $this->currentUser();
        $ekub = $this->row(DB::table('ekubs')->where('id', $ekubId)->first());
        $member = $this->row(DB::table('ekub_members')->where('ekub_id', $ekubId)->where('user_id', $user['id'])->first());
        if (! $ekub || ! $member) return response()->view('error', ['code' => 404, 'message' => 'Membership not found'], 404);
        if ($periodNo < 1 || $periodNo > $ekub['duration']) return response()->view('error', ['code' => 400, 'message' => 'Invalid period.'], 400);
        if ($ekub['status'] !== 'started') { $this->flash('This Ekub has not started yet.', 'error'); return $this->go('status'); }
        if ($periodNo > 1 && ! DB::table('payouts')->where('ekub_id', $ekubId)->where('period_no', $periodNo - 1)->exists()) {
            $this->flash('You cannot pay Period '.($periodNo).' yet. The previous period winner must be drawn first.', 'error');
            return $this->go('status');
        }

        $balance = $this->ekubs->periodBalance($ekub, $member, $periodNo, (int) $user['id']);
        if ($request->isMethod('post')) {
            $method = trim((string) $request->input('method'));
            $transaction = preg_replace('/\s+/', '', trim((string) $request->input('transaction_no'))) ?? '';
            $amount = round((float) $request->input('amount'), 2);
            $accounts = config('ekub.payment_accounts', []);
            $receivingAccount = trim((string) ($accounts[$method] ?? ''));
            $isBinance = $method === 'Binance Pay';
            $exchangeRate = $isBinance ? (float) config('ekub.binance_etb_per_usdt', 0) : 1.0;

            if ($balance['can_submit'] <= 0) {
                $this->flash($balance['left'] <= 0 ? 'Nothing left to pay for this period.' : 'Your earlier payment is waiting for admin approval. You can pay the remaining balance after that.', 'error');
                return $this->go('pay', ['ekub_id' => $ekubId, 'period_no' => $periodNo]);
            }
            if (! in_array($method, config('ekub.methods', []), true) || $receivingAccount === '') {
                $this->flash('Select a payment method with a configured receiving account.', 'error');
                return $this->go('pay', ['ekub_id' => $ekubId, 'period_no' => $periodNo]);
            }
            if ($isBinance && $exchangeRate <= 0) {
                $this->flash('Binance Pay is not ready. Ask an administrator to configure the ETB per USDT rate.', 'error');
                return $this->go('pay', ['ekub_id' => $ekubId, 'period_no' => $periodNo]);
            }
            if ($amount <= 0 || $amount > $balance['can_submit'] + 0.001) {
                $this->flash('Enter an amount within the remaining balance.', 'error');
                return $this->go('pay', ['ekub_id' => $ekubId, 'period_no' => $periodNo]);
            }
            if (! $transaction || mb_strlen($transaction) > 191 || ! $request->boolean('terms_accepted')) {
                $this->flash(! $transaction ? 'Enter the transaction ID from your transfer receipt.' : 'Accept the payment terms to continue.', 'error');
                return $this->go('pay', ['ekub_id' => $ekubId, 'period_no' => $periodNo]);
            }

            $upload = $request->file('screenshot');
            $extension = strtolower((string) ($upload?->getClientOriginalExtension() ?? ''));
            $mime = (string) ($upload?->getMimeType() ?? '');
            $allowedReceiptMimes = ['jpg' => 'image/jpeg', 'jpeg' => 'image/jpeg', 'png' => 'image/png', 'webp' => 'image/webp'];
            if (! $upload || ! $upload->isValid() || ! isset($allowedReceiptMimes[$extension]) || $mime !== $allowedReceiptMimes[$extension] || $upload->getSize() > 8 * 1024 * 1024) {
                $this->flash('Attach a clear JPG, PNG, or WebP transfer receipt up to 8 MB.', 'error');
                return $this->go('pay', ['ekub_id' => $ekubId, 'period_no' => $periodNo]);
            }

            $existingPayment = DB::table('payments')->where('transaction_no', $transaction)->first();
            if ($existingPayment) {
                $sameOwner = (int) $existingPayment->user_id === (int) $user['id'];
                $message = $sameOwner
                    ? 'This transaction was already submitted and is '.ucfirst((string) $existingPayment->status).'. Open My Status to view it.'
                    : 'This transaction reference has already been used. Check your receipt reference or contact an administrator.';
                $this->flash($message, 'error');
                return $this->go($sameOwner ? 'status' : 'pay', $sameOwner ? [] : ['ekub_id' => $ekubId, 'period_no' => $periodNo]);
            }

            $screenshot = $this->saveUpload($upload, null, null, array_keys($allowedReceiptMimes));
            $currency = $isBinance ? 'USDT' : 'ETB';
            $currencyAmount = $isBinance ? round($amount / $exchangeRate, 8) : $amount;
            DB::table('payments')->insert([
                'ekub_id' => $ekubId,
                'member_id' => $member['id'],
                'user_id' => $user['id'],
                'period_no' => $periodNo,
                'amount' => $amount,
                'penalty' => $balance['penalty'],
                'method' => $method,
                'transaction_no' => $transaction,
                'screenshot' => $screenshot,
                'status' => 'pending',
                'approved_amount' => 0,
                'verification_status' => 'not_checked',
                'payment_currency' => $currency,
                'payment_currency_amount' => $currencyAmount,
                'payment_exchange_rate' => $exchangeRate,
                'submitted_at' => now(),
            ]);
            $this->flash('Payment sent to the administrator for manual verification.', 'success');
            return $this->go('status');
        }

        return $this->page('payment', [
            'ekub' => $ekub,
            'member' => $member,
            'period_no' => $periodNo,
            'bal' => $balance,
            'methods' => config('ekub.methods', []),
            'payment_accounts' => config('ekub.payment_accounts', []),
            'payment_account_holder' => config('ekub.payment_account_holder', ''),
            'binance_etb_per_usdt' => (float) config('ekub.binance_etb_per_usdt', 0),
        ]);
    }
    public function adminLogin() { return $this->go('login'); }
    private function adminEkubRows(?bool $fullOnly = null): array
    {
        $ekubs=$this->rows(DB::table('ekubs')->where('status','!=','finished')->orderByDesc('id')->get());
        foreach($ekubs as &$e){
            $used=$this->ekubs->usedCapacity((int)$e['id']);
            $left=max((float)$e['duration']-$used,0);
            $e['joined_count']=DB::table('ekub_members')->where('ekub_id',$e['id'])->count();
            $e['left_slots']=floor($left)===$left?(int)$left:round($left,2);
            $e['is_full']=$left<=0.000001;
            $e['can_pick_winner']=false;
            $e['ready_members']=0;
            if($e['status']==='started'&&(int)$e['current_period']>0){
                $members=$this->rows(DB::table('ekub_members')->where('ekub_id',$e['id'])->get());
                foreach($members as $member){
                    if($this->ekubs->periodBalance($e,$member,(int)$e['current_period'])['fully_paid'])$e['ready_members']++;
                }
                $e['can_pick_winner']=$members&&$e['ready_members']===count($members)
                    &&$this->ekubs->drawError($e,(int)$e['current_period'])===null;
            }
        }
        unset($e);
        if($fullOnly!==null)$ekubs=array_values(array_filter($ekubs,fn($e)=>(bool)$e['is_full']===$fullOnly));
        return $ekubs;
    }
    public function adminDashboard()
    {
        $all=$this->adminEkubRows();
        $ekubs=array_values(array_filter($all,fn($e)=>!$e['is_full']));
        return $this->page('admin_dashboard',['ekubs'=>$ekubs,'full_count'=>count($all)-count($ekubs),'pending'=>DB::table('payments')->where('status','pending')->count(),'kycs'=>DB::table('kyc_verifications')->where('status','pending')->count(),'partners'=>DB::table('partners')->count()]);
    }
    public function adminFullEkubs()
    {
        $ekubs=array_values(array_filter($this->adminEkubRows(true),fn($e)=>$e['status']==='open'));
        return $this->page('admin_full_ekubs',['ekubs'=>$ekubs]);
    }
    public function adminPickWinners()
    {
        $ekubs=array_values(array_filter($this->adminEkubRows(),fn($e)=>$e['status']==='started'&&$e['can_pick_winner']));
        return $this->page('admin_pick_winners',['ekubs'=>$ekubs]);
    }
    public function createEkub(Request $request)
    {
        if($request->isMethod('post')){
            $name=trim((string)$request->input('name'));$category=(string)$request->input('category');$frequency=(string)$request->input('frequency');$amount=(float)$request->input('base_amount');$duration=(int)$request->input('duration');$isItem=$category==="Item's Ekub";
            if(!$name||!in_array($category,config('ekub.categories'),true)||!in_array($frequency,config('ekub.frequencies'),true)||$amount<=0||$duration<1){$this->flash('Enter a name, category, frequency, amount, and valid duration.','error');return $this->go('create_ekub');}
            try{$images=[];foreach((array)$request->file('images',[]) as $file){if(!$isItem)break;$img=$this->imageUpload($file,'ekub_items',$name);if($img)$images[]=$img;}$createdId=DB::transaction(fn()=> $this->insertEkub($name,$category,$frequency,$amount,$duration,$isItem,$images));$this->notifyEkubCreated((int)$createdId);$this->flash('Ekub created successfully. Members were notified.','success');return $this->go('admin_dashboard');}
            catch(Throwable $e){$this->flash($e->getMessage(),'error');}
        }
        return $this->page('create_ekub');
    }
    private function ekubIsEditable(array $ekub): bool
    {
        return $ekub['status']==='open'
            && !DB::table('ekub_members')->where('ekub_id',$ekub['id'])->exists()
            && !DB::table('payments')->where('ekub_id',$ekub['id'])->exists()
            && !DB::table('payouts')->where('ekub_id',$ekub['id'])->exists();
    }
    private function ekubImagePaths(int $ekubId, array $ekub): array
    {
        $images=DB::table('ekub_images')->where('ekub_id',$ekubId)->orderBy('position')->orderBy('id')->pluck('image')->all();
        if(!$images)$images=array_values(array_filter([$ekub['product1']??null,$ekub['product2']??null,$ekub['product3']??null]));
        return array_values(array_unique(array_filter($images)));
    }
    private function removeEkubImageFiles(array $paths): void
    {
        $root=realpath(public_path('static/uploads'));
        if(!$root)return;
        foreach(array_unique(array_filter($paths)) as $relative){
            $file=realpath(public_path('static/uploads/'.ltrim((string)$relative,'/\\')));
            if($file&&str_starts_with(strtolower($file),strtolower($root.DIRECTORY_SEPARATOR))&&is_file($file))@unlink($file);
        }
    }
    public function editEkub(int $ekubId, Request $request)
    {
        $ekub=$this->row(DB::table('ekubs')->where('id',$ekubId)->first());
        if(!$ekub){$this->flash('Ekub not found.','error');return $this->go('admin_dashboard');}
        if(!$this->ekubIsEditable($ekub)){$this->flash('Only an open Ekub with no members, payments, or payouts can be edited.','error');return $this->go('admin_dashboard');}
        $existingImages=$this->ekubImagePaths($ekubId,$ekub);
        if(!$request->isMethod('post'))return $this->page('create_ekub',['edit_mode'=>true,'ekub'=>$ekub,'existing_images'=>$existingImages]);

        $name=trim((string)$request->input('name'));$category=(string)$request->input('category');$frequency=(string)$request->input('frequency');
        $amount=$request->input('base_amount');$duration=$request->input('duration');$isItem=$category==="Item's Ekub";
        if(!$name||mb_strlen($name)>80||!in_array($category,config('ekub.categories'),true)||!in_array($frequency,config('ekub.frequencies'),true)||!is_numeric($amount)||(float)$amount<=0||!filter_var($duration,FILTER_VALIDATE_INT)||((int)$duration)<1||((int)$duration)>500){
            $this->flash('Enter a name (up to 80 characters), valid category and frequency, positive amount, and duration from 1 to 500.','error');
            return $this->go('admin_edit_ekub',['ekub_id'=>$ekubId]);
        }
        $rawUploads=$request->file('images',[]);$files=$rawUploads instanceof \Illuminate\Http\UploadedFile?[$rawUploads]:(array)$rawUploads;
        $files=array_values(array_filter($files,fn($file)=>$file instanceof \Illuminate\Http\UploadedFile&&$file->isValid()));
        if(!$isItem&&$files){$this->flash("Images can only be added to an Item's Ekub.",'error');return $this->go('admin_edit_ekub',['ekub_id'=>$ekubId]);}
        foreach($files as $file){
            $extension=strtolower($file->getClientOriginalExtension());
            if(!in_array($extension,['png','jpg','jpeg','webp','gif'],true)||$file->getSize()>50*1024*1024){$this->flash('Ekub images must be PNG, JPG, WEBP, or GIF files up to 50 MB each.','error');return $this->go('admin_edit_ekub',['ekub_id'=>$ekubId]);}
        }
        $remove=array_values(array_intersect($existingImages,array_map('strval',(array)$request->input('remove_images',[]))));
        if(!$isItem)$remove=$existingImages;
        $kept=array_values(array_diff($existingImages,$remove));$newImages=[];
        try{
            if($isItem)foreach($files as $file){$saved=$this->imageUpload($file,'ekub_items',$name);if($saved)$newImages[]=$saved;}
            $finalImages=array_merge($kept,$newImages);
            DB::transaction(function()use($ekubId,$name,$category,$frequency,$amount,$duration,$isItem,$finalImages){
                $locked=$this->row(DB::table('ekubs')->where('id',$ekubId)->lockForUpdate()->first());
                if(!$locked||!$this->ekubIsEditable($locked))throw new \RuntimeException('This Ekub changed and can no longer be edited safely.');
                DB::table('ekubs')->where('id',$ekubId)->update(['name'=>$name,'category'=>$category,'frequency'=>$frequency,'base_amount'=>round((float)$amount,2),'duration'=>(int)$duration,'is_item'=>$isItem,'product1'=>$finalImages[0]??null,'product2'=>$finalImages[1]??null,'product3'=>$finalImages[2]??null]);
                DB::table('ekub_images')->where('ekub_id',$ekubId)->delete();
                foreach($finalImages as $position=>$image)DB::table('ekub_images')->insert(['ekub_id'=>$ekubId,'image'=>$image,'position'=>$position,'created_at'=>now()]);
            });
            $this->removeEkubImageFiles($remove);
            $this->flash('Ekub updated successfully.','success');return $this->go('admin_dashboard');
        }catch(Throwable $e){$this->removeEkubImageFiles($newImages);$this->flash($e->getMessage(),'error');return $this->go('admin_edit_ekub',['ekub_id'=>$ekubId]);}
    }
    public function deleteEkub(int $ekubId)
    {
        $ekub=$this->row(DB::table('ekubs')->where('id',$ekubId)->first());
        if(!$ekub){$this->flash('Ekub not found.','error');return $this->go('admin_dashboard');}
        if(!$this->ekubIsEditable($ekub)){$this->flash('This Ekub cannot be deleted because it has members, payments, payouts, or has already started.','error');return $this->go('admin_dashboard');}
        $images=$this->ekubImagePaths($ekubId,$ekub);
        try{
            DB::transaction(function()use($ekubId){
                $locked=$this->row(DB::table('ekubs')->where('id',$ekubId)->lockForUpdate()->first());
                if(!$locked||!$this->ekubIsEditable($locked))throw new \RuntimeException('This Ekub changed and can no longer be deleted safely.');
                DB::table('ekub_applications')->where('created_ekub_id',$ekubId)->update(['created_ekub_id'=>null]);
                DB::table('ekubs')->where('id',$ekubId)->delete();
            });
            $this->removeEkubImageFiles($images);
            $this->flash('Ekub deleted successfully.','success');
        }catch(Throwable $e){$this->flash($e->getMessage(),'error');}
        return $this->go('admin_dashboard');
    }
    public function adminEkubInformation(int $ekubId)
    {
        $ekub=$this->row(DB::table('ekubs')->where('id',$ekubId)->first());if(!$ekub)return $this->page('error',['code'=>404,'message'=>'Ekub not found.']);
        $members=$this->rows(DB::table('ekub_members as em')->join('users as u','u.id','=','em.user_id')->where('em.ekub_id',$ekubId)->orderBy('em.id')->get(['em.*','u.first_name','u.last_name','u.username','u.phone','u.profile_picture']));
        return $this->page('admin_ekub_information',['ekub'=>$ekub,'members'=>$members,'winners'=>$this->ekubs->winners($ekubId)]);
    }
    public function startEkub(int $ekubId)
    {
        $ekub=$this->row(DB::table('ekubs')->where('id',$ekubId)->first());if(!$ekub){$this->flash('Ekub not found.','error');return $this->go('admin_dashboard');}
        $members=$this->rows(DB::table('ekub_members')->where('ekub_id',$ekubId)->get());$used=array_sum(array_column($members,'share_fraction'));
        $valid=$ekub['is_item'] ? count($members)>=(int)$ekub['duration'] && collect($members)->every(fn($m)=>$m['share_type']==='full') : $used>=(float)$ekub['duration'];
        if(!$valid||$ekub['status']!=='open'){$this->flash('Required effective membership is not complete.','error');return $this->go('admin_dashboard');}
        DB::table('ekubs')->where('id',$ekubId)->update(['status'=>'started','start_at'=>now(),'period_started_at'=>now(),'current_period'=>1]);DB::table('period_dues')->updateOrInsert(['ekub_id'=>$ekubId,'period_no'=>1],['started_at'=>now()]);
        $this->notifyEkubMembers($ekubId,'ekub_started','Your Ekub has started',"{$ekub['name']} has started. Period 1 contributions are now due.",'ekub.started:'.$ekubId);
        $this->flash('Ekub started successfully.','success');return $this->go('admin_dashboard');
    }

    private function approvalRows(?int $ekubId = null, ?int $period = null): array
    {
        $q=DB::table('payments as p')->join('users as u','u.id','=','p.user_id')->join('ekubs as e','e.id','=','p.ekub_id')->select('p.*','u.first_name','u.last_name','u.username','u.phone','u.email','e.name as ekub_name','e.category','e.frequency');
        if($ekubId)$q->where('p.ekub_id',$ekubId);if($period)$q->where('p.period_no',$period);
        return $this->rows($q->orderByDesc('p.id')->get());
    }
    private function approvalEkubs(): array
    {
        return $this->rows(DB::table('ekubs as e')->join('payments as p','p.ekub_id','=','e.id')->where('p.status','pending')->groupBy('e.id')->orderByDesc('e.id')->get(['e.*',DB::raw('COUNT(p.id) as pending_count')]));
    }
    public function adminPaymentStatus()
    {
        $ekubs=$this->rows(DB::table('ekubs')->where('status','started')->orderByDesc('id')->get());
        foreach($ekubs as &$e){$e['member_count']=DB::table('ekub_members')->where('ekub_id',$e['id'])->count();$e['pending_count']=DB::table('payments')->where('ekub_id',$e['id'])->where('status','pending')->count();}
        unset($e);return $this->page('payment_status',['ekubs'=>$ekubs]);
    }
    public function adminPaymentStatusDetail(int $ekubId, Request $request)
    {
        $ekub=$this->row(DB::table('ekubs')->where('id',$ekubId)->where('status','started')->first());if(!$ekub)return $this->page('error',['code'=>404,'message'=>'Started Ekub not found.']);
        $period=max(1,min((int)$request->query('period',$ekub['current_period'] ?: 1),(int)$ekub['duration']));
        $members=$this->rows(DB::table('ekub_members as m')->join('users as u','u.id','=','m.user_id')->where('m.ekub_id',$ekubId)->orderBy('m.id')->get(['m.*','u.first_name','u.last_name','u.username','u.phone','u.email']));
        foreach($members as &$member){$member['bal']=$this->ekubs->periodBalance($ekub,$member,$period);$member['payments']=$member['bal']['payments'];$member['payment_status']=$member['bal']['fully_paid']?'approved':($member['bal']['pending']>0?($member['bal']['paid']>0?'partial':'pending'):(collect($member['bal']['payments'])->contains(fn($p)=>$p['status']==='rejected')?'rejected':'unpaid'));}
        unset($member);return $this->page('payment_status_detail',['ekub'=>$ekub,'members'=>$members,'period'=>$period]);
    }
    public function sendPaymentReminder(int $ekubId, Request $request)
    {
        $period=max(1,(int)$request->input('period',1));$ekub=$this->row(DB::table('ekubs')->where('id',$ekubId)->first());if(!$ekub)return $this->go('admin_payment_status');
        $members=$this->rows(DB::table('ekub_members as m')->join('users as u','u.id','=','m.user_id')->where('m.ekub_id',$ekubId)->get(['m.*','u.email','u.first_name','u.username']));$sent=0;
        foreach($members as $m){$b=$this->ekubs->periodBalance($ekub,$m,$period);if($b['fully_paid']||!$m['email'])continue;try{BrandedEmail::send($m['email'],"Payment reminder: {$ekub['name']}",'Payment reminder',"Hello {$m['first_name']}, Period {$period} payment for {$ekub['name']} is due. Please sign in to submit your payment.");$sent++;}catch(Throwable){}}
        $this->flash("Payment reminders sent to {$sent} member(s).",'success');return $this->go('admin_payment_status_detail',['ekub_id'=>$ekubId,'period'=>$period]);
    }
    public function adminPaymentApproval() { return $this->page('payment_ekubs',['ekubs'=>$this->approvalEkubs(),'link_endpoint'=>'admin_payment_approval_ekub']); }
    public function adminPaymentApprovalEkub(int $ekubId)
    {
        $ekub=$this->row(DB::table('ekubs')->where('id',$ekubId)->first());if(!$ekub)return $this->page('error',['code'=>404,'message'=>'Ekub not found.']);
        return $this->page('payment_approval',['rows'=>$this->approvalRows($ekubId),'ekub'=>$ekub,'all_payments'=>true,'back_url'=>route_url('admin_payment_approval')]);
    }
    public function adminPaymentApprovalAll() { return $this->page('payment_approval',['rows'=>$this->approvalRows(),'all_payments'=>true]); }
    public function adminPayments(int $ekubId,int $periodNo) { return $this->page('payment_approval',['rows'=>$this->approvalRows($ekubId,$periodNo),'ekub_id'=>$ekubId,'period_no'=>$periodNo]); }
    public function paymentAction(int $paymentId,string $action)
    {
        $user=$this->currentUser();if($user['role']!=='admin'&&!$this->partnerAllowed('payment_approval'))return $this->page('error',['code'=>403,'message'=>'Payment approval permission required.']);
        if(!in_array($action,['approve','reject'],true))return $this->go('admin_dashboard');
        $p=$this->row(DB::table('payments')->where('id',$paymentId)->first());if(!$p)return $this->go('admin_dashboard');
        if($action==='approve'){
            $balance=$this->ekubs->payBalance($p);$amount=round((float)request()->input('approved_amount',$p['amount']),2);
            if($p['status']!=='pending'||$amount<=0||$amount>(float)$p['amount']||$amount>(float)$balance['left']){$this->flash('The approval amount is outside the remaining balance.','error');}
            else {
                DB::table('payments')->where('id',$paymentId)->update(['status'=>'approved','approved_amount'=>$amount,'approved_by'=>$user['username'],'reviewed_at'=>now()]);
                $amountLabel=number_format($amount,2,'.',',');
                $this->notifyMemberEvent((int)$p['user_id'],'payment','Payment approved',"Your payment for Ekub #{$p['ekub_id']}, Period {$p['period_no']} was approved ({$amountLabel} ETB).",'payment.approved:'.$paymentId);
            }
        } else {
            DB::table('payments')->where('id',$paymentId)->update(['status'=>'rejected','rejection_reason'=>trim((string)request()->input('reason')),'approved_by'=>$user['username'],'reviewed_at'=>now(),'approved_amount'=>0]);
            $reason=trim((string)request()->input('reason'));
            $this->notifyMemberEvent((int)$p['user_id'],'payment','Payment needs attention',"Your payment for Ekub #{$p['ekub_id']}, Period {$p['period_no']} was rejected.".($reason?' Reason: '.$reason:''),'payment.rejected:'.$paymentId);
        }
        $this->flash($action==='approve'?'Payment approved.':'Payment rejected.','success');
        return $this->go($user['role']==='partner'?'partner_payment_approval_ekub':'admin_payment_approval_ekub',['ekub_id'=>$p['ekub_id']]);
    }

    public function adminKyc()
    {
        $rows=$this->rows(DB::table('kyc_verifications as k')->join('users as u','u.id','=','k.user_id')->orderByRaw("CASE k.status WHEN 'pending' THEN 0 ELSE 1 END")->orderByDesc('k.id')->get(['k.*','u.first_name','u.last_name','u.username','u.phone']));
        return $this->page('kyc_approval',['rows'=>$rows,'pending_count'=>DB::table('kyc_verifications')->where('status','pending')->count()]);
    }
    public function kycAction(int $kycId,string $action)
    {
        $user=$this->currentUser();if($user['role']!=='admin'&&!$this->partnerAllowed('kyc_approval'))return $this->page('error',['code'=>403,'message'=>'KYC approval permission required.']);
        $kyc=$this->row(DB::table('kyc_verifications')->where('id',$kycId)->first());if(!$kyc)return $this->go('admin_kyc');
        if($action==='approve'){DB::table('kyc_verifications')->where('id',$kycId)->update(['status'=>'approved','approved_by'=>$user['username'],'reviewed_at'=>now(),'rejection_reason'=>null]);DB::table('users')->where('id',$kyc['user_id'])->update(['kyc_status'=>'approved']);$this->notifyMemberEvent((int)$kyc['user_id'],'identity','Identity verification approved','Your identity verification has been approved. You can now join available Ekubs.','identity.approved:'.$kycId);$this->flash('KYC approved.','success');}
        elseif($action==='reject'){$reason=trim((string)request()->input('reason'));DB::table('kyc_verifications')->where('id',$kycId)->update(['status'=>'rejected','approved_by'=>$user['username'],'reviewed_at'=>now(),'rejection_reason'=>$reason]);DB::table('users')->where('id',$kyc['user_id'])->update(['kyc_status'=>'rejected']);$this->notifyMemberEvent((int)$kyc['user_id'],'identity','Identity verification needs attention','Your identity verification was not approved.'.($reason?' Reason: '.$reason:''),'identity.rejected:'.$kycId);$this->flash('KYC rejected.','success');}
        return $this->go('admin_kyc');
    }
    public function adminMembers()
    {
        $rows=$this->rows(DB::table('users as u')->join('kyc_verifications as k','k.user_id','=','u.id')->leftJoin('payment_methods as pm',function($join){$join->on('pm.user_id','=','u.id')->where('pm.is_default',1);})->where('u.kyc_status','approved')->orderBy('u.id')->get(['u.*','k.full_name as kyc_name','k.dob','k.gender','k.id_type','k.id_number','k.id_front','k.id_back','k.personal_photo','k.video_agreement','k.approved_by','pm.bank_name as pm_bank','pm.account_number as pm_number','pm.account_name as pm_name']));
        return $this->page('members',['rows'=>$rows]);
    }
    public function partnerMembers()
    {
        if(!$this->partnerAllowed('member_info'))return $this->page('error',['code'=>403,'message'=>'Member information permission required.']);
        return $this->page('partner_members',['rows'=>$this->rows(DB::table('users as u')->join('kyc_verifications as k','k.user_id','=','u.id')->leftJoin('payment_methods as pm',function($join){$join->on('pm.user_id','=','u.id')->where('pm.is_default',1);})->where('u.kyc_status','approved')->get(['u.*','k.full_name as kyc_name','k.dob','k.gender','k.id_type','k.id_number','k.id_front','k.id_back','k.personal_photo','k.video_agreement','k.approved_by','pm.bank_name as pm_bank','pm.account_number as pm_number','pm.account_name as pm_name'])),'partner'=>true]);
    }
    public function partnerKyc() { if(!$this->partnerAllowed('kyc_approval'))return $this->page('error',['code'=>403,'message'=>'KYC permission required.']);return $this->adminKyc(); }
    public function paymentMethods(Request $request)
    {
        $user=$this->currentUser();
        if($request->isMethod('post')){
            $bank=trim((string)$request->input('bank_name'));$number=preg_replace('/[^0-9]/','',(string)$request->input('account_number'));$name=trim((string)$request->input('account_name'));
            if(!in_array($bank,config('ekub.banks'),true)||strlen($number)<6||strlen($number)>26||strlen($name)<3){$this->flash('Enter a valid bank, account number, and account name.','error');return $this->go('payment_methods');}
            if(DB::table('payment_methods')->where('user_id',$user['id'])->count()>=5){$this->flash('You can save up to 5 accounts.','error');return $this->go('payment_methods');}
            if(DB::table('payment_methods')->where('user_id',$user['id'])->where('bank_name',$bank)->where('account_number',$number)->exists()){$this->flash('That payment method is already saved.','error');return $this->go('payment_methods');}
            $isFirst=!DB::table('payment_methods')->where('user_id',$user['id'])->exists();DB::table('payment_methods')->insert(['user_id'=>$user['id'],'bank_name'=>$bank,'account_number'=>$number,'account_name'=>$name,'is_default'=>$isFirst,'created_at'=>now()]);$this->flash('Payment method added.','success');return $this->go('payment_methods');
        }
        return $this->page('payment_methods',['rows'=>$this->rows(DB::table('payment_methods')->where('user_id',$user['id'])->orderByDesc('is_default')->orderBy('id')->get()),'banks'=>config('ekub.banks')]);
    }
    public function paymentMethodDelete(int $pmId)
    {
        DB::table('payment_methods')->where('id',$pmId)->where('user_id',session('user_id'))->delete();$this->flash('Payment method removed.','success');return $this->go('payment_methods');
    }
    public function paymentMethodDefault(int $pmId)
    {
        $userId=session('user_id');$exists=DB::table('payment_methods')->where('id',$pmId)->where('user_id',$userId)->exists();
        if($exists){DB::table('payment_methods')->where('user_id',$userId)->update(['is_default'=>0]);DB::table('payment_methods')->where('id',$pmId)->update(['is_default'=>1]);$this->flash('Default payment method updated.','success');}
        return $this->go('payment_methods');
    }
    public function settings()
    {
        $user=$this->currentUser();return $this->page('settings',['reasons'=>config('ekub.delete_reasons'),'twofa_on'=>(bool)$user['twofa_enabled'],'twofa_method'=>$user['twofa_method']??'authenticator']);
    }
    public function sendSecurityEmailOtp(Request $request)
    {
        $user=$this->currentUser(); $open=in_array($request->input('open'),['username','password'],true)?$request->input('open'):'password';
        if (!$user || !$user['twofa_enabled'] || !$this->hasEmailOtp($user)) $this->flash('Enable email OTP first to request a security code.','error');
        else { try { $this->issueEmailOtp($user,'sensitive'); $this->flash($this->emailOtpDeliveryNotice($user['email'] ?? null,'security'),'success'); } catch (Throwable $e) { $this->flash($e instanceof \RuntimeException?$e->getMessage():'Could not send an email code. Check the mail settings and try again.','error'); } }
        return $this->go('settings',['open'=>$open]);
    }
    private function authenticatorOk(array $user, string $code): bool
    {
        if (!in_array($user['role'],['admin','partner'],true) || !$user['twofa_enabled']) return true;
        if ($this->hasEmailOtp($user) && $this->verifyEmailOtp($user,$code,'sensitive')) return true;
        return $this->hasAuthenticator($user) && (bool)(new Google2FA())->verifyKey($user['totp_secret'],$code);
    }
    public function changeUsername(Request $request)
    {
        $user=$this->currentUser();$username=trim((string)$request->input('new_username'));
        if($user['role']!=='admin'||!Hash::check((string)$request->input('current_password'),$user['password_hash'])||!$this->authenticatorOk($user,(string)$request->input('auth_code'))){$this->flash('Current password or authenticator code is incorrect.','error');return $this->go('settings',['open'=>'username']);}
        if(!preg_match('/^[A-Za-z0-9_.]{3,30}$/',$username)||DB::table('users')->where('username',$username)->where('id','!=',$user['id'])->exists()){$this->flash('Choose an available username using 3-30 letters, numbers, dots or underscores.','error');return $this->go('settings',['open'=>'username']);}
        DB::table('users')->where('id',$user['id'])->update(['username'=>$username]);session()->put('username',$username);$this->flash('Username updated.','success');return $this->go('settings');
    }
    public function changePassword(Request $request)
    {
        $user=$this->currentUser();$current=(string)$request->input('current_password');$new=(string)$request->input('new_password');
        if(!Hash::check($current,$user['password_hash'])||!$this->authenticatorOk($user,(string)$request->input('auth_code'))){$this->flash('Current password or authenticator code is incorrect.','error');return $this->go('settings',['open'=>'password']);}
        if(!$this->validPassword($new)||$new!==$request->input('confirm_password')){$this->flash('New passwords must match and include at least 8 characters, an uppercase letter, a number, and a special character.','error');return $this->go('settings',['open'=>'password']);}
        DB::table('users')->where('id',$user['id'])->update(['password_hash'=>Hash::make($new)]);$this->flash('Password updated.','success');return $this->go('settings');
    }
    public function deleteAccount(Request $request)
    {
        $user=$this->currentUser();
        if ($user['role'] !== 'member') return response()->view('error',['code'=>403,'message'=>'Only member accounts can be deleted here.'],403);
        $reason=(string)$request->input('reason');$details=trim((string)$request->input('details'));
        if(!in_array($reason,config('ekub.delete_reasons'),true)||($reason==='Other'&&!$details)){$this->flash('Please choose a reason and provide details for Other.','error');return $this->go('settings');}
        if(!Hash::check((string)$request->input('password'),$user['password_hash'])){$this->flash('Incorrect password. Your account was not deleted.','error');return $this->go('settings');}
        $active=DB::table('ekub_members as m')->join('ekubs as e','e.id','=','m.ekub_id')->where('m.user_id',$user['id'])->where('e.status','started')->first(['e.name']);
        if($active){$this->flash('You cannot delete your account while you are part of the running Ekub "'.$active->name.'". Please wait until it finishes.','error');return $this->go('settings');}
        DB::transaction(function()use($user,$reason,$details){DB::table('deleted_accounts')->insert(['user_id'=>$user['id'],'full_name'=>trim($user['first_name'].' '.$user['last_name']),'username'=>$user['username'],'phone'=>$user['phone'],'email'=>$user['email'],'role'=>$user['role'],'reason'=>$reason,'details'=>$details?:null,'deleted_at'=>now()]);DB::table('users')->where('id',$user['id'])->delete();});
        session()->invalidate();session()->regenerateToken();$this->flash('Your account has been deleted.','success');return $this->go('home');
    }
    public function adminDeletedAccounts() { return $this->page('deleted_accounts',['rows'=>$this->rows(DB::table('deleted_accounts')->orderByDesc('deleted_at')->get())]); }
    public function adminSuspendMembers()
    {
        $rows=$this->rows(DB::table('users as u')->leftJoin('kyc_verifications as k','k.user_id','=','u.id')->where('u.role','member')->orderBy('u.id')->get(['u.*','k.gender','k.dob','k.id_type','k.id_number']));return $this->page('suspend_members',['rows'=>$rows]);
    }
    public function memberSuspendAction(int $userId,string $action)
    {
        if(!in_array($action,['suspend','activate'],true))return $this->page('error',['code'=>404,'message'=>'Action not found.']);
        $user=$this->row(DB::table('users')->where('id',$userId)->where('role','member')->first());if(!$user){$this->flash('Member not found.','error');return $this->go('admin_suspend_members');}
        DB::table('users')->where('id',$userId)->update(['status'=>$action==='suspend'?'suspended':'active']);$this->flash($action==='suspend'?'Member suspended.':'Member activated.','success');return $this->go('admin_suspend_members');
    }
    public function partners(Request $request)
    {
        if($request->isMethod('post')){
            $first=trim((string)$request->input('first_name'));$last=trim((string)$request->input('last_name'));$username=trim((string)$request->input('username'));$phone=$this->normalizedPhone((string)$request->input('phone'));$email=trim((string)$request->input('email'))?:null;$password=(string)$request->input('password');$perms=array_intersect((array)$request->input('permissions',[]),['payment_approval','kyc_approval','member_info','recent_winner']);
            if(!$first||!$last||!$phone||!$username||!$this->validPassword($password))$this->flash('Complete the required fields and use a strong password.','error');
            elseif(DB::table('users')->where('username',$username)->orWhere('phone',$phone)->when($email,fn($q)=>$q->orWhere('email',$email))->exists())$this->flash('Username, phone, or email already exists.','error');
            else{DB::transaction(function()use($first,$last,$username,$phone,$email,$password,$perms){$id=DB::table('users')->insertGetId(['first_name'=>$first,'last_name'=>$last,'username'=>$username,'phone'=>$phone,'email'=>$email,'password_hash'=>Hash::make($password),'role'=>'partner','status'=>'active','kyc_status'=>'approved','created_at'=>now()]);DB::table('partners')->insert(['user_id'=>$id,'permissions'=>implode(',',$perms),'created_at'=>now()]);});$this->flash('Partner account created.','success');return $this->go('partners');}
        }
        $rows=$this->rows(DB::table('partners as p')->join('users as u','u.id','=','p.user_id')->orderBy('u.first_name')->get(['p.permissions','u.id','u.first_name','u.last_name','u.username','u.phone','u.email']));return $this->page('partners',['rows'=>$rows]);
    }
    public function deletePartner(int $pid)
    {
        $partner=DB::table('partners')->where('user_id',$pid)->first();if($partner)DB::table('users')->where('id',$pid)->where('role','partner')->delete();$this->flash('Partner removed.','success');return $this->go('partners');
    }
    public function partnerLogin() { return $this->go('login'); }
    public function partnerDashboard()
    {
        $user=$this->currentUser();if($user['role']==='admin')return $this->go('admin_dashboard');if($user['role']!=='partner')return $this->go('dashboard');
        $permissions=array_values(array_filter(explode(',',DB::table('partners')->where('user_id',$user['id'])->value('permissions')??'')));
        return $this->page('partner_dashboard',['permissions'=>$permissions]);
    }
    public function partnerPaymentApproval()
    {
        if(!$this->partnerAllowed('payment_approval'))return $this->page('error',['code'=>403,'message'=>'Payment approval permission required.']);
        return $this->page('payment_ekubs',['ekubs'=>$this->approvalEkubs(),'link_endpoint'=>'partner_payment_approval_ekub']);
    }
    public function partnerPaymentApprovalEkub(int $ekubId)
    {
        if(!$this->partnerAllowed('payment_approval'))return $this->page('error',['code'=>403,'message'=>'Payment approval permission required.']);
        $ekub=$this->row(DB::table('ekubs')->where('id',$ekubId)->first());if(!$ekub)return $this->page('error',['code'=>404,'message'=>'Ekub not found.']);
        return $this->page('payment_approval',['rows'=>$this->approvalRows($ekubId),'ekub'=>$ekub,'all_payments'=>true,'partner'=>true,'back_url'=>route_url('partner_payment_approval')]);
    }
    public function partnerPaymentApprovalAll()
    {
        if(!$this->partnerAllowed('payment_approval'))return $this->page('error',['code'=>403,'message'=>'Payment approval permission required.']);
        return $this->page('payment_approval',['rows'=>$this->approvalRows(),'all_payments'=>true,'partner'=>true]);
    }
    public function partnerPayment(int $ekubId,int $periodNo)
    {
        if(!$this->partnerAllowed('payment_approval'))return $this->page('error',['code'=>403,'message'=>'Payment permission required.']);
        return $this->page('payment_approval',['rows'=>$this->approvalRows($ekubId,$periodNo),'ekub_id'=>$ekubId,'period_no'=>$periodNo,'partner'=>true]);
    }
    private function drawState(int $ekubId,int $periodNo): array
    {
        $ekub=$this->row(DB::table('ekubs')->where('id',$ekubId)->first());if(!$ekub)return ['ekub'=>null,'members'=>[],'approved'=>0,'drawn'=>false,'error'=>'Ekub not found.'];
        $members=$this->rows(DB::table('ekub_members as m')->join('users as u','u.id','=','m.user_id')->where('m.ekub_id',$ekubId)->orderBy('m.id')->get(['m.*','u.first_name','u.last_name','u.username','u.phone']));
        $approved=0;foreach($members as $member)if($this->ekubs->periodBalance($ekub,$member,$periodNo)['fully_paid'])$approved++;
        $drawn=DB::table('payouts')->where('ekub_id',$ekubId)->where('period_no',$periodNo)->exists();
        return ['ekub'=>$ekub,'members'=>$members,'approved'=>$approved,'drawn'=>$drawn,'error'=>$this->ekubs->drawError($ekub,$periodNo)];
    }
    private function finishIfComplete(int $ekubId): ?int
    {
        $ekub=$this->row(DB::table('ekubs')->where('id',$ekubId)->first());if(!$ekub||$ekub['status']!=='started')return null;
        $count=DB::table('payouts')->where('ekub_id',$ekubId)->count();if($count<(int)$ekub['duration'])return null;
        DB::table('ekubs')->where('id',$ekubId)->update(['status'=>'finished','finished_at'=>now()]);
        $images=$ekub['is_item']?$this->ekubs->images($ekub):[];
        return $this->insertEkub($ekub['name'],$ekub['category'],$ekub['frequency'],(float)$ekub['base_amount'],(int)$ekub['duration'],(bool)$ekub['is_item'],$images,$ekubId);
    }
    private function performDraw(int $ekubId,int $periodNo): array
    {
        $draw = DB::transaction(function()use($ekubId,$periodNo){
            $state=$this->drawState($ekubId,$periodNo);$ekub=$state['ekub'];
            if(!$ekub)return ['error'=>'Ekub not found.'];
            if($state['error'])return ['error'=>$state['error']];
            $winnerIndex=random_int(0,count($state['members'])-1);$winner=$state['members'][$winnerIndex];
            $gross=(float)DB::table('payments')->where('ekub_id',$ekubId)->where('period_no',$periodNo)->where('status','approved')->sum('approved_amount');$fee=round($gross*0.02,2);$net=round($gross*0.98,2);
            DB::table('payouts')->insert(['ekub_id'=>$ekubId,'period_no'=>$periodNo,'winner_member_id'=>$winner['id'],'gross_amount'=>$gross,'service_fee'=>$fee,'net_amount'=>$net,'status'=>'pending','created_at'=>now(),'celebrated'=>0]);
            $next=min((int)$ekub['duration'],$periodNo+1);DB::table('ekubs')->where('id',$ekubId)->update(['current_period'=>$next]);
            if($next>$periodNo){DB::table('ekubs')->where('id',$ekubId)->update(['period_started_at'=>now()]);DB::table('period_dues')->updateOrInsert(['ekub_id'=>$ekubId,'period_no'=>$next],['started_at'=>now()]);}
            $newId=$periodNo >= (int)$ekub['duration'] ? $this->finishIfComplete($ekubId) : null;
            return ['result'=>['index'=>$winnerIndex,'finished'=>(bool)$newId,'recreated_id'=>$newId,'winner'=>trim($winner['first_name'].' '.$winner['last_name']),'period'=>$periodNo,'gross'=>$gross,'fee'=>$fee,'net'=>$net,'next_period'=>$next>$periodNo?$next:null]];
        });
        if (! isset($draw['error'])) {
            $this->notifyWinner($ekubId, $periodNo);
            if (! empty($draw['result']['next_period']) && empty($draw['result']['finished'])) {
                $nextPeriod = (int) $draw['result']['next_period'];
                $ekubName = (string) (DB::table('ekubs')->where('id', $ekubId)->value('name') ?? 'Your Ekub');
                $this->notifyEkubMembers($ekubId, 'period_started', 'A new Ekub period is open', "Period {$nextPeriod} for {$ekubName} is open. Check the app for your contribution due.", 'ekub.period:'.$ekubId.':'.$nextPeriod);
            }
            if (! empty($draw['result']['recreated_id'])) {
                $this->notifyEkubCreated((int)$draw['result']['recreated_id'], true);
            }
        }
        return $draw;
    }
    public function pickWinner(int $ekubId,int $periodNo,Request $request)
    {
        if($request->isMethod('post')){$draw=$this->performDraw($ekubId,$periodNo);if(isset($draw['error']))return response()->json(['ok'=>false,'error'=>$draw['error']],400);$this->flash('Winner selected.','success');return response()->json(['ok'=>true]+$draw['result']);}
        $state=$this->drawState($ekubId,$periodNo);if(!$state['ekub'])return $this->page('error',['code'=>404,'message'=>'Ekub not found.']);
        return $this->page('winner_spin',['ekub'=>$state['ekub'],'period_no'=>$periodNo,'members'=>$state['members'],'approved'=>$state['approved'],'error'=>$state['drawn']?'A winner has already been selected for this period.':$state['error'],'drawn'=>$state['drawn'],'winners'=>$this->ekubs->winners($ekubId)]);
    }
    public function recentWinners()
    {
        if(!$this->partnerAllowed('recent_winner'))return $this->page('error',['code'=>403,'message'=>'Recently Winner permission required.']);
        $rows=$this->rows(DB::table('payouts as p')->join('ekubs as e','e.id','=','p.ekub_id')->join('ekub_members as m','m.id','=','p.winner_member_id')->join('users as u','u.id','=','m.user_id')
            ->leftJoin('kyc_verifications as k','k.user_id','=','u.id')->leftJoin('payment_methods as pm',function($join){$join->on('pm.user_id','=','u.id')->where('pm.is_default',1);})
            ->whereNull('p.sent_at')->orderByDesc('p.created_at')->orderByDesc('p.id')->get(['p.id as payout_id','p.ekub_id','p.period_no','p.gross_amount','p.service_fee','p.net_amount','p.created_at','e.name as ekub_name','e.category','e.frequency','u.id as user_id','u.first_name','u.last_name','u.username','u.phone','u.email','u.kyc_status','k.full_name as kyc_name','k.dob','k.gender','k.id_type','k.id_number','pm.bank_name as pm_bank','pm.account_number as pm_number','pm.account_name as pm_name']));
        return $this->page('recent_winners',['rows'=>$rows]);
    }
    public function recentWinnerSend(int $payoutId)
    {
        if(!$this->partnerAllowed('recent_winner'))return $this->page('error',['code'=>403,'message'=>'Recently Winner permission required.']);
        $p=$this->row(DB::table('payouts')->where('id',$payoutId)->first());
        if(!$p)$this->flash('Winner record not found.','error');elseif($p['sent_at'])$this->flash('This winner was already marked as sent.','error');else{DB::table('payouts')->where('id',$payoutId)->update(['sent_at'=>now(),'sent_by'=>$this->currentUser()['username'],'status'=>'sent']);$this->flash('Prize payout marked as sent.','success');}
        return $this->go('recent_winners');
    }
    public function adminAds()
    {
        $ads=[];foreach(DB::table('ads')->get() as $row)$ads[(int)$row->slot]=(array)$row;
        return $this->page('admin_ads',['slots'=>range(1,10),'ads'=>$ads]);
    }
    public function adminAdSave(int $slot,Request $request)
    {
        if($slot<1||$slot>10)return $this->go('admin_ads');
        try{$file=$request->file('image');$image=$this->imageUpload($file,'ads','ad-'.$slot);if(!$image)throw new \RuntimeException('Choose an image first.');$old=DB::table('ads')->where('slot',$slot)->value('image');DB::table('ads')->updateOrInsert(['slot'=>$slot],['image'=>$image,'updated_at'=>now()]);if($old)@unlink(public_path('static/uploads/'.$old));$this->flash("Ad {$slot} published.",'success');}
        catch(Throwable $e){$this->flash($e->getMessage(),'error');}
        return $this->go('admin_ads');
    }
    public function adminAdDelete(int $slot)
    {
        $old=DB::table('ads')->where('slot',$slot)->value('image');DB::table('ads')->where('slot',$slot)->delete();if($old)@unlink(public_path('static/uploads/'.$old));$this->flash("Ad {$slot} removed.",'success');return $this->go('admin_ads');
    }
    public function finishedEkubs()
    {
        $user=$this->currentUser();$query=DB::table('ekubs')->where('status','finished');if(!in_array($user['role'],['admin','partner'],true))$query->whereIn('id',DB::table('ekub_members')->where('user_id',$user['id'])->pluck('ekub_id'));
        $data=$this->rows($query->orderByDesc('finished_at')->orderByDesc('id')->get());
        foreach($data as &$e){$e['member_count']=DB::table('ekub_members')->where('ekub_id',$e['id'])->count();$e['winners']=$this->ekubs->winners((int)$e['id']);$e['new_ekub_id']=DB::table('ekubs')->where('recreated_from',$e['id'])->value('id');}
        unset($e);return $this->page('finished_ekubs',['ekubs'=>$data]);
    }
    public function applyEkub(Request $request)
    {
        $user=$this->currentUser();
        if($request->isMethod('post')){$name=trim((string)$request->input('name'));$category=(string)$request->input('category');$frequency=(string)$request->input('frequency');$amount=(float)$request->input('base_amount');$duration=(int)$request->input('duration');$note=mb_substr(trim((string)$request->input('note')),0,500);
            if(!$name||mb_strlen($name)>80)$this->flash('Enter an Ekub name (up to 80 characters).','error');elseif(!in_array($category,config('ekub.categories'),true))$this->flash('Choose a valid category.','error');elseif(!in_array($frequency,config('ekub.frequencies'),true))$this->flash('Choose a valid payment frequency.','error');elseif($amount<=0)$this->flash('Contribution amount must be greater than zero.','error');elseif($duration<2||$duration>500)$this->flash('Duration must be between 2 and 500 periods.','error');elseif(DB::table('ekub_applications')->where('user_id',$user['id'])->where('status','pending')->whereRaw('LOWER(name)=?', [mb_strtolower($name)])->exists())$this->flash('You already have a pending application with this name.','error');else{DB::table('ekub_applications')->insert(['user_id'=>$user['id'],'name'=>$name,'category'=>$category,'frequency'=>$frequency,'base_amount'=>$amount,'duration'=>$duration,'note'=>$note?:null,'status'=>'pending','created_at'=>now()]);$this->flash('Your Ekub application was sent. The admin will review it.','success');return $this->go('apply_ekub');}}
        $mine=$this->rows(DB::table('ekub_applications')->where('user_id',$user['id'])->orderByDesc('id')->get());return $this->page('apply_ekub',['applications'=>$mine,'form'=>$request->all()]);
    }
    public function adminAppliedEkubs()
    {
        $rows=$this->rows(DB::table('ekub_applications as a')->join('users as u','u.id','=','a.user_id')->orderByRaw("CASE a.status WHEN 'pending' THEN 0 ELSE 1 END")->orderByDesc('a.id')->get(['a.*','u.first_name','u.last_name','u.username','u.phone']));return $this->page('admin_applied_ekubs',['applications'=>$rows]);
    }
    public function approveApplication(int $appId)
    {
        $application=$this->row(DB::table('ekub_applications')->where('id',$appId)->where('status','pending')->first());if(!$application){$this->flash('This application is no longer pending.','error');return $this->go('admin_applied_ekubs');}
        $id=$this->insertEkub($application['name'],$application['category'],$application['frequency'],(float)$application['base_amount'],(int)$application['duration'],$application['category']==="Item's Ekub");
        DB::table('ekub_applications')->where('id',$appId)->update(['status'=>'approved','created_ekub_id'=>$id,'reviewed_at'=>now(),'reviewed_by'=>$this->currentUser()['username']]);$this->notifyEkubCreated((int)$id);$this->flash('Application approved and the Ekub was created. Members were notified.','success');return $this->go('admin_applied_ekubs');
    }
    public function rejectApplication(int $appId,Request $request)
    {
        $application=$this->row(DB::table('ekub_applications')->where('id',$appId)->where('status','pending')->first());
        $reason=mb_substr(trim((string)$request->input('reason')),0,300);
        $count=DB::table('ekub_applications')->where('id',$appId)->where('status','pending')->update(['status'=>'rejected','rejection_reason'=>$reason?:null,'reviewed_at'=>now(),'reviewed_by'=>$this->currentUser()['username']]);
        if($count&&$application)$this->notifyMemberEvent((int)$application['user_id'],'application','Ekub application update',"Your application for {$application['name']} was not approved.".($reason?' Reason: '.$reason:''),'application.rejected:'.$appId);
        $this->flash($count?'Application rejected.':'This application is no longer pending.',$count?'success':'error');return $this->go('admin_applied_ekubs');
    }
    public function uploads(string $name)
    {
        $base=realpath(public_path('static/uploads'));$target=realpath(public_path('static/uploads/'.$name));
        if(!$base||!$target||!str_starts_with($target,$base.DIRECTORY_SEPARATOR)||!is_file($target))abort(404);
        return response()->file($target);
    }
}
