<?php
// Lamma - by Mohamed Ibrahim

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // 1. تحديث slug وفئات جدول categories الخاص بـ Trivia
        // أ) أفلام ومسلسلات: تحويل guess_movie القديم إلى movies
        DB::table('categories')
            ->where('slug', 'guess_movie')
            ->update([
                'slug' => 'movies',
                'name_ar' => 'أفلام ومسلسلات',
                'emoji' => '🎬',
                'sort_order' => 1,
            ]);

        // ب) كورة مصرية: تحويل kora إلى sports
        DB::table('categories')
            ->where('slug', 'kora')
            ->update([
                'slug' => 'sports',
                'name_ar' => 'كورة مصرية',
                'emoji' => '⚽',
                'sort_order' => 2,
            ]);

        // ج) إفيهات وقفشات: توحيد الاسم العربي والإيموجي
        DB::table('categories')
            ->where('slug', 'afeehat')
            ->update([
                'name_ar' => 'إفيهات وقفشات',
                'emoji' => '😂',
                'sort_order' => 3,
            ]);

        // د) تاريخ وجغرافيا: إضافة الفئة إن لم تكن موجودة
        $historyExists = DB::table('categories')->where('slug', 'history')->exists();
        if (!$historyExists) {
            DB::table('categories')->insert([
                'slug' => 'history',
                'name_ar' => 'تاريخ وجغرافيا',
                'emoji' => '🏛️',
                'kind' => 'trivia',
                'is_active' => true,
                'sort_order' => 4,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        // هـ) معلومات عامة: تحديث الاسم والترتيب
        DB::table('categories')
            ->where('slug', 'general')
            ->update([
                'name_ar' => 'معلومات عامة',
                'emoji' => '💡',
                'sort_order' => 5,
            ]);

        // 2. توحيد حزم الجاسوس: تحويل pack_slug = 'food' إلى 'foods'
        DB::table('spy_word_groups')
            ->where('pack_slug', 'food')
            ->update(['pack_slug' => 'foods']);
    }

    public function down(): void
    {
        DB::table('categories')
            ->where('slug', 'movies')
            ->update(['slug' => 'guess_movie', 'name_ar' => 'خمّن الفيلم']);

        DB::table('categories')
            ->where('slug', 'sports')
            ->update(['slug' => 'kora', 'name_ar' => 'كورة']);

        DB::table('categories')
            ->where('slug', 'history')
            ->delete();
    }
};
