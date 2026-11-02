<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('site_visits', function (Blueprint $table): void {
            $table->id();
            $table->string('source', 12);
            $table->string('visitor_hash', 64);
            $table->foreignId('member_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->date('visit_date');
            $table->timestamp('created_at')->useCurrent();
            $table->unique(['source', 'visitor_hash', 'visit_date']);
            $table->index(['source', 'visit_date']);
            $table->index(['source', 'member_user_id', 'visit_date']);
        });

        Schema::create('site_ratings', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained('users')->cascadeOnDelete();
            $table->smallInteger('rating');
            $table->text('comment')->nullable();
            $table->timestamp('updated_at')->useCurrent();
        });

        Schema::create('merchants', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained('users')->cascadeOnDelete();
            $table->string('business_name', 120);
            $table->string('tin', 40)->unique();
            $table->string('category', 40);
            $table->string('business_phone', 32);
            $table->string('address', 255);
            $table->string('website', 255)->nullable();
            $table->string('location', 255)->nullable();
            $table->string('status', 24)->default('pending');
            $table->text('rejection_reason')->nullable();
            $table->string('reviewed_by', 80)->nullable();
            $table->timestamp('created_at')->useCurrent();
            $table->dateTime('reviewed_at')->nullable();
        });

        Schema::table('ekubs', function (Blueprint $table): void {
            $table->foreignId('merchant_id')->nullable()->after('is_item')->constrained('merchants')->nullOnDelete();
            $table->string('invite_code', 20)->nullable()->unique();
        });

        Schema::create('merchant_join_requests', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('ekub_id')->constrained('ekubs')->cascadeOnDelete();
            $table->foreignId('merchant_id')->constrained('merchants')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('share_type', 24);
            $table->string('status', 24)->default('pending');
            $table->timestamp('created_at')->useCurrent();
            $table->dateTime('reviewed_at')->nullable();
            $table->unique(['ekub_id', 'user_id']);
            $table->index(['merchant_id', 'status']);
        });

        Schema::create('merchant_ekub_ads', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('ekub_id')->unique()->constrained('ekubs')->cascadeOnDelete();
            $table->string('title', 120);
            $table->text('body')->nullable();
            $table->string('website_url', 255)->nullable();
            $table->string('location', 255)->nullable();
            $table->text('images')->nullable();
            $table->timestamp('updated_at')->useCurrent();
        });

        Schema::create('merchant_commissions', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('merchant_id')->constrained('merchants')->cascadeOnDelete();
            $table->foreignId('ekub_id')->constrained('ekubs')->cascadeOnDelete();
            $table->foreignId('payout_id')->unique()->constrained('payouts')->cascadeOnDelete();
            $table->decimal('gross_amount', 14, 2);
            $table->decimal('amount', 14, 2);
            $table->decimal('admin_amount', 14, 2);
            $table->string('status', 24)->default('pending');
            $table->timestamp('created_at')->useCurrent();
            $table->dateTime('paid_at')->nullable();
            $table->string('paid_by', 80)->nullable();
            $table->index(['merchant_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('merchant_commissions');
        Schema::dropIfExists('merchant_ekub_ads');
        Schema::dropIfExists('merchant_join_requests');
        Schema::table('ekubs', function (Blueprint $table): void {
            $table->dropForeign(['merchant_id']);
            $table->dropUnique(['invite_code']);
            $table->dropColumn(['merchant_id', 'invite_code']);
        });
        Schema::dropIfExists('merchants');
        Schema::dropIfExists('site_ratings');
        Schema::dropIfExists('site_visits');
    }
};
