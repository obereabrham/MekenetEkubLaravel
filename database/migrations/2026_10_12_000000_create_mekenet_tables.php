<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
return new class extends Migration {
    public function up(): void
    {
        Schema::create('users', function (Blueprint $t) {
            $t->id(); $t->string('first_name'); $t->string('last_name'); $t->string('username')->unique(); $t->string('phone')->unique(); $t->string('email')->nullable()->unique();
            $t->text('password_hash'); $t->string('role',24)->default('member'); $t->string('status',24)->default('active'); $t->string('kyc_status',24)->default('not_submitted');
            $t->boolean('first_login')->default(true); $t->string('profile_picture')->nullable(); $t->string('twofa_method',24)->default('authenticator'); $t->text('totp_secret')->nullable(); $t->boolean('twofa_enabled')->default(false); $t->timestamp('created_at')->useCurrent();
        });
        Schema::create('partners', function (Blueprint $t) { $t->id(); $t->foreignId('user_id')->unique()->constrained('users')->cascadeOnDelete(); $t->text('permissions'); $t->timestamp('created_at')->useCurrent(); });
        Schema::create('ekubs', function (Blueprint $t) {
            $t->id(); $t->string('name'); $t->string('category'); $t->string('frequency'); $t->decimal('base_amount',14,2); $t->unsignedInteger('duration'); $t->string('status',24)->default('open'); $t->boolean('is_item')->default(false);
            $t->string('product1')->nullable(); $t->string('product2')->nullable(); $t->string('product3')->nullable(); $t->dateTime('start_at')->nullable(); $t->unsignedInteger('current_period')->default(0); $t->dateTime('finished_at')->nullable(); $t->unsignedBigInteger('recreated_from')->nullable(); $t->dateTime('period_started_at')->nullable(); $t->timestamp('created_at')->useCurrent(); $t->index(['status','id']);
        });
        Schema::create('ekub_members', function (Blueprint $t) {
            $t->id(); $t->foreignId('ekub_id')->constrained('ekubs')->cascadeOnDelete(); $t->foreignId('user_id')->constrained('users')->cascadeOnDelete(); $t->string('share_type',24); $t->decimal('share_fraction',6,2); $t->decimal('contribution_amount',14,2); $t->string('status',24)->default('joined'); $t->timestamp('joined_at')->useCurrent(); $t->unique(['ekub_id','user_id']);
        });
        Schema::create('kyc_verifications', function (Blueprint $t) {
            $t->id(); $t->foreignId('user_id')->unique()->constrained('users')->cascadeOnDelete(); $t->string('full_name'); $t->string('dob',40); $t->string('gender',24); $t->string('id_type',40); $t->string('id_number');
            $t->string('id_front'); $t->string('id_back')->nullable(); $t->string('video_agreement'); $t->string('status',24)->default('pending'); $t->text('rejection_reason')->nullable(); $t->timestamp('submitted_at')->useCurrent(); $t->dateTime('reviewed_at')->nullable(); $t->string('approved_by')->nullable(); $t->string('personal_photo')->nullable();
        });
        Schema::create('payments', function (Blueprint $t) {
            $t->id(); $t->foreignId('ekub_id')->constrained('ekubs')->cascadeOnDelete(); $t->foreignId('member_id')->constrained('ekub_members')->cascadeOnDelete(); $t->foreignId('user_id')->constrained('users')->cascadeOnDelete(); $t->unsignedInteger('period_no');
            $t->decimal('amount',14,2); $t->decimal('penalty',14,2)->default(0); $t->string('method',40); $t->string('transaction_no')->unique(); $t->string('screenshot'); $t->string('status',24)->default('pending'); $t->text('rejection_reason')->nullable();
            $t->timestamp('submitted_at')->useCurrent(); $t->dateTime('reviewed_at')->nullable(); $t->string('approved_by')->nullable(); $t->decimal('approved_amount',14,2)->default(0); $t->index(['ekub_id','user_id','period_no']);
        });
        Schema::create('payouts', function (Blueprint $t) {
            $t->id(); $t->foreignId('ekub_id')->constrained('ekubs')->cascadeOnDelete(); $t->unsignedInteger('period_no'); $t->foreignId('winner_member_id')->constrained('ekub_members')->cascadeOnDelete(); $t->decimal('gross_amount',14,2); $t->decimal('service_fee',14,2); $t->decimal('net_amount',14,2);
            $t->string('status',24)->default('pending'); $t->timestamp('created_at')->useCurrent(); $t->boolean('celebrated')->default(false); $t->dateTime('sent_at')->nullable(); $t->string('sent_by')->nullable(); $t->unique(['ekub_id','period_no']);
        });
        Schema::create('payment_methods', function (Blueprint $t) { $t->id(); $t->foreignId('user_id')->constrained('users')->cascadeOnDelete(); $t->string('bank_name'); $t->string('account_number'); $t->string('account_name'); $t->boolean('is_default')->default(false); $t->timestamp('created_at')->useCurrent(); $t->unique(['user_id','bank_name','account_number']); });
        Schema::create('deleted_accounts', function (Blueprint $t) { $t->id(); $t->unsignedBigInteger('user_id')->nullable(); $t->string('full_name'); $t->string('username')->nullable(); $t->string('phone')->nullable(); $t->string('email')->nullable(); $t->string('role')->nullable(); $t->string('reason'); $t->text('details')->nullable(); $t->dateTime('deleted_at'); });
        Schema::create('ads', function (Blueprint $t) { $t->unsignedTinyInteger('slot')->primary(); $t->string('image'); $t->timestamp('updated_at')->useCurrent(); });
        Schema::create('ekub_images', function (Blueprint $t) { $t->id(); $t->foreignId('ekub_id')->constrained('ekubs')->cascadeOnDelete(); $t->string('image'); $t->unsignedInteger('position')->default(0); $t->timestamp('created_at')->useCurrent(); });
        Schema::create('ekub_applications', function (Blueprint $t) { $t->id(); $t->foreignId('user_id')->constrained('users')->cascadeOnDelete(); $t->string('name'); $t->string('category'); $t->string('frequency'); $t->decimal('base_amount',14,2); $t->unsignedInteger('duration'); $t->text('note')->nullable(); $t->string('status',24)->default('pending'); $t->text('rejection_reason')->nullable(); $t->unsignedBigInteger('created_ekub_id')->nullable(); $t->timestamp('created_at')->useCurrent(); $t->dateTime('reviewed_at')->nullable(); $t->string('reviewed_by')->nullable(); });
        Schema::create('period_dues', function (Blueprint $t) { $t->foreignId('ekub_id')->constrained('ekubs')->cascadeOnDelete(); $t->unsignedInteger('period_no'); $t->dateTime('started_at'); $t->primary(['ekub_id','period_no']); });
    }
    public function down(): void { foreach (['period_dues','ekub_applications','ekub_images','ads','deleted_accounts','payment_methods','payouts','payments','kyc_verifications','ekub_members','ekubs','partners','users'] as $table) Schema::dropIfExists($table); }
};