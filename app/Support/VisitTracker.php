<?php

namespace App\Support;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class VisitTracker
{
    public function record(Request $request, string $platform, ?int $userId = null): void
    {
        $platform = $platform === 'app' ? 'app' : 'website';
        $anonymousId = trim((string) $request->header('X-Visitor-Id', ''));
        $visitor = $userId !== null
            ? 'member:'.$userId
            : 'guest:'.($anonymousId !== '' && strlen($anonymousId) <= 128
                ? $anonymousId
                : ($request->hasSession() ? $request->session()->getId() : '')
                    .'|'.(string) $request->ip().'|'.(string) $request->userAgent());
        $now = now();

        DB::table('site_visits')->updateOrInsert(
            [
                'platform' => $platform,
                'visit_date' => $now->toDateString(),
                'visitor_hash' => hash('sha256', $platform.'|'.$visitor),
            ],
            [
                'user_id' => $userId,
                'last_seen_at' => $now,
                'updated_at' => $now,
                'created_at' => $now,
            ],
        );
    }

    public function summary(): array
    {
        $now = now();
        $today = $now->copy()->startOfDay();
        $periods = [
            'day' => $today,
            'week' => $today->copy()->startOfWeek(),
            'month' => $today->copy()->startOfMonth(),
            'year' => $today->copy()->startOfYear(),
        ];
        $summary = [];

        foreach ($periods as $key => $start) {
            $summary[$key]['new_members'] = DB::table('users')
                ->where('role', 'member')
                ->whereBetween('created_at', [$start, $now])
                ->count();

            foreach (['website', 'app'] as $platform) {
                $query = DB::table('site_visits')
                    ->where('platform', $platform)
                    ->whereBetween('visit_date', [$start->toDateString(), $today->toDateString()]);
                $summary[$key][$platform] = [
                    'total' => (clone $query)->distinct()->count('visitor_hash'),
                    'members' => (clone $query)->whereNotNull('user_id')->distinct()->count('user_id'),
                    'guests' => (clone $query)->whereNull('user_id')->distinct()->count('visitor_hash'),
                ];
            }
        }

        return $summary;
    }
}
