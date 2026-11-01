<?php

namespace App\Http\Controllers\Api;

use App\Support\EkubService;
use App\Support\UploadStorage;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class MemberController
{
    public function __construct(private EkubService $ekubs) {}

    public function ads()
    {
        $data = DB::table('ads')
            ->orderBy('slot')
            ->get(['slot', 'image'])
            ->filter(fn ($row) => trim((string) $row->image) !== '')
            ->map(fn ($row) => [
                'slot' => (int) $row->slot,
                'image_url' => app(UploadStorage::class)->url((string) $row->image),
            ])
            ->values();

        return response()->json(['data' => $data]);
    }

    public function notifications(Request $request)
    {
        $userId = (int) $request->user()->id;
        $rows = DB::table('member_notifications')->where('user_id', $userId)
            ->orderByDesc('id')->limit(100)->get([
                'id', 'type', 'title', 'body', 'read_at', 'created_at',
            ])->map(function ($row) {
                // Repair approval notices created while the amount formatter was
                // accidentally stored as literal text in the notification body.
                $row->body = preg_replace_callback(
                    '/\{number_format\(([-\d.,]+),2\)\}/',
                    fn (array $match): string => number_format((float) str_replace(',', '', $match[1]), 2, '.', ','),
                    (string) $row->body,
                );

                return $row;
            });

        return response()->json([
            'data' => $rows,
            'unread_count' => DB::table('member_notifications')
                ->where('user_id', $userId)->whereNull('read_at')->count(),
        ]);
    }

    public function readNotifications(Request $request)
    {
        DB::table('member_notifications')->where('user_id', $request->user()->id)
            ->whereNull('read_at')->update(['read_at' => now()]);

        return response()->json(['message' => 'Notifications marked as read.']);
    }

    public function ekubs(Request $request)
    {
        $query = DB::table('ekubs')
            ->whereIn('status', ['open', 'started'])
            ->orderByDesc('id');

        if ($request->filled('category')) {
            $query->where('category', trim((string) $request->query('category')));
        }

        if ($request->filled('frequency')) {
            $query->where('frequency', trim((string) $request->query('frequency')));
        }

        if ($request->filled('search')) {
            $term = trim((string) $request->query('search'));
            $query->where('name', 'like', '%'.str_replace(['%', '_'], ['\\%', '\\_'], $term).'%');
        }

        $rows = $query->limit(100)->get();
        $userId = (int) $request->user()->id;
        $data = $rows->map(fn ($row) => $this->ekubPayload((array) $row, $userId))->values();

        return response()->json([
            'data' => $data,
            'categories' => config('ekub.categories'),
            'frequencies' => config('ekub.frequencies'),
        ]);
    }

    public function ekubDetail(Request $request, int $ekubId)
    {
        $row = DB::table('ekubs')->where('id', $ekubId)->first();

        if (! $row) {
            return response()->json(['message' => 'Ekub not found.'], 404);
        }

        $userId = (int) $request->user()->id;
        $membership = DB::table('ekub_members')
            ->where('ekub_id', $ekubId)
            ->where('user_id', $userId)
            ->first();
        $payload = $this->ekubPayload((array) $row, $userId);

        $winners = $membership
            ? DB::table('payouts as p')
                ->join('ekub_members as m', 'm.id', '=', 'p.winner_member_id')
                ->join('users as u', 'u.id', '=', 'm.user_id')
                ->where('p.ekub_id', $ekubId)
                ->orderBy('p.period_no')
                ->get(['p.period_no', 'p.net_amount', 'p.status', 'p.sent_at', 'u.username'])
                ->map(fn ($winner) => (array) $winner)
                ->values()
            : collect();

        $myPaymentPeriods = collect();
        if ($membership) {
            $paymentsByPeriod = DB::table('payments')
                ->where('ekub_id', $ekubId)
                ->where('user_id', $userId)
                ->orderBy('id')
                ->get()
                ->groupBy('period_no');

            for ($periodNo = 1; $periodNo <= (int) $row->duration; $periodNo++) {
                $periodPayments = $paymentsByPeriod->get($periodNo, collect());
                $due = round((float) $membership->contribution_amount, 2);
                $paid = round((float) $periodPayments
                    ->where('status', 'approved')
                    ->sum(fn ($payment) => (float) ($payment->approved_amount ?? 0)), 2);
                $pending = round((float) $periodPayments
                    ->where('status', 'pending')
                    ->sum(fn ($payment) => (float) $payment->amount), 2);
                $remaining = round(max(0, $due - $paid), 2);
                $myPaymentPeriods->push([
                    'period_no' => $periodNo,
                    'due' => $due,
                    'paid' => $paid,
                    'pending' => $pending,
                    'remaining' => $remaining,
                    'fully_paid' => $remaining <= 0,
                    'payments' => $periodPayments->map(fn ($payment) => [
                        'id' => (int) $payment->id,
                        'amount' => (float) $payment->amount,
                        'approved_amount' => (float) ($payment->approved_amount ?? 0),
                        'penalty' => (float) ($payment->penalty ?? 0),
                        'method' => $payment->method,
                        'transaction_no' => $payment->transaction_no,
                        'status' => $payment->status,
                        'rejection_reason' => $payment->rejection_reason,
                        'payment_currency' => $payment->payment_currency ?? 'ETB',
                        'payment_currency_amount' => $payment->payment_currency_amount,
                        'payment_exchange_rate' => $payment->payment_exchange_rate,
                        'submitted_at' => $payment->submitted_at,
                        'reviewed_at' => $payment->reviewed_at,
                        'approved_by' => $payment->approved_by,
                        'screenshot_url' => app(UploadStorage::class)->url((string) $payment->screenshot),
                    ])->values(),
                ]);
            }
        }

        return response()->json([
            'ekub' => $payload,
            'membership' => $membership ? [
                'id' => (int) $membership->id,
                'share_type' => $membership->share_type,
                'share_fraction' => (float) $membership->share_fraction,
                'contribution_amount' => (float) $membership->contribution_amount,
                'status' => $membership->status,
            ] : null,
            'members' => DB::table('ekub_members as m')
                ->join('users as u', 'u.id', '=', 'm.user_id')
                ->where('m.ekub_id', $ekubId)
                ->orderBy('m.id')
                ->get(['u.first_name', 'u.last_name', 'u.username', 'm.share_type', 'm.contribution_amount'])
                ->map(fn ($member) => (array) $member)
                ->values(),
            'winners' => $winners,
            'my_payment_periods' => $myPaymentPeriods,
            'potential_net_payout' => round((float) $row->base_amount * (float) $row->duration * 0.98, 2),
        ]);
    }

    public function joinEkub(Request $request, int $ekubId)
    {
        $data = $request->validate([
            'share_type' => ['required', 'in:full,half,quarter'],
        ]);
        $user = $request->user();

        if ($user->kyc_status !== 'approved') {
            return response()->json([
                'message' => 'Complete identity verification and wait for approval before joining an Ekub.',
                'kyc_status' => $user->kyc_status,
            ], 403);
        }

        $shareType = $data['share_type'];

        try {
            $membershipId = DB::transaction(function () use ($ekubId, $user, $shareType): int {
                $ekub = DB::table('ekubs')->where('id', $ekubId)->lockForUpdate()->first();

                if (! $ekub) {
                    abort(404, 'Ekub not found.');
                }

                if ($ekub->status !== 'open') {
                    abort(422, 'This Ekub is not accepting members.');
                }

                if (DB::table('ekub_members')->where('ekub_id', $ekubId)->where('user_id', $user->id)->exists()) {
                    abort(422, 'You already joined this Ekub.');
                }

                $fraction = match ($shareType) {
                    'full' => 1.0,
                    'half' => 0.5,
                    'quarter' => 0.25,
                };

                if ((bool) $ekub->is_item && $shareType !== 'full') {
                    abort(422, 'Item Ekubs only allow a full share.');
                }

                $used = (float) DB::table('ekub_members')->where('ekub_id', $ekubId)->sum('share_fraction');

                if ($used + $fraction > (float) $ekub->duration + 0.000001) {
                    abort(422, 'This Ekub is full or does not have enough capacity for that share.');
                }

                return DB::table('ekub_members')->insertGetId([
                    'ekub_id' => $ekubId,
                    'user_id' => $user->id,
                    'share_type' => $shareType,
                    'share_fraction' => $fraction,
                    'contribution_amount' => round((float) $ekub->base_amount * $fraction, 2),
                    'status' => 'joined',
                    'joined_at' => now(),
                ]);
            });
        } catch (\Illuminate\Http\Exceptions\HttpResponseException $exception) {
            throw $exception;
        }

        $membership = DB::table('ekub_members')->where('id', $membershipId)->first();

        return response()->json([
            'message' => 'You joined the Ekub.',
            'membership' => [
                'id' => (int) $membership->id,
                'ekub_id' => (int) $membership->ekub_id,
                'share_type' => $membership->share_type,
                'share_fraction' => (float) $membership->share_fraction,
                'contribution_amount' => (float) $membership->contribution_amount,
                'status' => $membership->status,
            ],
        ], 201);
    }

    public function leaveEkub(Request $request, int $ekubId)
    {
        $membership = DB::table('ekub_members as m')
            ->join('ekubs as e', 'e.id', '=', 'm.ekub_id')
            ->where('m.ekub_id', $ekubId)
            ->where('m.user_id', $request->user()->id)
            ->first(['m.id', 'e.status']);

        if (! $membership) {
            return response()->json(['message' => 'Membership not found.'], 404);
        }

        if (! in_array($membership->status, ['pending', 'open'], true)) {
            return response()->json(['message' => 'You cannot leave after this Ekub has started.'], 422);
        }

        DB::table('ekub_members')->where('id', $membership->id)->delete();

        return response()->json(['message' => 'You left the Ekub.']);
    }

    public function myEkubs(Request $request)
    {
        $userId = (int) $request->user()->id;
        $rows = DB::table('ekub_members as m')
            ->join('ekubs as e', 'e.id', '=', 'm.ekub_id')
            ->where('m.user_id', $userId)
            ->where('e.status', '!=', 'finished')
            ->orderByDesc('m.id')
            ->get([
                'e.*',
                'm.id as member_id',
                'm.share_type',
                'm.share_fraction',
                'm.contribution_amount',
                'm.status as member_status',
            ]);

        return response()->json([
            'data' => $rows->map(function ($row) use ($userId): array {
                $ekub = (array) $row;
                $payload = $this->ekubPayload($ekub, $userId);
                $payload['membership'] = [
                    'id' => (int) $row->member_id,
                    'share_type' => $row->share_type,
                    'share_fraction' => (float) $row->share_fraction,
                    'contribution_amount' => (float) $row->contribution_amount,
                    'status' => $row->member_status,
                ];

                return $payload;
            })->values(),
        ]);
    }

    public function status(Request $request)
    {
        $userId = (int) $request->user()->id;
        $memberships = DB::table('ekub_members as m')
            ->join('ekubs as e', 'e.id', '=', 'm.ekub_id')
            ->where('m.user_id', $userId)
            ->where('e.status', '!=', 'finished')
            ->orderByDesc('m.id')
            ->get(['e.*', 'm.id as member_id', 'm.share_type', 'm.share_fraction', 'm.contribution_amount']);

        $data = $memberships->map(function ($row) use ($userId): array {
            $ekub = (array) $row;
            $member = [
                'id' => (int) $row->member_id,
                'ekub_id' => (int) $row->id,
                'share_type' => $row->share_type,
                'share_fraction' => (float) $row->share_fraction,
                'contribution_amount' => (float) $row->contribution_amount,
            ];
            $periods = [];

            for ($periodNo = 1; $periodNo <= (int) $row->duration; $periodNo++) {
                $balance = $this->ekubs->periodBalance($ekub, $member + ['user_id' => $userId], $periodNo, $userId);
                $payments = collect($balance['payments'])->map(fn ($payment) => [
                    'id' => (int) $payment['id'],
                    'amount' => (float) $payment['amount'],
                    'approved_amount' => (float) ($payment['approved_amount'] ?? 0),
                    'method' => $payment['method'],
                    'transaction_no' => $payment['transaction_no'],
                    'payment_currency' => $payment['payment_currency'] ?? 'ETB',
                    'payment_currency_amount' => isset($payment['payment_currency_amount']) ? (float) $payment['payment_currency_amount'] : null,
                    'payment_exchange_rate' => isset($payment['payment_exchange_rate']) ? (float) $payment['payment_exchange_rate'] : null,
                    'status' => $payment['status'],
                    'verification_status' => $payment['verification_status'] ?? 'not_checked',
                    'verification_message' => $payment['verification_message'] ?? null,
                    'submitted_at' => $payment['submitted_at'],
                    'reviewed_at' => $payment['reviewed_at'] ?? null,
                ])->values();
                $winner = DB::table('payouts as p')
                    ->join('ekub_members as m', 'm.id', '=', 'p.winner_member_id')
                    ->join('users as u', 'u.id', '=', 'm.user_id')
                    ->where('p.ekub_id', $row->id)
                    ->where('p.period_no', $periodNo)
                    ->first([
                        'p.id as payout_id',
                        'p.winner_member_id',
                        'p.net_amount',
                        'p.status',
                        'p.sent_at',
                        'u.username',
                    ]);

                $periods[] = [
                    'period_no' => $periodNo,
                    'required' => (float) $balance['must'],
                    'paid' => (float) $balance['paid'],
                    'pending' => (float) $balance['pending'],
                    'remaining' => (float) $balance['left'],
                    'available_to_pay' => (float) $balance['can_submit'],
                    'penalty' => (float) $balance['penalty'],
                    'due_at' => $balance['due']?->toIso8601String(),
                    'days_late' => (int) $balance['days_late'],
                    'is_paid' => (bool) $balance['fully_paid'],
                    'is_current' => (int) $row->current_period === $periodNo,
                    'can_pay' => $row->status === 'started'
                        && (int) $row->current_period === $periodNo
                        && (float) $balance['can_submit'] > 0,
                    'payments' => $payments,
                    'winner' => $winner ? [
                        'payout_id' => (int) $winner->payout_id,
                        'winner_member_id' => (int) $winner->winner_member_id,
                        'username' => $winner->username,
                        'net_amount' => (float) $winner->net_amount,
                        'status' => $winner->status,
                        'sent_at' => $winner->sent_at,
                    ] : null,
                ];
            }

            return [
                'ekub' => $this->ekubPayload($ekub, $userId),
                'membership' => $member,
                'periods' => $periods,
            ];
        })->values();

        return response()->json(['data' => $data]);
    }

    private function ekubPayload(array $ekub, int $userId): array
    {
        $used = $this->ekubs->usedCapacity((int) $ekub['id']);
        $memberCount = DB::table('ekub_members')->where('ekub_id', $ekub['id'])->count();
        $joined = DB::table('ekub_members')
            ->where('ekub_id', $ekub['id'])
            ->where('user_id', $userId)
            ->exists();
        $images = $this->ekubs->images($ekub);

        return [
            'id' => (int) $ekub['id'],
            'name' => $ekub['name'],
            'created_at' => $ekub['created_at'] ?? null,
            'category' => $ekub['category'],
            'frequency' => $ekub['frequency'],
            'base_amount' => (float) $ekub['base_amount'],
            'duration' => (int) $ekub['duration'],
            'status' => $ekub['status'],
            'is_item' => (bool) $ekub['is_item'],
            'current_period' => (int) $ekub['current_period'],
            'member_count' => (int) $memberCount,
            'used_capacity' => round((float) $used, 2),
            'capacity' => (int) $ekub['duration'],
            'slots_remaining' => round(max(0, (float) $ekub['duration'] - $used), 2),
            'is_full' => (float) $ekub['duration'] - $used <= 0.000001,
            'joined' => $joined,
            'images' => array_map(fn ($path) => app(UploadStorage::class)->url((string) $path), $images),
            'starts_at' => $ekub['start_at'] ?? null,
        ];
    }
}

