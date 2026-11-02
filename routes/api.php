<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\AnalyticsController;
use App\Http\Controllers\Api\MemberController;
use App\Http\Controllers\Api\MerchantController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\ProfileController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::post('/analytics/visit', [AnalyticsController::class, 'visit'])->middleware('throttle:30,1');
    Route::prefix('auth')->group(function (): void {
        Route::post('/register', [AuthController::class, 'register'])->middleware('throttle:6,1');
        Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:8,1');
        Route::post('/2fa/verify', [AuthController::class, 'verifyTwoFactor'])->middleware('throttle:10,1');
        Route::post('/2fa/resend', [AuthController::class, 'resendEmailCode'])->middleware('throttle:3,1');
        Route::post('/forgot-password', [AuthController::class, 'forgotPassword'])->middleware('throttle:5,1');
        Route::post('/reset-password', [AuthController::class, 'resetPassword'])->middleware('throttle:8,1');
    });

    Route::middleware('auth:sanctum')->group(function (): void {
        Route::get('/me', [AuthController::class, 'me']);
        Route::post('/auth/logout', [AuthController::class, 'logout']);
    });

    Route::get('/ads', [MemberController::class, 'ads'])->middleware('throttle:30,1');

    Route::middleware(['auth:sanctum', 'member.api'])->group(function (): void {
        Route::get('/notifications', [MemberController::class, 'notifications']);
        Route::post('/notifications/read', [MemberController::class, 'readNotifications']);
        Route::post('/profile', [ProfileController::class, 'updateProfile']);
        Route::post('/profile/email/send-code', [ProfileController::class, 'sendEmailChangeCode'])->middleware('throttle:3,1');
        Route::post('/profile/email/verify', [ProfileController::class, 'verifyEmailChange'])->middleware('throttle:8,1');
        Route::post('/profile/picture', [ProfileController::class, 'updateProfilePicture']);
        Route::get('/profile/payment-methods', [ProfileController::class, 'paymentMethods']);
        Route::post('/profile/payment-methods', [ProfileController::class, 'addPaymentMethod']);
        Route::post('/profile/payment-methods/{id}/default', [ProfileController::class, 'defaultPaymentMethod'])->whereNumber('id');
        Route::delete('/profile/payment-methods/{id}', [ProfileController::class, 'deletePaymentMethod'])->whereNumber('id');
        Route::get('/profile/applications', [ProfileController::class, 'applications']);
        Route::post('/profile/applications', [ProfileController::class, 'applyEkub']);
        Route::get('/profile/finished-ekubs', [ProfileController::class, 'finishedEkubs']);
        Route::get('/profile/full-ekubs', [ProfileController::class, 'fullEkubs']);
        Route::match(['get', 'post'], '/profile/kyc', [ProfileController::class, 'kyc']);
        Route::get('/profile/security', [ProfileController::class, 'security']);
        Route::post('/profile/security/{action}', [ProfileController::class, 'securityAction'])
            ->middleware('throttle:10,1')
            ->whereIn('action', ['send-email-code', 'verify-email', 'start-authenticator', 'verify-authenticator', 'disable']);
        Route::post('/profile/password', [ProfileController::class, 'changePassword']);
        Route::post('/profile/account/delete', [ProfileController::class, 'deleteAccount']);
        Route::get('/merchant', [MerchantController::class, 'dashboard']);
        Route::post('/merchant/application', [MerchantController::class, 'apply']);
        Route::post('/merchant/ekubs', [MerchantController::class, 'createEkub']);
        Route::post('/merchant/requests/{requestId}/{action}', [MerchantController::class, 'decideJoin'])->whereNumber('requestId')->whereIn('action', ['approve', 'reject']);
        Route::post('/merchant/ekubs/{ekubId}/ad', [MerchantController::class, 'saveAd'])->whereNumber('ekubId');
        Route::get('/ekubs', [MemberController::class, 'ekubs']);
        Route::get('/ekubs/{ekubId}', [MemberController::class, 'ekubDetail'])->whereNumber('ekubId');
        Route::post('/ekubs/{ekubId}/join', [MemberController::class, 'joinEkub'])->whereNumber('ekubId');
        Route::delete('/ekubs/{ekubId}/leave', [MemberController::class, 'leaveEkub'])->whereNumber('ekubId');
        Route::get('/my/ekubs', [MemberController::class, 'myEkubs']);
        Route::get('/my/status', [MemberController::class, 'status']);
        Route::get('/payments/methods', [PaymentController::class, 'methods']);
        Route::post('/payments/check-transaction', [PaymentController::class, 'checkTransaction'])
            ->middleware('throttle:20,1');
        Route::post('/payments/{ekubId}/{periodNo}', [PaymentController::class, 'submitManual'])
            ->whereNumber('ekubId')
            ->whereNumber('periodNo');
    });

    Route::prefix('admin')->middleware(['auth:sanctum', 'admin.api'])->group(function (): void {
        Route::get('/merchants', [\App\Http\Controllers\Api\AdminMerchantController::class, 'index']);
        Route::post('/merchants/{merchantId}/{action}', [\App\Http\Controllers\Api\AdminMerchantController::class, 'review'])
            ->whereNumber('merchantId')->whereIn('action', ['approve', 'reject']);
        Route::post('/merchant-commissions/{commissionId}/paid', [\App\Http\Controllers\Api\AdminMerchantController::class, 'markCommissionPaid'])
            ->whereNumber('commissionId');
    });
});


