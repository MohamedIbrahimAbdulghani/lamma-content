<?php
// Lamma - by Mohamed Ibrahim

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('rule_pages', function (Blueprint $table) {
            $table->id();
            $table->string('slug')->unique(); // app_guide, spy, trivia, charades, anti_cheat
            $table->string('title_ar');
            $table->enum('accent', ['coral', 'saffron', 'mint', 'neutral']);
            $table->json('sections'); // [{heading, kind: text|steps|points|tip, items:[...]}]
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('rule_pages');
    }
};
