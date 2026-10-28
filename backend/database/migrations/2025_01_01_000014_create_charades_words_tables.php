<?php
// Lamma - by Mohamed Ibrahim

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('charades_categories', function (Blueprint $table) {
            $table->id();
            $table->enum('slug', ['movies', 'jobs', 'actions', 'mixed'])->unique();
            $table->string('name_ar');
            $table->timestamps();
        });

        Schema::create('charades_words', function (Blueprint $table) {
            $table->id();
            $table->foreignId('category_id')->constrained('charades_categories')->cascadeOnDelete();
            $table->string('word_ar');
            $table->string('content_hash', 40)->unique();
            $table->boolean('is_active')->default(true);
            $table->enum('source', ['seed', 'gemini'])->default('seed');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('charades_words');
        Schema::dropIfExists('charades_categories');
    }
};
