<?php
// Lamma - by Mohamed Ibrahim

namespace App\Console\Commands;

use App\Helpers\ArabicNormalizer;
use App\Models\Category;
use App\Models\CharadesWord;
use App\Models\Question;
use App\Models\SpyGroupWord;
use App\Models\SpyWordGroup;
use Illuminate\Console\Command;

class ContentAuditCommand extends Command
{
    protected $signature = 'content:audit {--fix : عزل وتجميد العناصر المكررة والمتشابهة تلقائياً}';
    protected $description = 'فحص شامل لمحتوى الألعاب الثلاث لاكتشاف وعزل المكرر والمتشابه';

    public function handle(): int
    {
        $autoFix = (bool) $this->option('fix');
        $this->info('🔍 بدء الفحص والتدقيق الشامل لمحتوى ألعاب لمّة...');
        $this->newLine();

        $triviaStats = $this->auditTrivia($autoFix);
        $spyStats = $this->auditSpy($autoFix);
        $charadesStats = $this->auditCharades($autoFix);

        $this->newLine();
        $this->info('📊 ملخص نتائج التدقيق الشامل:');
        $this->table(
            ['اللعبة', 'إجمالي العناصر', 'العناصر النشطة', 'المكرر بالنص', 'المتشابه بنسبة عالية', 'المعزول (Quarantined)'],
            [
                [
                    'تحدي الشلة (أسئلة)',
                    $triviaStats['total'],
                    $triviaStats['active'],
                    $triviaStats['exact_duplicates'],
                    $triviaStats['similar'],
                    $triviaStats['quarantined'],
                ],
                [
                    'مين الجاسوس (مجموعات)',
                    $spyStats['total'],
                    $spyStats['active'],
                    $spyStats['exact_duplicates'],
                    $spyStats['similar'],
                    $spyStats['quarantined'],
                ],
                [
                    'مثّل ومتتكلمش (كلمات)',
                    $charadesStats['total'],
                    $charadesStats['active'],
                    $charadesStats['exact_duplicates'],
                    $charadesStats['similar'],
                    $charadesStats['quarantined'],
                ],
            ]
        );

        if ($autoFix) {
            $this->info('✅ تم عزل وتجميد جميع العناصر المكررة بنجاح.');
        } else {
            $this->comment('💡 لتنفيذ العزل التلقائي للعناصر المكررة والمتشابهة، شغل الأمر مع: --fix');
        }

        return Command::SUCCESS;
    }

    private function auditTrivia(bool $autoFix): array
    {
        $questions = Question::all();
        $total = $questions->count();
        $active = 0;
        $quarantined = 0;
        $exactDuplicates = 0;
        $similar = 0;

        $seenPrompts = [];
        $seenAnswers = [];
        $toQuarantine = [];

        foreach ($questions as $q) {
            if ($q->status === 'quarantined' || !$q->is_active) {
                $quarantined++;
                continue;
            }

            // تضمين الإيموجي في فحص التطابق لأسئلة الإيموجي لمنع التضارب الزائف
            $combinedPrompt = trim($q->prompt_ar . ' ' . ($q->emoji_prompt ?? ''));
            $normPrompt = ArabicNormalizer::normalize($combinedPrompt);
            $correctOption = $q->options[$q->correct_index] ?? '';
            $normAnswer = $q->category_id . '::' . ArabicNormalizer::normalize($correctOption);

            if (isset($seenPrompts[$normPrompt])) {
                $exactDuplicates++;
                $toQuarantine[] = [
                    'id' => $q->id,
                    'reason' => "تطابق تام مع السؤال رقم {$seenPrompts[$normPrompt]}",
                ];
            } else {
                $seenPrompts[$normPrompt] = $q->id;

                // فحص تشابه الإجابة مع أسئلة سابقة غير البوليان
                if (!in_array($correctOption, ['صح', 'غلط', 'نعم', 'لا'], true) && isset($seenAnswers[$normAnswer])) {
                    // إذا نفس الإجابة بنفس القسم ونفس السؤال بصياغة أخرى
                    $prevId = $seenAnswers[$normAnswer];
                    $prevQ = $questions->firstWhere('id', $prevId);
                    if ($prevQ && ArabicNormalizer::jaccardSimilarity($q->prompt_ar, $prevQ->prompt_ar) >= 0.50) {
                        $similar++;
                        $toQuarantine[] = [
                            'id' => $q->id,
                            'reason' => "سؤال مكرر لنفس الإجابة ({$correctOption}) بنسبة تشابه عالية مع {$prevId}",
                        ];
                    }
                } else {
                    $seenAnswers[$normAnswer] = $q->id;
                }
            }
        }

        // فحص التشابه العالي بين الأسئلة النشطة (Jaccard >= 0.75)
        $activeQuestions = $questions->whereNotIn('id', array_column($toQuarantine, 'id'))
            ->where('status', 'active')
            ->values();

        for ($i = 0; $i < $activeQuestions->count(); $i++) {
            for ($j = $i + 1; $j < $activeQuestions->count(); $j++) {
                $qA = $activeQuestions[$i];
                $qB = $activeQuestions[$j];

                // تخطي لو كانت أسئلة إيموجي بإيموجي مختلف
                if (!empty($qA->emoji_prompt) && !empty($qB->emoji_prompt) && $qA->emoji_prompt !== $qB->emoji_prompt) {
                    continue;
                }

                $sim = ArabicNormalizer::jaccardSimilarity($qA->prompt_ar, $qB->prompt_ar);
                if ($sim >= 0.75) {
                    $similar++;
                    $toQuarantine[] = [
                        'id' => $qB->id,
                        'reason' => "تشابه صياغة عالي (" . round($sim * 100) . "%) مع السؤال {$qA->id}",
                    ];
                }
            }
        }

        if ($autoFix && !empty($toQuarantine)) {
            foreach ($toQuarantine as $item) {
                Question::where('id', $item['id'])->update([
                    'status' => 'quarantined',
                    'is_active' => false,
                    'rejection_reason' => $item['reason'],
                ]);
                $quarantined++;
            }
        }

        $active = $total - $quarantined;

        return [
            'total' => $total,
            'active' => $active,
            'quarantined' => $quarantined,
            'exact_duplicates' => $exactDuplicates,
            'similar' => $similar,
        ];
    }

