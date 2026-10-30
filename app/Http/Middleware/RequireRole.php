<?php
namespace App\Http\Middleware;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
class RequireRole
{
    public function handle(Request $request, Closure $next, string ...$roles) {
        $id = $request->session()->get('user_id');
        if (! $id) return redirect('/login');
        $user = DB::table('users')->where('id', $id)->first();
        if (! $user || $user->status !== 'active') { $request->session()->invalidate(); return redirect('/login'); }
        if (! in_array($user->role, $roles, true)) return response()->view('error', ['code'=>403,'message'=>'Access denied.'], 403);
        return $next($request);
    }
}