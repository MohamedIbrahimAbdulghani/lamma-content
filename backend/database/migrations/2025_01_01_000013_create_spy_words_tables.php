<?php
// Lamma - by Mohamed Ibrahim

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('spy_word_packs', function (Blueprint $table) {
            $table->id();
            $table->enum('slug', ['places', 'movies', 'foods', 'mixed'])->unique();
            $table->string('name_ar');
            $table->timestamps();
        });

        Schema::create('spy_words', function (Blueprint $table) {
            $table->id();
            $table->foreignId('pack_id')->constrained('spy_word_packs')->cascadeOnDelete();
            $table->string('word_ar');
            $table->string('content_hash', 40)->unique();
            $table->boolean('is_active')->default(true);
            $table->enum('source', ['seed', 'gemini'])->default('seed');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('spy_words');
        Schema::dropIfExists('spy_word_packs');
    }
};
