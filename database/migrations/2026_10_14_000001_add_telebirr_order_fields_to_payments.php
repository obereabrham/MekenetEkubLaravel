<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('payments', function (Blueprint $table): void {
            $table->string('telebirr_merchant_order_id', 64)->nullable()->unique();
            $table->string('telebirr_prepay_id', 128)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('payments', function (Blueprint $table): void {
            $table->dropUnique(['telebirr_merchant_order_id']);
            $table->dropColumn(['telebirr_merchant_order_id', 'telebirr_prepay_id']);
        });
    }
};
