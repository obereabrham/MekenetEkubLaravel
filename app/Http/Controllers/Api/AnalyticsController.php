<?php

namespace App\Http\Controllers\Api;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class AnalyticsController
{
    public function visit(Request $request)
    {
        $data = $request->validate(['visitor_id' => ['required', 'string', 'min:20', 'max:128']]);
        $user = Auth::guard('sanctum')->user();
        $memberId = $user && $user->role === 'member' && $user->status === 'active'
            ? (int) $user->id
            : null;
        $visitorHash = hash_hmac('sha256', $data['visitor_id'], (string) config('app.key'));
        $visitDate = now()->toDateString();
        DB::table('site_visits')->insertOrIgnore([
            'source' => 'app',
            'visitor_hash' => $visitorHash,
            'member_user_id' => $memberId,
            'visit_date' => $visitDate,
            'created_at' => now(),
        ]);
        if ($memberId) {
            DB::table('site_visits')->where('source', 'app')->where('visitor_hash', $visitorHash)
                ->where('visit_date', $visitDate)->whereNull('member_user_id')
                ->update(['member_user_id' => $memberId]);
        }
        return response()->json(['ok' => true]);
    }
}
