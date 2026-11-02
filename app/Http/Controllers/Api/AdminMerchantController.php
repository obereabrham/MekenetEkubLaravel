<?php

namespace App\Http\Controllers\Api;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AdminMerchantController
{
    public function index()
    {
        $merchants = DB::table('merchants as m')
            ->join('users as u', 'u.id', '=', 'm.user_id')
            ->orderByRaw("CASE m.status WHEN 'pending' THEN 0 WHEN 'rejected' THEN 1 ELSE 2 END")
            ->orderByDesc('m.id')
            ->get([
                'm.id', 'm.user_id', 'm.business_name', 'm.tin', 'm.category', 'm.business_phone',
                'm.address', 'm.website', 'm.location', 'm.status', 'm.rejection_reason',
                'm.reviewed_by', 'm.reviewed_at', 'm.created_at',
                'u.first_name', 'u.last_name', 'u.username', 'u.phone', 'u.email',
            ])
            ->map(fn ($row): array => (array) $row)
            ->values();

        $commissions = DB::table('merchant_commissions as c')
            ->join('merchants as m', 'm.id', '=', 'c.merchant_id')
            ->join('ekubs as e', 'e.id', '=', 'c.ekub_id')
            ->where('c.status', 'pending')
            ->orderBy('c.id')
            ->get([
                'c.id', 'c.merchant_id', 'c.ekub_id', 'c.payout_id', 'c.amount',
                'c.admin_amount', 'c.status', 'c.created_at', 'm.business_name', 'e.name as ekub_name',
            ])
            ->map(fn ($row): array => (array) $row)
            ->values();

        return response()->json([
            'merchants' => $merchants,
            'pending_count' => $merchants->where('status', 'pending')->count(),
            'commissions' => $commissions,
        ]);
    }

    public function review(Request $request, int $merchantId, string $action)
    {
        if (! in_array($action, ['approve', 'reject'], true)) {
            abort(404);
        }

        $data = $request->validate([
            'reason' => [$action === 'reject' ? 'required' : 'nullable', 'string', 'max:500'],
        ]);

        $updated = DB::table('merchants')->where('id', $merchantId)->where('status', 'pending')->update([
            'status' => $action === 'approve' ? 'approved' : 'rejected',
            'rejection_reason' => $action === 'reject' ? trim($data['reason']) : null,
            'reviewed_by' => (string) $request->user()->username,
            'reviewed_at' => now(),
        ]);

        if (! $updated) {
            return response()->json(['message' => 'Pending merchant application not found.'], 404);
        }

        return response()->json(['message' => $action === 'approve' ? 'Merchant approved.' : 'Merchant application rejected.']);
    }

    public function markCommissionPaid(Request $request, int $commissionId)
    {
        $updated = DB::table('merchant_commissions')->where('id', $commissionId)->where('status', 'pending')->update([
            'status' => 'paid',
            'paid_at' => now(),
            'paid_by' => (string) $request->user()->username,
        ]);

        if (! $updated) {
            return response()->json(['message' => 'Pending commission not found.'], 404);
        }

        return response()->json(['message' => 'Commission marked as paid.']);
    }
}