    private function auditSpy(bool $autoFix): array
    {
        $groups = SpyWordGroup::with('words')->get();
        $total = $groups->count();
        $quarantined = 0;
        $exactDuplicates = 0;
        $similar = 0;

        $seenTitles = [];
        $seenWordSets = [];
        $toQuarantine = [];

        foreach ($groups as $g) {
            if ($g->status === 'quarantined') {
                $quarantined++;
                continue;
            }

            $normTitle = ArabicNormalizer::normalize($g->title_ar);
            $wordList = $g->words->pluck('word_ar')->map(fn($w) => ArabicNormalizer::normalize($w))->sort()->values()->all();
            $wordSetKey = implode(',', $wordList);

            if (isset($seenTitles[$normTitle])) {
                $exactDuplicates++;
                $toQuarantine[] = [
                    'id' => $g->id,
                    'reason' => "مجموعة مكررة بالاسم مع المجموعة {$seenTitles[$normTitle]}",
                ];
            } elseif (isset($seenWordSets[$wordSetKey])) {
                $similar++;
                $toQuarantine[] = [
                    'id' => $g->id,
                    'reason' => "مجموعة بنفس كلمات المجموعة {$seenWordSets[$wordSetKey]}",
                ];
            } else {
                $seenTitles[$normTitle] = $g->id;
                $seenWordSets[$wordSetKey] = $g->id;
            }
        }

        if ($autoFix && !empty($toQuarantine)) {
            foreach ($toQuarantine as $item) {
                SpyWordGroup::where('id', $item['id'])->update([
                    'status' => 'quarantined',
                ]);
                $quarantined++;
            }
        }

        $active = $total - $quarantined;

        return [
            'total' => $total,
            'active' => $active,
            'quarantined' => $quarantined,
            'exact_duplicates' => $exactDuplicates,
            'similar' => $similar,
        ];
    }

    private function auditCharades(bool $autoFix): array
    {
        $words = CharadesWord::all();
        $total = $words->count();
        $quarantined = 0;
        $exactDuplicates = 0;
        $similar = 0;

        $seenWords = [];
        $toQuarantine = [];

        foreach ($words as $w) {
            if ($w->status === 'quarantined' || !$w->is_active) {
                $quarantined++;
                continue;
            }

            $norm = ArabicNormalizer::normalize($w->word_ar);
            if (isset($seenWords[$norm])) {
                $exactDuplicates++;
                $toQuarantine[] = [
                    'id' => $w->id,
                    'reason' => "كلمة مكررة تماماً مع المعرف {$seenWords[$norm]}",
                ];
            } else {
                $seenWords[$norm] = $w->id;
            }
        }

        if ($autoFix && !empty($toQuarantine)) {
            foreach ($toQuarantine as $item) {
                CharadesWord::where('id', $item['id'])->update([
                    'status' => 'quarantined',
                    'is_active' => false,
                ]);
                $quarantined++;
            }
        }

        $active = $total - $quarantined;

        return [
            'total' => $total,
            'active' => $active,
            'quarantined' => $quarantined,
            'exact_duplicates' => $exactDuplicates,
            'similar' => $similar,
        ];
    }
}
