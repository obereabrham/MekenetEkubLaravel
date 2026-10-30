<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('payments', function (Blueprint $table): void {
            $table->string('payment_currency', 8)->nullable();
            $table->decimal('payment_currency_amount', 18, 8)->nullable();
            $table->decimal('payment_exchange_rate', 18, 8)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('payments', function (Blueprint $table): void {
            $table->dropColumn(['payment_currency', 'payment_currency_amount', 'payment_exchange_rate']);
        });
    }
};
