<?php
namespace App\Http\Middleware;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
class AuthenticateSession
{
    public function handle(Request $request, Closure $next) {
        $userId = $request->session()->get('user_id');
        if (! $userId) return redirect('/login?next='.urlencode($request->getRequestUri()));
        $status = DB::table('users')->where('id', $userId)->value('status');
        if ($status !== 'active') {
            $request->session()->invalidate();
            $request->session()->regenerateToken();
            $request->session()->flash('_flashes', [['type'=>'error','message'=>'This account is suspended.']]);
            return redirect('/login');
        }
        return $next($request);
    }
}
