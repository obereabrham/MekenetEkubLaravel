<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('website_ratings', function (Blueprint $table): void {
            $table->id();
            $table->unsignedBigInteger('user_id')->nullable();
            $table->string('display_name', 80);
            $table->unsignedTinyInteger('rating');
            $table->text('comment');
            $table->boolean('visible')->default(true);
            $table->timestamps();
            $table->index(['visible', 'created_at'], 'website_ratings_visible_created_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('website_ratings');
    }
};
