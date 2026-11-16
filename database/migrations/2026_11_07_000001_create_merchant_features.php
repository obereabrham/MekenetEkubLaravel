<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('merchants', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained('users')->cascadeOnDelete();
            $table->string('business_name', 160);
            $table->string('tin', 20)->unique();
            $table->string('category', 50);
            $table->string('contact_name', 160);
            $table->string('business_phone', 32);
            $table->string('business_email', 190)->nullable();
            $table->string('address', 255);
            $table->string('website_url', 255)->nullable();
            $table->string('tin_document', 255)->nullable();
            $table->decimal('location_lat', 10, 7)->nullable();
            $table->decimal('location_lng', 10, 7)->nullable();
            $table->string('status', 20)->default('pending')->index();
            $table->text('rejection_reason')->nullable();
            $table->timestamp('submitted_at')->nullable();
            $table->timestamp('reviewed_at')->nullable();
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });

        Schema::table('ekubs', function (Blueprint $table): void {
            $table->foreignId('merchant_id')->nullable()->after('id')->constrained('merchants')->nullOnDelete();
            $table->string('join_code', 20)->nullable()->unique();
        });

        Schema::create('merchant_join_requests', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('ekub_id')->constrained('ekubs')->cascadeOnDelete();
            $table->foreignId('merchant_id')->constrained('merchants')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('share_type', 20)->default('full');
            $table->string('status', 20)->default('pending')->index();
            $table->timestamp('created_at')->nullable();
            $table->timestamp('reviewed_at')->nullable();
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->unique(['ekub_id', 'user_id']);
        });

        Schema::create('merchant_ekub_ads', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('ekub_id')->unique()->constrained('ekubs')->cascadeOnDelete();
            $table->foreignId('merchant_id')->constrained('merchants')->cascadeOnDelete();
            $table->string('title', 160);
            $table->text('description')->nullable();
            $table->text('images')->nullable();
            $table->string('website_url', 255)->nullable();
            $table->string('location_name', 255)->nullable();
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->timestamps();
        });

        Schema::create('merchant_commissions', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('merchant_id')->constrained('merchants')->cascadeOnDelete();
            $table->foreignId('ekub_id')->constrained('ekubs')->cascadeOnDelete();
            $table->foreignId('payout_id')->unique()->constrained('payouts')->cascadeOnDelete();
            $table->unsignedInteger('period_no');
            $table->decimal('gross_amount', 14, 2);
            $table->decimal('commission_amount', 14, 2);
            $table->string('status', 20)->default('pending')->index();
            $table->timestamp('paid_at')->nullable();
            $table->foreignId('paid_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('created_at')->nullable();
        });

        Schema::table('payouts', function (Blueprint $table): void {
            $table->decimal('admin_fee', 14, 2)->default(0);
            $table->decimal('merchant_commission', 14, 2)->default(0);
        });
    }

    public function down(): void
    {
        Schema::table('payouts', function (Blueprint $table): void {
            $table->dropColumn(['admin_fee', 'merchant_commission']);
        });
        Schema::dropIfExists('merchant_commissions');
        Schema::dropIfExists('merchant_ekub_ads');
        Schema::dropIfExists('merchant_join_requests');
        Schema::table('ekubs', function (Blueprint $table): void {
            $table->dropForeign(['merchant_id']);
            $table->dropUnique(['join_code']);
            $table->dropColumn(['merchant_id', 'join_code']);
        });
        Schema::dropIfExists('merchants');
    }
};
