<?php
// Lamma - by Mohamed Ibrahim

namespace App\Console\Commands;

use App\Models\Category;
use App\Models\CharadesCategory;
use App\Models\ContentVersion;
use App\Models\Question;
use App\Models\SeenQuestion;
use App\Models\SpyWordPack;
use Illuminate\Console\Command;

class ContentStatsCommand extends Command
{
    protected $signature = 'content:stats';
    protected $description = 'إحصائيات الأسئلة والكلمات في قاعدة البيانات';

    public function handle(): int
    {
        $this->info("=========================================");
        $this->info("   إحصائيات محتوى لمّة (Lamma Content)   ");
        $this->info("=========================================");

        $currentVersion = ContentVersion::current();
        $this->line("إصدار المحتوى الحالي: " . ($currentVersion?->version ?? 1) . " (بتاريخ: " . ($currentVersion?->generated_at ?? 'غير محدد') . ")");
        $this->newLine();

        $this->info("--- [أسئلة المعلومات والمسابقات (Trivia)] ---");
        $categories = Category::where('kind', 'trivia')->get();
        $rows = [];
        $totalQuestions = 0;

        foreach ($categories as $cat) {
            $total = Question::where('category_id', $cat->id)->count();
            $seedCount = Question::where('category_id', $cat->id)->where('source', 'seed')->count();
            $geminiCount = Question::where('category_id', $cat->id)->where('source', 'gemini')->count();
            $totalQuestions += $total;

            $rows[] = [
                $cat->name_ar,
                $cat->slug,
                $cat->emoji,
                $seedCount,
                $geminiCount,
                $total,
            ];
        }

        $this->table(
            ['التصنيف', 'Slug', 'إيموجي', 'أساسي (Seed)', 'ذكاء اصطناعي (Gemini)', 'الإجمالي'],
            $rows
        );
        $pendingTotal = Question::where('is_active', false)->count();
        $this->line("إجمالي أسئلة المسابقات: {$totalQuestions} (منها {$pendingTotal} معلقة للمراجعة)");
        $this->newLine();

        $this->info("--- [كلمات لعبة الجاسوس (Spy)] ---");
        $spyPacks = SpyWordPack::withCount('words')->get();
        $spyRows = [];
        $totalSpyWords = 0;
        foreach ($spyPacks as $pack) {
            $spyRows[] = [$pack->name_ar, $pack->slug, $pack->words_count];
            $totalSpyWords += $pack->words_count;
        }
        $this->table(['الحزمة', 'Slug', 'عدد الكلمات'], $spyRows);
        $this->line("إجمالي كلمات الجاسوس: {$totalSpyWords}");
        $this->newLine();

        $this->info("--- [كلمات لعبة بدون كلام (Charades)] ---");
        $charadesCats = CharadesCategory::withCount('words')->get();
        $charadesRows = [];
        $totalCharadesWords = 0;
        foreach ($charadesCats as $cat) {
            $charadesRows[] = [$cat->name_ar, $cat->slug, $cat->words_count];
            $totalCharadesWords += $cat->words_count;
        }
        $this->table(['الفئة', 'Slug', 'عدد الكلمات'], $charadesRows);
        $this->line("إجمالي كلمات بدون كلام: {$totalCharadesWords}");
        $this->newLine();

        $seenCount = SeenQuestion::count();
        $uniqueDevices = SeenQuestion::distinct('device_id')->count('device_id');
        $this->line("عدد الأسئلة التي تم حلها: {$seenCount} (عبر {$uniqueDevices} أجهزة)");

        return 0;
    }
}
