<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('site_visits', function (Blueprint $table): void {
            $table->id();
            $table->string('platform', 12);
            $table->char('visitor_hash', 64);
            $table->unsignedBigInteger('user_id')->nullable();
            $table->date('visit_date');
            $table->timestamp('last_seen_at')->nullable();
            $table->timestamps();
            $table->unique(['platform', 'visit_date', 'visitor_hash'], 'site_visits_daily_unique');
            $table->index(['platform', 'visit_date', 'user_id'], 'site_visits_period_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('site_visits');
    }
};
