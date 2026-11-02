<?php
// Lamma - by Mohamed Ibrahim

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. تحديث جدول الأسئلة
        Schema::table('questions', function (Blueprint $table) {
            $table->text('normalized_prompt')->nullable()->after('prompt_ar');
            $table->string('prompt_hash', 64)->nullable()->index()->after('content_hash');
            $table->string('answer_hash', 64)->nullable()->index()->after('prompt_hash');
            $table->string('distractors_hash', 64)->nullable()->after('answer_hash');
            $table->enum('status', ['active', 'quarantined', 'rejected'])->default('active')->index()->after('is_active');
            $table->string('rejection_reason', 255)->nullable()->after('status');
            $table->unsignedInteger('times_served')->default(0)->after('rejection_reason');
            $table->unsignedInteger('reports_count')->default(0)->after('times_served');
        });

        // 2. جدول مجموعات كلمات الجاسوس المتجانسة بدقة (Spy Word Groups)
        Schema::create('spy_word_groups', function (Blueprint $table) {
            $table->id();
            $table->string('pack_slug', 64)->default('places')->index();
            $table->string('title_ar', 255); // مثل: مدن ساحلية مصرية، أكلات شعبية، غرف منزلية
            $table->string('theme', 100)->nullable();
            $table->enum('difficulty', ['easy', 'medium', 'hard'])->default('medium');
            $table->enum('status', ['active', 'quarantined', 'rejected'])->default('active')->index();
            $table->string('content_hash', 64)->unique();
            $table->unsignedInteger('times_served')->default(0);
            $table->unsignedInteger('reports_count')->default(0);
            $table->enum('source', ['seed', 'gemini'])->default('seed');
            $table->timestamps();

            $table->index(['pack_slug', 'status', 'difficulty']);
        });

        // 3. كلمات المجموعة
        Schema::create('spy_group_words', function (Blueprint $table) {
            $table->id();
            $table->foreignId('group_id')->constrained('spy_word_groups')->cascadeOnDelete();
            $table->string('word_ar', 255);
            $table->string('normalized_word', 255);
            $table->string('content_hash', 64);
            $table->timestamps();

            $table->index(['group_id', 'content_hash']);
        });

        // 4. تحديث جدول كلمات التمثيل (Charades)
        Schema::table('charades_words', function (Blueprint $table) {
            $table->enum('difficulty', ['easy', 'medium', 'hard'])->default('medium')->after('word_ar');
            $table->enum('status', ['active', 'quarantined', 'rejected'])->default('active')->index()->after('is_active');
            $table->unsignedInteger('times_served')->default(0)->after('status');
            $table->unsignedInteger('reports_count')->default(0)->after('times_served');
        });

        // 5. السجل الموحد لمشاهدات الأجهزة لجميع أنواع المحتوى
        Schema::create('device_content_history', function (Blueprint $table) {
            $table->id();
            $table->string('device_id', 64)->index();
            $table->enum('content_type', ['trivia', 'spy_group', 'charades'])->index();
            $table->unsignedBigInteger('content_id')->index();
            $table->timestamp('seen_at')->useCurrent();

            $table->unique(['device_id', 'content_type', 'content_id'], 'device_content_unique');
            $table->index(['device_id', 'content_type']);
        });

        // 6. جلسات الغرف على الباك إند لتتبع حضور الأجهزة ومنع التكرار المشترك
        Schema::create('room_sessions', function (Blueprint $table) {
            $table->id();
            $table->string('room_code', 16)->unique();
            $table->string('host_device_id', 64)->index();
            $table->enum('status', ['lobby', 'active', 'finished'])->default('lobby');
            $table->string('current_game', 32)->nullable();
            $table->timestamps();
        });

        Schema::create('room_session_devices', function (Blueprint $table) {
            $table->id();
            $table->foreignId('room_session_id')->constrained('room_sessions')->cascadeOnDelete();
            $table->string('device_id', 64)->index();
            $table->timestamp('joined_at')->useCurrent();
            $table->timestamp('left_at')->nullable();

            $table->unique(['room_session_id', 'device_id']);
        });

        // 7. بلاغات اللاعبين عن المحتوى غير السليم
        Schema::create('content_reports', function (Blueprint $table) {
            $table->id();
            $table->string('device_id', 64);
            $table->enum('content_type', ['trivia', 'spy_group', 'charades'])->index();
            $table->unsignedBigInteger('content_id')->index();
            $table->string('reason', 255)->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['content_type', 'content_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('content_reports');
        Schema::dropIfExists('room_session_devices');
        Schema::dropIfExists('room_sessions');
        Schema::dropIfExists('device_content_history');

        Schema::table('charades_words', function (Blueprint $table) {
            $table->dropColumn(['difficulty', 'status', 'times_served', 'reports_count']);
        });

        Schema::dropIfExists('spy_group_words');
        Schema::dropIfExists('spy_word_groups');

        Schema::table('questions', function (Blueprint $table) {
            $table->dropColumn([
                'normalized_prompt',
                'prompt_hash',
                'answer_hash',
                'distractors_hash',
                'status',
                'rejection_reason',
                'times_served',
                'reports_count',
            ]);
        });
    }
};
