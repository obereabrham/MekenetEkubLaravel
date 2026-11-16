<?php

namespace App\Http\Controllers\Api;

use App\Support\UploadStorage;
use App\Support\LocationGeocoder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class MerchantController
{
    private const BUSINESS_CATEGORIES = ['Hotel', 'Shop', 'Mini market', 'Super Market', 'Grocery', 'School', 'Import and Export', 'Drivers', 'Private Works'];

    private function merchant(int $userId): ?object
    {
        return DB::table('merchants')->where('user_id', $userId)->first();
    }

    private function code(): string
    {
        do { $code = strtoupper(Str::random(8)); }
        while (DB::table('ekubs')->where('join_code', $code)->exists());
        return $code;
    }

    public function show(Request $request)
    {
        $user = $request->user();
        if ($user->role !== 'member') return response()->json(['message' => 'Merchant access is for member accounts.'], 403);
        $merchant = $this->merchant((int) $user->id);
        $ekubs = collect();
        $commissions = collect();
        if ($merchant && $merchant->status === 'approved') {
            $ekubs = DB::table('ekubs')->where('merchant_id', $merchant->id)->orderByDesc('id')->get()->map(function ($ekub): array {
                $members = DB::table('ekub_members as m')->join('users as u','u.id','=','m.user_id')->where('m.ekub_id',$ekub->id)->orderBy('m.id')->get(['u.first_name','u.last_name','u.username','u.phone','u.profile_picture','m.contribution_amount','m.share_type','m.joined_at'])->map(function ($row): array {
                    $member = (array) $row;
                    $member['profile_picture_url'] = filled($member['profile_picture'])
                        ? app(UploadStorage::class)->url((string) $member['profile_picture'])
                        : null;
                    unset($member['profile_picture']);

                    return $member;
                })->values();
                $requests = DB::table('merchant_join_requests as r')->join('users as u','u.id','=','r.user_id')->where('r.ekub_id',$ekub->id)->where('r.status','pending')->orderBy('r.id')->get(['r.id','r.share_type','r.created_at','u.first_name','u.last_name','u.username','u.phone'])->map(fn ($row) => (array)$row)->values();
                $ad = DB::table('merchant_ekub_ads')->where('ekub_id',$ekub->id)->first();
                $adData = $ad ? (array)$ad : null;
                if ($adData) {
                    $adData['images'] = collect(json_decode($adData['images'] ?? '[]',true) ?: [])->map(fn ($path) => app(UploadStorage::class)->url($path))->all();
                    $adData['map_url'] = $adData['latitude'] !== null && $adData['longitude'] !== null ? 'https://www.google.com/maps/search/?api=1&query='.$adData['latitude'].','.$adData['longitude'] : null;
                }
                return ['id'=>(int)$ekub->id,'name'=>$ekub->name,'category'=>$ekub->category,'frequency'=>$ekub->frequency,'base_amount'=>(float)$ekub->base_amount,'duration'=>(int)$ekub->duration,'status'=>$ekub->status,'join_code'=>$ekub->join_code,'members'=>$members,'requests'=>$requests,'ad'=>$adData];
            });
            $commissions = DB::table('merchant_commissions as c')->join('ekubs as e','e.id','=','c.ekub_id')->where('c.merchant_id',$merchant->id)->orderByDesc('c.id')->limit(100)->get(['c.id','c.ekub_id','c.period_no','c.gross_amount','c.commission_amount','c.status','c.created_at','e.name as ekub_name'])->map(fn ($row) => (array)$row)->values();
        }
        $merchantData = $merchant ? (array)$merchant : null;
        if ($merchantData) {
            $merchantData['tin_last_four'] = substr((string)($merchantData['tin'] ?? ''), -4);
            unset($merchantData['tin'], $merchantData['tin_document']);
        }
        return response()->json([
            'merchant'=>$merchantData,
            'business_categories'=>self::BUSINESS_CATEGORIES,
            'ekub_categories'=>$merchant && $merchant->status === 'approved'
                ? [(string) $merchant->category]
                : config('ekub.categories'),
            'frequencies'=>config('ekub.frequencies'),
            'ekubs'=>$ekubs,
            'commissions'=>$commissions,
            'earned'=>(float)DB::table('merchant_commissions')->where('merchant_id',$merchant->id ?? 0)->sum('commission_amount'),
            'pending_commission'=>(float)DB::table('merchant_commissions')->where('merchant_id',$merchant->id ?? 0)->where('status','pending')->sum('commission_amount'),
        ]);
    }

    public function apply(Request $request)
    {
        $user = $request->user();
        if ($user->role !== 'member') return response()->json(['message'=>'Merchant applications are for member accounts.'],403);
        if ($user->kyc_status !== 'approved') return response()->json(['message'=>'Complete identity verification and wait for admin approval before applying as a merchant.'],403);
        $existing = $this->merchant((int)$user->id);
        if ($existing && $existing->status === 'approved') return response()->json(['message'=>'This merchant account is already approved.'],422);
        $tinRule = Rule::unique('merchants','tin');
        if ($existing) $tinRule->ignore($existing->id);
        $data = $request->validate([
            'business_name'=>['required','string','min:2','max:160'],
            'tin'=>['required','regex:/^\d{10}$/',$tinRule],
            'category'=>['required','in:'.implode(',',self::BUSINESS_CATEGORIES)],
            'contact_name'=>['required','string','min:2','max:160'],
            'business_phone'=>['required','string','min:9','max:32'],
            'business_email'=>['nullable','email','max:190'],
            'address'=>['required','string','min:4','max:255'],
            'website_url'=>['nullable','url','max:255'],
            'tin_document'=>['nullable','file','mimes:pdf,jpg,jpeg,png,webp','max:1024'],
        ]);
        $location = app(LocationGeocoder::class)->geocode($data['address']);
        if (! $location) return response()->json(['message'=>'We could not find that business location. Include the area and city, such as “Bole, Addis Ababa”, then try again.'],422);
        $document = $existing->tin_document ?? null;
        $oldDocument = $document;
        if ($request->file('tin_document')) {
            $prefix = trim(preg_replace('/[^\pL\pN_-]+/u', '-', (string) $user->username), '-_') ?: 'member';
            $document = app(UploadStorage::class)->putForUser($request->file('tin_document'), (string) $user->username, (int) $user->id, 'merchant_tin', mb_substr($prefix, 0, 48).'-tin-'.Str::random(10).'.'.$request->file('tin_document')->getClientOriginalExtension());
        }
        $fields = ['business_name'=>trim($data['business_name']),'tin'=>$data['tin'],'category'=>$data['category'],'contact_name'=>trim($data['contact_name']),'business_phone'=>trim($data['business_phone']),'business_email'=>$data['business_email'] ?? null,'address'=>trim($data['address']),'website_url'=>$data['website_url'] ?? null,'location_lat'=>$location['latitude'],'location_lng'=>$location['longitude'],'tin_document'=>$document,'status'=>'pending','rejection_reason'=>null,'submitted_at'=>now(),'reviewed_at'=>null,'reviewed_by'=>null,'updated_at'=>now()];
        if ($existing) DB::table('merchants')->where('id',$existing->id)->update($fields);
        else DB::table('merchants')->insert($fields + ['user_id'=>$user->id,'created_at'=>now()]);
        if ($request->file('tin_document') && $oldDocument && $oldDocument !== $document) app(UploadStorage::class)->delete($oldDocument);
        return response()->json(['message'=>'Merchant application submitted for admin review.','status'=>'pending'],201);
    }

    public function createEkub(Request $request)
    {
        $merchant = $this->merchant((int)$request->user()->id);
        if (! $merchant || $merchant->status !== 'approved') return response()->json(['message'=>'An approved merchant account is required.'],403);
        $data = $request->validate(['name'=>['required','string','min:2','max:120'],'frequency'=>['required','in:'.implode(',',config('ekub.frequencies'))],'base_amount'=>['required','numeric','gt:0','max:100000000'],'duration'=>['required','integer','min:2','max:500'],'banner_image'=>['nullable','file','image','mimes:jpg,jpeg,png,webp','max:1024']]);
        if (! in_array($merchant->category, self::BUSINESS_CATEGORIES, true)) return response()->json(['message'=>'Your approved merchant category is invalid. Contact an administrator.'],422);
        $user = $request->user();
        $file = $request->file('banner_image');
        $bannerPath = $file ? app(UploadStorage::class)->putForUser($file, (string)$user->username, (int)$user->id, 'merchant_banners', 'ekub-banner-'.Str::random(12).'.'.$file->getClientOriginalExtension()) : null;
        try {
            $id = DB::transaction(function () use ($merchant, $data, $bannerPath): int {
                $id = DB::table('ekubs')->insertGetId(['merchant_id'=>$merchant->id,'join_code'=>$this->code(),'name'=>trim($data['name']),'category'=>$merchant->category,'frequency'=>$data['frequency'],'base_amount'=>round((float)$data['base_amount'],2),'duration'=>(int)$data['duration'],'status'=>'open','is_item'=>false,'created_at'=>now()]);
                DB::table('merchant_ekub_ads')->insert(['ekub_id'=>$id,'merchant_id'=>$merchant->id,'title'=>$merchant->business_name,'description'=>null,'images'=>json_encode($bannerPath ? [$bannerPath] : []),'website_url'=>$merchant->website_url,'location_name'=>$merchant->address,'latitude'=>$merchant->location_lat,'longitude'=>$merchant->location_lng,'created_at'=>now(),'updated_at'=>now()]);
                return (int)$id;
            });
        } catch (\Throwable $e) {
            if ($bannerPath) app(UploadStorage::class)->delete($bannerPath);
            throw $e;
        }
        $ekub = DB::table('ekubs')->where('id',$id)->first(['id','name','join_code','category','frequency','base_amount','duration','status']);
        return response()->json(['message'=>$bannerPath ? 'Private Ekub created with its banner. Share its invite code with selected people.' : 'Private Ekub created. Share its invite code with selected people.','ekub'=>$ekub],201);
    }

    public function decideJoin(Request $request, int $requestId, string $action)
    {
        $merchant = $this->merchant((int)$request->user()->id);
        if (! $merchant || $merchant->status !== 'approved') return response()->json(['message'=>'An approved merchant account is required.'],403);
        if (! in_array($action,['approve','reject'],true)) return response()->json(['message'=>'Invalid action.'],404);
        $join = DB::table('merchant_join_requests')->where('id',$requestId)->where('merchant_id',$merchant->id)->where('status','pending')->first();
        if (! $join) return response()->json(['message'=>'Pending join request not found.'],404);
        try {
            DB::transaction(function () use ($join,$merchant,$request,$action): void {
                $lockedRequest = DB::table('merchant_join_requests')->where('id',$join->id)->lockForUpdate()->first();
                if (! $lockedRequest || $lockedRequest->status !== 'pending') abort(422,'This join request was already reviewed.');
                if ($action === 'reject') {
                    DB::table('merchant_join_requests')->where('id',$join->id)->update(['status'=>'rejected','reviewed_at'=>now(),'reviewed_by'=>$request->user()->id]);
                } else {
                    if (DB::table('users')->where('id',$join->user_id)->value('kyc_status') !== 'approved') abort(422,'This member must have approved identity verification before joining.');
                    $ekub = DB::table('ekubs')->where('id',$join->ekub_id)->where('merchant_id',$merchant->id)->lockForUpdate()->first();
                    if (! $ekub || $ekub->status !== 'open') abort(422,'This Ekub is no longer accepting member requests.');
                    if (DB::table('ekub_members')->where('ekub_id',$join->ekub_id)->where('user_id',$join->user_id)->exists()) abort(422,'This person is already a member.');
                    $fraction = ['full'=>1.0,'half'=>0.5,'quarter'=>0.25][$join->share_type] ?? 1.0;
                    $used = (float)DB::table('ekub_members')->where('ekub_id',$join->ekub_id)->sum('share_fraction');
                    if ($used + $fraction > (float)$ekub->duration + 0.000001) abort(422,'This Ekub has no remaining capacity for the selected share.');
                    DB::table('ekub_members')->insert(['ekub_id'=>$join->ekub_id,'user_id'=>$join->user_id,'share_type'=>$join->share_type,'share_fraction'=>$fraction,'contribution_amount'=>round((float)$ekub->base_amount*$fraction,2),'status'=>'joined','joined_at'=>now()]);
                    DB::table('merchant_join_requests')->where('id',$join->id)->update(['status'=>'approved','reviewed_at'=>now(),'reviewed_by'=>$request->user()->id]);
                }
                $title = $action === 'approve' ? 'Your Ekub request was approved' : 'Your Ekub request was declined';
                DB::table('member_notifications')->insertOrIgnore(['user_id'=>$join->user_id,'type'=>'merchant_join_'.$action,'title'=>$title,'body'=>'The merchant reviewed your request to join this private Ekub.','event_key'=>'merchant.join.'.$action.':'.$join->id.':'.now()->timestamp,'created_at'=>now()]);
            });
        } catch (\Illuminate\Http\Exceptions\HttpResponseException $e) { throw $e; }
        return response()->json(['message'=>$action === 'approve' ? 'Member approved. Admin still controls payment review.' : 'Join request rejected.']);
    }

    public function saveAd(Request $request, int $ekubId)
    {
        $merchant = $this->merchant((int)$request->user()->id);
        $ekub = $merchant ? DB::table('ekubs')->where('id',$ekubId)->where('merchant_id',$merchant->id)->first() : null;
        if (! $merchant || $merchant->status !== 'approved' || ! $ekub) return response()->json(['message'=>'You can only edit ads for your own Ekubs.'],403);
        $data = $request->validate(['title'=>['required','string','min:2','max:160'],'description'=>['nullable','string','max:3000'],'website_url'=>['nullable','url','max:255'],'location_name'=>['nullable','string','max:255'],'images'=>['nullable','array','max:3'],'images.*'=>['file','image','mimes:jpg,jpeg,png,webp','max:1024']]);
        $locationName = trim((string)($data['location_name'] ?? ''));
        $location = $locationName !== '' ? app(LocationGeocoder::class)->geocode($locationName) : null;
        if ($locationName !== '' && ! $location) return response()->json(['message'=>'We could not find that ad location. Add the area and city, then try again.'],422);
        $old = DB::table('merchant_ekub_ads')->where('ekub_id',$ekubId)->first();
        $oldImages = $old ? (json_decode($old->images ?? '[]',true) ?: []) : [];
        $images = $oldImages;
        $newImages = [];
        $username = trim(preg_replace('/[^\pL\pN_-]+/u', '-', (string) $request->user()->username), '-_') ?: 'member';
        try {
            foreach ($request->file('images',[]) as $index=>$file) {
                $path = app(UploadStorage::class)->putForUser($file, (string) $request->user()->username, (int) $request->user()->id, 'merchant_ads', mb_substr($username, 0, 48).'-ekub-'.$ekubId.'-ad-'.Str::random(10).'.'.$file->getClientOriginalExtension());
                $newImages[] = $path;
                $images[$index] = $path;
            }
            $images = array_slice(array_values($images),0,3);
            DB::table('merchant_ekub_ads')->updateOrInsert(['ekub_id'=>$ekubId],['merchant_id'=>$merchant->id,'title'=>trim($data['title']),'description'=>$data['description'] ?? null,'images'=>json_encode($images),'website_url'=>$data['website_url'] ?? null,'location_name'=>$locationName ?: $merchant->address,'latitude'=>$location['latitude'] ?? $merchant->location_lat,'longitude'=>$location['longitude'] ?? $merchant->location_lng,'created_at'=>$old->created_at ?? now(),'updated_at'=>now()]);
        } catch (\Throwable $exception) {
            foreach ($newImages as $path) app(UploadStorage::class)->delete($path);
            throw $exception;
        }
        foreach ($oldImages as $path) if (! in_array($path, $images, true)) app(UploadStorage::class)->delete((string) $path);
        return response()->json(['message'=>'Merchant advertisement saved.','image_count'=>count($images)]);
    }
}
