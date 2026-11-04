<?php
// Lamma - by Mohamed Ibrahim

namespace App\Console\Commands;

use App\Models\Category;
use App\Models\CharadesWord;
use App\Models\Question;
use App\Models\SpyWordGroup;
use App\Services\ContentVerificationService;
use Illuminate\Console\Command;

class ContentVerifyCommand extends Command
{
    protected $signature = 'content:verify 
                            {--ai : تشغيل التحقق المزدوج المستقل (Blind + Reviewer) عبر الذكاء الاصطناعي}
                            {--limit= : تحديد حد أقصى للأسئلة المراد فحصها بـ AI لتوفير الكوتا}';

    protected $description = 'الفحص والتدقيق الشامل لمحتوى ألعاب لمّة وعزل (Quarantine) أي سؤال مشكوك فيه أو مخالف';

    public function handle(ContentVerificationService $verifier): int
    {
        $this->info("===============================================================");
        $this->info("   🔍 بدء الفحص والتدقيق الشامل لضمان صحة المحتوى وصارمة الأقسام   ");
        $this->info("===============================================================");
        $this->newLine();

        $runAi = (bool) $this->option('ai');
        $limit = $this->option('limit') ? (int) $this->option('limit') : null;

        $questions = Question::with('category')->get();
        $totalQuestions = $questions->count();
        $quarantinedCount = 0;
        $passedCount = 0;
        $quarantineDetails = [];

        $this->line("⏳ جارٍ فحص {$totalQuestions} سؤال في تحدي الشلة...");
        $aiChecked = 0;

        $bar = $this->output->createProgressBar($totalQuestions);
        $bar->start();

        foreach ($questions as $q) {
            $reason = null;
            $catSlug = $q->category?->slug ?? 'none';
            $p = $q->prompt_ar;
            $opts = (array) ($q->options ?? []);
            $cIdx = (int) ($q->correct_index ?? 0);

            // 1. فحص قسم 'nokat' (غير معتمد في اللعبة)
            if ($catSlug === 'nokat') {
                $reason = 'القسم غير معتمد في اللعبة (نكت)';
            }

            // 2. الفحص الآلي الحتمي
            if (!$reason) {
                $auto = $verifier->runAutomatedChecks($p, $opts, $cIdx);
                if (!$auto['passed']) {
                    $reason = 'فحص آلي قطعي: ' . $auto['reason'];
                }
            }

            // 3. فحص الهلوسات والأخطاء التاريخية المعروفة في الـ Seeders
            if (!$reason) {
                if (str_contains($p, 'الناظر') && str_contains($p, 'عادل إمام')) {
                    $reason = 'خطأ تاريخي صريح (عادل إمام ليس بطل فيلم الناظر)';
                } elseif (str_contains($p, 'فيلم') && str_contains($p, 'التسعينات') && str_contains($q->explanation_ar ?? '', '2000')) {
                    $reason = 'تناقض السؤال مع الشرح وسنة الإنتاج (الفيلم إنتاج 2000)';
                }
            }

            // 4. فحص تطابق القسم
            if (!$reason) {
                $canonicalCat = Category::canonicalSlug($catSlug);
                if (!in_array($canonicalCat, ['movies', 'sports', 'afeehat', 'history', 'general'], true)) {
                    $reason = "القسم ({$catSlug}) غير صالح أو غير معتمد";
                }
            }

            // 5. التحقق المزدوج المستقل عبر AI (إذا تم تفعيل الخيار أو كان السؤال نشطاً ولم يُستبعد)
            if (!$reason && $runAi && ($limit === null || $aiChecked < $limit)) {
                $aiChecked++;
                $verifyRes = $verifier->verifyTriviaQuestion(
                    prompt: $p,
                    options: $opts,
                    correctIndex: $cIdx,
                    categorySlug: $catSlug,
                    difficulty: $q->difficulty ?? 'medium'
                );

                if (!$verifyRes['approved']) {
                    $reason = 'رفض التدقيق المستقل: ' . ($verifyRes['reason'] ?? 'شك في صحة الإجابة أو انحراف القسم');
                }
            }

            if ($reason) {
                $q->update([
                    'status' => 'quarantined',
                    'is_active' => false,
                    'rejection_reason' => $reason,
                ]);
                $quarantinedCount++;
                $quarantineDetails[] = [
                    'id' => $q->id,
                    'category' => $q->category?->name_ar ?? $catSlug,
                    'prompt' => mb_substr($p, 0, 45) . '..',
                    'reason' => $reason,
                ];
            } else {
                $q->update([
                    'status' => 'active',
                    'is_active' => true,
                    'rejection_reason' => null,
                ]);
                $passedCount++;
            }

            $bar->advance();
        }

        $bar->finish();
        $this->newLine(2);

        // فحص حزم مين الجاسوس وتجانسها
        $this->line("⏳ جارٍ فحص مجموعات مين الجاسوس...");
        $spyGroups = SpyWordGroup::with('words')->get();
        $spyQuarantined = 0;
        foreach ($spyGroups as $g) {
            $pack = ($g->pack_slug === 'food') ? 'foods' : $g->pack_slug;
            if ($pack !== $g->pack_slug) {
                $g->update(['pack_slug' => $pack]);
            }
            if ($g->words->count() < 4) {
                $g->update(['status' => 'quarantined']);
                $spyQuarantined++;
            }
        }

        // فحص كلمات مثّل ومتتكلمش
        $this->line("⏳ جارٍ فحص وتوحيد أقسام كلمات مثّل ومتتكلمش...");
        $charadesWords = CharadesWord::with('category')->get();
        $charadesFixed = 0;
        foreach ($charadesWords as $w) {
            if ($w->category) {
                $canonical = Category::canonicalSlug($w->category->slug);
                if ($canonical !== $w->category->slug) {
                    $w->category->update(['slug' => $canonical]);
                    $charadesFixed++;
                }
            }
        }

        // عرض تقرير النتائج
        $this->info("📊 تقرير نتائج الفحص والعزل الشامل (Content Verification Report):");
        $this->table(
            ['المقياس', 'العدد', 'النسبة المئوية'],
            [
                ['إجمالي الأسئلة المفحوصة', $totalQuestions, '100%'],
                ['الأسئلة السليمة المعتمدة (Active)', $passedCount, round(($passedCount / max(1, $totalQuestions)) * 100, 1) . '%'],
                ['الأسئلة المعزولة المشكوك فيها (Quarantined)', $quarantinedCount, round(($quarantinedCount / max(1, $totalQuestions)) * 100, 1) . '%'],
                ['مجموعات الجاسوس المعزولة لنقص الكلمات', $spyQuarantined, '-'],
            ]
        );

        if (!empty($quarantineDetails)) {
            $this->newLine();
            $this->comment("🚫 عينة من الأسئلة المعزولة وأسباب عزلها المحددة:");
            $sampleRows = array_slice($quarantineDetails, 0, 15);
            $this->table(['ID', 'القسم', 'نص السؤال', 'سبب العزل'], $sampleRows);
        }

        $this->newLine();
        $this->info("✅ اكتمل الفحص بنجاح. الأسئلة المعزولة لن تُقدَّم للاعبين في أي جلسة أو مخزون.");
        return Command::SUCCESS;
    }
}
