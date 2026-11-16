<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

class TrackSiteVisit
{
    public function handle(Request $request, Closure $next): Response
    {
        $memberId = $request->session()->get('role') === 'member'
            ? $request->session()->get('user_id')
            : null;
        $response = $next($request);
        if ($request->isMethod('GET') && $response->getStatusCode() < 400) {
            $visitor = (string) $request->cookie('mekenet_visitor', '');
            $newCookie = $visitor === '';
            if ($newCookie) $visitor = (string) Str::uuid();
            $visitorHash = hash_hmac('sha256', $visitor, (string) config('app.key'));
            $visitDate = now()->toDateString();
            DB::table('site_visits')->insertOrIgnore([
                'source' => 'website',
                'visitor_hash' => $visitorHash,
                'member_user_id' => $memberId,
                'visit_date' => $visitDate,
                'created_at' => now(),
            ]);
            if ($memberId) {
                DB::table('site_visits')->where('source', 'website')->where('visitor_hash', $visitorHash)
                    ->where('visit_date', $visitDate)->whereNull('member_user_id')
                    ->update(['member_user_id' => $memberId]);
            }
            if ($newCookie) $response->headers->setCookie(cookie('mekenet_visitor', $visitor, 60 * 24 * 365, '/', null, $request->isSecure(), true, false, 'Lax'));
        }
        return $response;
    }
}
