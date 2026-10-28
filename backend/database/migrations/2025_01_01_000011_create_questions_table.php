<?php
// Lamma - by Mohamed Ibrahim

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('questions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('category_id')->constrained()->cascadeOnDelete();
            $table->enum('type', ['mcq', 'emoji_movie', 'true_false', 'complete_phrase', 'who_said']);
            $table->text('prompt_ar');
            $table->string('emoji_prompt', 500)->nullable();
            $table->json('options'); // 4 strings for mcq/emoji_movie/who_said, 2 for true_false
            $table->tinyInteger('correct_index');
            $table->enum('difficulty', ['easy', 'medium', 'hard'])->default('medium');
            $table->text('explanation_ar')->nullable();
            $table->enum('source', ['seed', 'gemini'])->default('seed');
            $table->string('content_hash', 40)->unique(); // sha1
            $table->boolean('is_active')->default(true);
            $table->timestamp('published_at')->nullable();
            $table->timestamps();

            $table->index(['category_id', 'is_active', 'difficulty']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('questions');
    }
};
