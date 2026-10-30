<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('kyc_verifications', function (Blueprint $table): void {
            $table->string('liveness_video')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('kyc_verifications', function (Blueprint $table): void {
            $table->dropColumn('liveness_video');
        });
    }
};
