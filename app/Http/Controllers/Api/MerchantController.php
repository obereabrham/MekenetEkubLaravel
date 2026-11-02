<?php

namespace App\Http\Controllers\Api;

use App\Support\UploadStorage;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class MerchantController
{
    private const CATEGORIES = ['Hotel', 'Shop', 'Mini market', 'Super Market', 'Grocery', 'School', 'Import and Export', 'Drivers', 'Private Works'];

    public function dashboard(Request $request)
    {
        $userId = (int) $request->user()->id;
        $merchant = DB::table('merchants')->where('user_id', $userId)->first();
        $options = ['business_categories' => self::CATEGORIES, 'ekub_categories' => config('ekub.categories'), 'frequencies' => config('ekub.frequencies')];
        if (! $merchant) return response()->json(['status' => 'not_applied'] + $options);
        $payload = (array) $merchant;
        if ($merchant->status !== 'approved') return response()->json(['status' => $merchant->status, 'application' => $payload] + $options);

        $ekubs = DB::table('ekubs')->where('merchant_id', $merchant->id)->orderByDesc('id')->get()->map(function ($ekub) use ($merchant): array {
            $item = (array) $ekub;
            $item['base_amount'] = (float) $ekub->base_amount;
            $item['member_count'] = (int) DB::table('ekub_members')->where('ekub_id', $ekub->id)->count();
            $item['members'] = DB::table('ekub_members as m')->join('users as u', 'u.id', '=', 'm.user_id')
                ->where('m.ekub_id', $ekub->id)->orderBy('m.id')
                ->get(['u.first_name', 'u.last_name', 'u.username', 'u.phone', 'u.email', 'u.kyc_status', 'm.share_type', 'm.contribution_amount'])
                ->map(fn ($row) => (array) $row)->values();
            $item['join_requests'] = DB::table('merchant_join_requests as r')
                ->join('users as u', 'u.id', '=', 'r.user_id')
                ->where('r.ekub_id', $ekub->id)->where('r.status', 'pending')
                ->orderBy('r.id')->get(['r.id', 'r.share_type', 'r.created_at', 'u.id as user_id', 'u.first_name', 'u.last_name', 'u.username', 'u.phone', 'u.email', 'u.kyc_status'])
                ->map(fn ($row) => (array) $row)->values();
            $item['ad'] = $this->adPayload((int) $ekub->id);
            return $item;
        })->values();
        $commissions = DB::table('merchant_commissions')->where('merchant_id', $merchant->id)->orderByDesc('id')->get();
        return response()->json([
            'status' => 'approved', 'application' => $payload, 'ekubs' => $ekubs,
            'business_categories' => self::CATEGORIES, 'ekub_categories' => config('ekub.categories'), 'frequencies' => config('ekub.frequencies'),
            'commission_total' => (float) $commissions->sum('amount'),
            'commission_pending' => (float) $commissions->where('status', 'pending')->sum('amount'),
            'commissions' => $commissions,
        ]);
    }

    public function apply(Request $request)
    {
        $data = $request->validate([
            'business_name' => ['required', 'string', 'max:120'],
            'tin' => ['required', 'string', 'max:40'],
            'category' => ['required', 'in:'.implode(',', self::CATEGORIES)],
            'business_phone' => ['required', 'string', 'max:32'],
            'address' => ['required', 'string', 'max:255'],
            'website' => ['nullable', 'url', 'max:255'],
            'location' => ['nullable', 'string', 'max:255'],
        ]);
        $userId = (int) $request->user()->id;
        $existing = DB::table('merchants')->where('user_id', $userId)->first();
        if ($existing && $existing->status === 'approved') return response()->json(['message' => 'Your merchant account is already approved.'], 422);
        if (DB::table('merchants')->where('tin', trim($data['tin']))->where('user_id', '!=', $userId)->exists()) {
            throw ValidationException::withMessages(['tin' => ['That TIN is already attached to another merchant application.']]);
        }
        DB::table('merchants')->updateOrInsert(['user_id' => $userId], [
            'business_name' => trim($data['business_name']), 'tin' => trim($data['tin']),
            'category' => $data['category'], 'business_phone' => trim($data['business_phone']),
            'address' => trim($data['address']), 'website' => trim((string) ($data['website'] ?? '')) ?: null,
            'location' => trim((string) ($data['location'] ?? '')) ?: null,
            'status' => 'pending', 'rejection_reason' => null, 'reviewed_by' => null, 'reviewed_at' => null,
            'created_at' => now(),
        ]);
        return response()->json(['message' => 'Merchant application sent for admin review.', 'status' => 'pending'], 201);
    }

    public function createEkub(Request $request)
    {
        $merchant = $this->approvedMerchant((int) $request->user()->id);
        $data = $request->validate([
            'name' => ['required', 'string', 'max:80'],
            'category' => ['required', 'in:'.implode(',', config('ekub.categories'))],
            'frequency' => ['required', 'in:'.implode(',', config('ekub.frequencies'))],
            'base_amount' => ['required', 'numeric', 'gt:0'],
            'duration' => ['required', 'integer', 'between:2,500'],
        ]);
        $code = Str::upper(Str::random(8));
        while (DB::table('ekubs')->where('invite_code', $code)->exists()) $code = Str::upper(Str::random(8));
        $id = DB::table('ekubs')->insertGetId([
            'name' => trim($data['name']), 'category' => $data['category'], 'frequency' => $data['frequency'],
            'base_amount' => $data['base_amount'], 'duration' => $data['duration'], 'status' => 'open',
            'is_item' => $data['category'] === "Item's Ekub", 'merchant_id' => $merchant->id,
            'invite_code' => $code, 'created_at' => now(),
        ]);
        return response()->json(['message' => 'Merchant Ekub created. Share its invite code with people you choose.', 'id' => (int) $id, 'invite_code' => $code], 201);
    }

    public function decideJoin(Request $request, int $requestId, string $action)
    {
        if (! in_array($action, ['approve', 'reject'], true)) return response()->json(['message' => 'Invalid action.'], 404);
        $merchant = $this->approvedMerchant((int) $request->user()->id);
        $joinRequest = DB::table('merchant_join_requests')->where('id', $requestId)->where('merchant_id', $merchant->id)->where('status', 'pending')->first();
        if (! $joinRequest) return response()->json(['message' => 'Pending join request not found.'], 404);
        if ($action === 'reject') {
            DB::table('merchant_join_requests')->where('id', $requestId)->update(['status' => 'rejected', 'reviewed_at' => now()]);
            return response()->json(['message' => 'Join request rejected.']);
        }
        DB::transaction(function () use ($joinRequest, $requestId): void {
            $ekub = DB::table('ekubs')->where('id', $joinRequest->ekub_id)->lockForUpdate()->first();
            $user = DB::table('users')->where('id', $joinRequest->user_id)->first();
            if (! $ekub || $ekub->status !== 'open') abort(422, 'This Ekub is no longer accepting members.');
            if (! $user || $user->kyc_status !== 'approved') abort(422, 'This member must have approved identity verification.');
            if (DB::table('ekub_members')->where('ekub_id', $ekub->id)->where('user_id', $user->id)->exists()) abort(422, 'This user already joined the Ekub.');
            $fraction = match ($joinRequest->share_type) { 'full' => 1.0, 'half' => 0.5, 'quarter' => 0.25, default => 0.0 };
            $used = (float) DB::table('ekub_members')->where('ekub_id', $ekub->id)->sum('share_fraction');
            if ($fraction <= 0 || $used + $fraction > (float) $ekub->duration + 0.000001) abort(422, 'There is not enough capacity for that share.');
            DB::table('ekub_members')->insert(['ekub_id' => $ekub->id, 'user_id' => $user->id, 'share_type' => $joinRequest->share_type, 'share_fraction' => $fraction, 'contribution_amount' => round((float) $ekub->base_amount * $fraction, 2), 'status' => 'joined', 'joined_at' => now()]);
            DB::table('merchant_join_requests')->where('id', $requestId)->update(['status' => 'approved', 'reviewed_at' => now()]);
        });
        return response()->json(['message' => 'Member approved and added to the Ekub.']);
    }

    public function saveAd(Request $request, int $ekubId)
    {
        $merchant = $this->approvedMerchant((int) $request->user()->id);
        $ekub = DB::table('ekubs')->where('id', $ekubId)->where('merchant_id', $merchant->id)->first();
        if (! $ekub) return response()->json(['message' => 'Merchant Ekub not found.'], 404);
        $data = $request->validate([
            'title' => ['required', 'string', 'max:120'], 'body' => ['nullable', 'string', 'max:2000'],
            'website_url' => ['nullable', 'url', 'max:255'], 'location' => ['nullable', 'string', 'max:255'],
            'image_1' => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:1024'],
            'image_2' => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:1024'],
            'image_3' => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:1024'],
        ]);
        $old = DB::table('merchant_ekub_ads')->where('ekub_id', $ekubId)->first();
        $images = $old ? (json_decode((string) $old->images, true) ?: []) : [];
        $newImages = [];
        try {
            foreach (['image_1', 'image_2', 'image_3'] as $field) {
                if (! $request->hasFile($field)) continue;
                $file = $request->file($field);
                $path = app(UploadStorage::class)->put($file, 'merchant_ads/'.Str::uuid().'.'.$file->getClientOriginalExtension());
                $newImages[] = $path;
            }
            if ($newImages) $images = $newImages;
            DB::table('merchant_ekub_ads')->updateOrInsert(['ekub_id' => $ekubId], [
                'title' => trim($data['title']), 'body' => trim((string) ($data['body'] ?? '')) ?: null,
                'website_url' => trim((string) ($data['website_url'] ?? '')) ?: null,
                'location' => trim((string) ($data['location'] ?? '')) ?: null,
                'images' => json_encode(array_slice($images, 0, 3), JSON_THROW_ON_ERROR), 'updated_at' => now(),
            ]);
        } catch (\Throwable $exception) {
            foreach ($newImages as $path) app(UploadStorage::class)->delete($path);
            throw $exception;
        }
        if ($newImages && $old) foreach ((json_decode((string) $old->images, true) ?: []) as $path) app(UploadStorage::class)->delete($path);
        return response()->json(['message' => 'Ekub ad saved.', 'ad' => $this->adPayload($ekubId)]);
    }

    private function approvedMerchant(int $userId): object
    {
        $merchant = DB::table('merchants')->where('user_id', $userId)->where('status', 'approved')->first();
        if (! $merchant) abort(403, 'An approved merchant account is required.');
        return $merchant;
    }

    private function adPayload(int $ekubId): ?array
    {
        $ad = DB::table('merchant_ekub_ads')->where('ekub_id', $ekubId)->first();
        if (! $ad) return null;
        $data = (array) $ad;
        $data['images'] = array_map(fn ($path) => app(UploadStorage::class)->url((string) $path), json_decode((string) $ad->images, true) ?: []);
        return $data;
    }
}
