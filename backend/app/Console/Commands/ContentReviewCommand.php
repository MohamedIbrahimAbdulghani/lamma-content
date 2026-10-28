<?php
// Lamma - by Mohamed Ibrahim

namespace App\Console\Commands;

use App\Models\ContentVersion;
use App\Models\Question;
use Illuminate\Console\Command;

class ContentReviewCommand extends Command
{
    protected $signature = 'content:review 
                            {--all : الموافقة على جميع الأسئلة المعلقة وتفعيلها} 
                            {--reject-all : حذف جميع الأسئلة المعلقة}';

    protected $description = 'مراجعة الأسئلة المعلقة المولدة بالذكاء الاصطناعي للموافقة عليها أو حذفها';

    public function handle(): int
    {
        $pendingQuestions = Question::with('category')
            ->where('is_active', false)
            ->get();

        $totalPending = $pendingQuestions->count();

        if ($totalPending === 0) {
            $this->info('لا توجد أي أسئلة معلقة (is_active=0) للمراجعة حالياً.');
            return 0;
        }

        $this->info("=========================================");
        $this->info("   مراجعة الأسئلة المعلقة ({$totalPending} سؤال)   ");
        $this->info("=========================================");

        if ($this->option('all')) {
            Question::where('is_active', false)->update(['is_active' => true]);
            ContentVersion::bump("تمت الموافقة على {$totalPending} سؤال معلق");
            $this->info("تمت الموافقة على جميع الأسئلة ({$totalPending}) وتفعيلها بنجاح!");
            return 0;
        }

        if ($this->option('reject-all')) {
            if ($this->confirm("هل أنت متأكد من حذف جميع الأسئلة المعلقة ({$totalPending})؟", true)) {
                Question::where('is_active', false)->delete();
                $this->warn("تم حذف جميع الأسئلة المعلقة ({$totalPending}) بنجاح.");
            }
            return 0;
        }

        $approvedCount = 0;
        $deletedCount = 0;

        foreach ($pendingQuestions as $index => $question) {
            $currentIndex = $index + 1;
            $this->newLine();
            $this->line("--------------------------------------------------");
            $this->info("[سؤال {$currentIndex} من {$totalPending}] - ID: {$question->id}");
            $this->line("التصنيف: " . ($question->category?->name_ar ?? 'عام') . " ({$question->category?->slug})");
            $this->line("النوع: {$question->type} | الصعوبة: {$question->difficulty} | المصدر: {$question->source}");
            $this->newLine();
            $this->comment("نص السؤال:");
            $this->line("  {$question->prompt_ar}");

            if (!empty($question->emoji_prompt)) {
                $this->line("  الإيموجي: {$question->emoji_prompt}");
            }

            $this->newLine();
            $this->comment("الخيارات:");
            $options = (array) $question->options;
            foreach ($options as $optIdx => $opt) {
                $isCorrect = ($optIdx === $question->correct_index);
                $mark = $isCorrect ? ' [صح ✔]' : '';
                $this->line("  " . ($optIdx + 1) . ". {$opt}{$mark}");
            }

            if (!empty($question->explanation_ar)) {
                $this->newLine();
                $this->line("الشرح: {$question->explanation_ar}");
            }

            $this->newLine();
            $choice = $this->choice(
                'ما هو الإجراء لهذا السؤال؟',
                ['موافقة وتفعيل (Approve)', 'حذف (Delete)', 'تخطي للآن (Skip)', 'موافقة على كل المتبقي (Approve All)', 'إنهاء المراجعة (Exit)'],
                0
            );

            if ($choice === 'موافقة وتفعيل (Approve)') {
                $question->update(['is_active' => true]);
                $approvedCount++;
                $this->info("تم تفعيل السؤال رقم {$question->id}.");
            } elseif ($choice === 'حذف (Delete)') {
                $question->delete();
                $deletedCount++;
                $this->warn("تم حذف السؤال رقم {$question->id}.");
            } elseif ($choice === 'موافقة على كل المتبقي (Approve All)') {
                $remainingIds = $pendingQuestions->slice($index)->pluck('id');
                Question::whereIn('id', $remainingIds)->update(['is_active' => true]);
                $approvedCount += $remainingIds->count();
                $this->info("تمت الموافقة على جميع الأسئلة المتبقية ({$remainingIds->count()} سؤال).");
                break;
            } elseif ($choice === 'إنهاء المراجعة (Exit)') {
                $this->line('تم إنهاء المراجعة.');
                break;
            }
        }

        if ($approvedCount > 0) {
            ContentVersion::bump("تمت مراجعة وتفعيل {$approvedCount} سؤال جديد");
            $this->newLine();
            $this->info("تم بنجاح تفعيل {$approvedCount} سؤال وتحديث إصدار المحتوى!");
        }

        if ($deletedCount > 0) {
            $this->line("إجمالي الأسئلة المحذوفة: {$deletedCount}");
        }

        return 0;
    }
}
