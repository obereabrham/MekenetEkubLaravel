<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('payments', function (Blueprint $table): void {
            $table->string('verification_provider', 32)->nullable();
            $table->string('verification_status', 24)->default('not_checked');
            $table->string('verification_message', 255)->nullable();
            $table->timestamp('verified_at')->nullable();
            $table->string('screenshot')->nullable()->change();
        });
    }

    public function down(): void
    {
        DB::table('payments')->whereNull('screenshot')->update(['screenshot' => '']);

        Schema::table('payments', function (Blueprint $table): void {
            $table->string('screenshot')->nullable(false)->change();
            $table->dropColumn([
                'verification_provider',
                'verification_status',
                'verification_message',
                'verified_at',
            ]);
        });
    }
};
