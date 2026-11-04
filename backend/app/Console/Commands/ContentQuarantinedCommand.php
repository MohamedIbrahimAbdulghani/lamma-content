<?php
// Lamma - by Mohamed Ibrahim

namespace App\Console\Commands;

use App\Models\CharadesWord;
use App\Models\ContentReport;
use App\Models\Question;
use App\Models\SpyWordGroup;
use Illuminate\Console\Command;

class ContentQuarantinedCommand extends Command
{
    protected $signature = 'content:quarantined';
    protected $description = 'عرض الأسئلة والمجموعات المعزولة (Quarantined) التي بلّغ عنها اللاعبون';

    public function handle(): int
    {
        $this->info("=== قائمة المحتوى المعزول للمراجعة (Quarantined Content) ===");

        // 1. أسئلة التحدي المعزولة
        $questions = Question::where('status', 'quarantined')->get();
        $this->newLine();
        $this->line("<comment>📌 أسئلة تحدي الشلة المعزولة (" . $questions->count() . "):</comment>");

        if ($questions->isEmpty()) {
            $this->info("لا توجد أسئلة معزولة حالياً. جميع الأسئلة نشطة وسليمة.");
        } else {
            $rows = [];
            foreach ($questions as $q) {
                $reports = ContentReport::where('content_type', 'trivia')->where('content_id', $q->id)->pluck('reason')->all();
                $reasonDisplay = $q->rejection_reason ?: (!empty($reports) ? implode(' | ', array_slice($reports, -2)) : 'عزل للمراجعة');
                $rows[] = [
                    $q->id,
                    $q->category?->name_ar ?? 'عام',
                    mb_substr($q->prompt_ar, 0, 45) . '..',
                    $q->reports_count,
                    $reasonDisplay,
                ];
            }
            $this->table(['ID', 'القسم', 'نص السؤال', 'عدد البلاغات', 'سبب العزل / البلاغ'], $rows);
        }

        // 2. مجموعات الجاسوس المعزولة
        $spyGroups = SpyWordGroup::where('status', 'quarantined')->get();
        $this->newLine();
        $this->line("<comment>🕵️ مجموعات مين الجاسوس المعزولة (" . $spyGroups->count() . "):</comment>");

        if ($spyGroups->isEmpty()) {
            $this->info("لا توجد مجموعات جاسوس معزولة.");
        } else {
            $rows = [];
            foreach ($spyGroups as $g) {
                $rows[] = [
                    $g->id,
                    $g->pack_slug,
                    $g->title_ar,
                    $g->reports_count,
                ];
            }
            $this->table(['ID', 'الحزمة', 'عنوان المجموعة', 'البلاغات'], $rows);
        }

        return 0;
    }
}
