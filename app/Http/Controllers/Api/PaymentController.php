<?php

namespace App\Http\Controllers\Api;

use App\Support\EkubService;
use Illuminate\Database\QueryException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class PaymentController
{
    public function __construct(private EkubService $ekubs) {}

    public function methods()
    {
        $methods = collect(config('ekub.methods', []))->map(function (string $method): array {
            $isBinance = $method === 'Binance Pay';
            $account = trim((string) (config('ekub.payment_accounts')[$method] ?? ''));
            $rate = $isBinance ? (float) config('ekub.binance_etb_per_usdt', 0) : 1.0;

            return [
                'name' => $method,
                'account' => $account,
                'account_holder' => (string) config('ekub.payment_account_holder', ''),
                'currency' => $isBinance ? 'USDT' : 'ETB',
                'etb_per_usdt' => $isBinance ? $rate : null,
                'configured' => $account !== '' && (! $isBinance || $rate > 0),
            ];
        })->values();

        return response()->json(['methods' => $methods]);
    }

    public function checkTransaction(Request $request)
    {
        $data = $request->validate([
            'transaction_no' => ['required', 'string', 'max:191'],
        ]);
        $transaction = $this->normalizeTransaction((string) $data['transaction_no']);
        if ($transaction === '') {
            return response()->json(['message' => 'Enter the transaction ID from your receipt.'], 422);
        }

        $duplicate = $this->transactionExists($transaction);

        return response()->json([
            'available' => ! $duplicate,
            'duplicate' => $duplicate,
            'message' => $duplicate
                ? 'Duplicate Transaction ID Error: This transaction ID has already been submitted.'
                : 'This transaction ID is new and can be submitted for admin review.',
        ]);
    }

    public function submitManual(Request $request, int $ekubId, int $periodNo)
    {
        $user = $request->user();
        $ekub = DB::table('ekubs')->where('id', $ekubId)->first();
        $member = DB::table('ekub_members')->where('ekub_id', $ekubId)->where('user_id', $user->id)->first();

        if (! $ekub || ! $member) return response()->json(['message' => 'Membership not found.'], 404);
        if ($periodNo < 1 || $periodNo > (int) $ekub->duration) return response()->json(['message' => 'Invalid payment period.'], 422);
        if ($ekub->status !== 'started') return response()->json(['message' => 'This Ekub has not started yet.'], 422);
        if ($periodNo > 1 && ! DB::table('payouts')->where('ekub_id', $ekubId)->where('period_no', $periodNo - 1)->exists()) {
            return response()->json(['message' => 'The previous period winner must be drawn before this period can be paid.'], 422);
        }

        $balance = $this->ekubs->periodBalance((array) $ekub, (array) $member, $periodNo, (int) $user->id);
        if ((float) $balance['can_submit'] <= 0) {
            return response()->json([
                'message' => (float) $balance['left'] <= 0
                    ? 'Nothing is left to pay for this period.'
                    : 'An earlier payment is waiting for admin review. Pay the remaining amount after it is reviewed.',
            ], 422);
        }

        $allowedMethods = config('ekub.methods', []);
        $data = $request->validate([
            'amount' => ['required', 'numeric', 'min:0.01', 'max:'.(float) $balance['can_submit']],
            'method' => ['required', 'string', 'in:'.implode(',', $allowedMethods)],
            'transaction_no' => ['required', 'string', 'max:191'],
            'screenshot' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:8192'],
            'terms_accepted' => ['accepted'],
        ]);

        $method = (string) $data['method'];
        $account = trim((string) (config('ekub.payment_accounts')[$method] ?? ''));
        $isBinance = $method === 'Binance Pay';
        $exchangeRate = $isBinance ? (float) config('ekub.binance_etb_per_usdt', 0) : 1.0;
        if ($account === '' || ($isBinance && $exchangeRate <= 0)) {
            return response()->json(['message' => 'This payment method is not configured yet. Choose another method or contact an administrator.'], 422);
        }

        $transaction = $this->normalizeTransaction((string) $data['transaction_no']);
        if ($transaction === '') return response()->json(['message' => 'Enter the transaction ID from your receipt.'], 422);
        if ($this->transactionExists($transaction)) {
            return response()->json(['message' => 'Duplicate Transaction ID Error: This transaction ID has already been submitted.'], 422);
        }

        $amount = round((float) $data['amount'], 2);
        $currency = $isBinance ? 'USDT' : 'ETB';
        $currencyAmount = $isBinance ? round($amount / $exchangeRate, 8) : $amount;
        $receipt = $data['screenshot'];
        $directory = public_path('static/uploads');
        if (! is_dir($directory)) mkdir($directory, 0775, true);
        $filename = 'payment-'.Str::uuid().'.'.strtolower($receipt->getClientOriginalExtension());
        $receipt->move($directory, $filename);

        try {
            $paymentId = DB::table('payments')->insertGetId([
                'ekub_id' => $ekubId,
                'member_id' => $member->id,
                'user_id' => $user->id,
                'period_no' => $periodNo,
                'amount' => $amount,
                'penalty' => $balance['penalty'],
                'method' => $method,
                'transaction_no' => $transaction,
                'screenshot' => $filename,
                'status' => 'pending',
                'approved_amount' => 0,
                'verification_status' => 'not_checked',
                'payment_currency' => $currency,
                'payment_currency_amount' => $currencyAmount,
                'payment_exchange_rate' => $exchangeRate,
                'submitted_at' => now(),
            ]);
        } catch (QueryException $exception) {
            if ($this->transactionExists($transaction)) {
                @unlink($directory.DIRECTORY_SEPARATOR.$filename);

                return response()->json([
                    'message' => 'Duplicate Transaction ID Error: This transaction ID has already been submitted.',
                ], 422);
            }

            throw $exception;
        }

        return response()->json([
            'message' => 'Payment submitted for admin verification.',
            'payment' => [
                'id' => $paymentId,
                'amount' => $amount,
                'currency' => $currency,
                'currency_amount' => $currencyAmount,
                'method' => $method,
                'transaction_no' => $transaction,
                'status' => 'pending',
            ],
        ], 201);
    }

    private function normalizeTransaction(string $transaction): string
    {
        return mb_strtolower(preg_replace('/\s+/', '', trim($transaction)) ?? '');
    }

    private function transactionExists(string $normalized): bool
    {
        return DB::table('payments')
            ->whereRaw("LOWER(REPLACE(transaction_no, ' ', '')) = ?", [$normalized])
            ->exists();
    }
}
