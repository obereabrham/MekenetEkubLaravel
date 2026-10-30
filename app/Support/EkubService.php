<?php
namespace App\Support;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Carbon;

class EkubService
{
    public function usedCapacity(int $ekubId): float
    {
        return (float) DB::table('ekub_members')->where('ekub_id', $ekubId)->sum('share_fraction');
    }

    public function isFull(array|object $ekub): bool
    {
        $e = (array) $ekub;
        return (float) $e['duration'] - $this->usedCapacity((int) $e['id']) <= 0.000001;
    }

    public function images(array|object $ekub): array
    {
        $e = (array) $ekub;
        $images = DB::table('ekub_images')->where('ekub_id', $e['id'])->orderBy('position')->orderBy('id')->pluck('image')->all();
        if (! $images) $images = array_values(array_filter([$e['product1'] ?? null, $e['product2'] ?? null, $e['product3'] ?? null]));
        return array_values(array_filter($images, fn ($path) => in_array(strtolower(pathinfo($path, PATHINFO_EXTENSION)), ['png','jpg','jpeg','webp','gif'], true)));
    }

    public function winners(int $ekubId): array
    {
        return DB::table('payouts as p')->join('ekub_members as m', 'm.id', '=', 'p.winner_member_id')->join('users as u', 'u.id', '=', 'm.user_id')
            ->where('p.ekub_id', $ekubId)->orderBy('p.period_no')
            ->get(['p.*','u.first_name','u.last_name','u.username','u.phone','u.profile_picture'])->map(fn ($r) => (array) $r)->all();
    }

    public function periodBalance(array|object $ekub, array|object $member, int $period, ?int $userId = null): array
    {
        $e = (array) $ekub; $m = (array) $member; $uid = $userId ?: (int) $m['user_id'];
        $rows = DB::table('payments')->where('ekub_id', $e['id'])->where('user_id', $uid)->where('period_no', $period)->orderBy('id')->get()->map(fn ($r) => (array) $r)->all();
        $must = round((float) $m['contribution_amount'], 2);
        $paid = round(array_sum(array_map(fn ($r) => $r['status'] === 'approved' ? (float) ($r['approved_amount'] ?? 0) : 0, $rows)), 2);
        $pending = round(array_sum(array_map(fn ($r) => $r['status'] === 'pending' ? (float) $r['amount'] : 0, $rows)), 2);
        $left = round(max(0, $must - $paid), 2);
        $canSubmit = round(max(0, $left - $pending), 2);
        $due = $this->dueDate($e, $period);
        $daysLate = $due && $left > 0 ? max(0, (int) floor($due->diffInSeconds(now(), false) / 86400)) : 0;
        $penalty = round($left * 0.01 * $daysLate, 2);
        return ['must'=>$must,'paid'=>$paid,'pending'=>$pending,'left'=>$left,'can_submit'=>$canSubmit,'due'=>$due,'days_late'=>$daysLate,'penalty'=>$penalty,'fully_paid'=>$left <= 0,'payments'=>$rows];
    }

    public function payBalance(array $payment): array
    {
        $ekub = (array) DB::table('ekubs')->where('id', $payment['ekub_id'])->first();
        $member = (array) DB::table('ekub_members')->where('id', $payment['member_id'])->first();
        return $this->periodBalance($ekub, $member, (int) $payment['period_no'], (int) $payment['user_id']);
    }

    public function currentPeriodBalance(array $ekub, int $period): array
    {
        $uid = (int) session('user_id');
        $member = (array) DB::table('ekub_members')->where('ekub_id', $ekub['id'])->where('user_id', $uid)->first();
        return $this->periodBalance($ekub, $member, $period, $uid);
    }

    public function dueDate(array $ekub, int $period): ?Carbon
    {
        $start = DB::table('period_dues')->where('ekub_id', $ekub['id'])->where('period_no', $period)->value('started_at');
        if (! $start) return null;
        $days = match ($ekub['frequency']) { 'Daily'=>1, 'Weekly'=>7, 'Monthly'=>30, default=>0 };
        if (! $days) return null;
        return Carbon::parse($start)->addDays($days);
    }

    public function drawError(array|object $ekub, int $period): ?string
    {
        $e = (array) $ekub;
        if ($e['status'] !== 'started') return 'This Ekub has not started.';
        if ((int) $e['current_period'] !== $period) return 'This is not the current period.';
        if (DB::table('payouts')->where('ekub_id', $e['id'])->where('period_no', $period)->exists()) return "The winner for Period {$period} has already been selected.";
        $members = DB::table('ekub_members')->where('ekub_id', $e['id'])->get()->map(fn ($r)=>(array)$r)->all();
        if (! $members) return 'No members have joined this Ekub.';
        foreach ($members as $member) {
            $balance = $this->periodBalance($e, $member, $period);
            if (! $balance['fully_paid']) return 'All members must fully pay the current period before a winner can be selected.';
        }
        return null;
    }
}