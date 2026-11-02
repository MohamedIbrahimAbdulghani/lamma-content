<?php
// Lamma - by Mohamed Ibrahim

namespace App\Console\Commands;

use App\Services\AutonomousContentService;
use Illuminate\Console\Command;

class TestAutonomousCommand extends Command
{
    protected $signature = 'ai:test-autonomous {--type=trivia} {--category=general} {--count=4}';
    protected $description = 'تشغيل تجربة حية لنظام التوليد الذاتي والفلترة الثنائية بالذكاء الاصطناعي';

    public function handle(AutonomousContentService $service): int
    {
        $type = (string) $this->option('type');
        $cat = (string) $this->option('category');
        $count = (int) $this->option('count');

        $this->info("=== بدء فحص التوليد الذاتي والفلترة الثنائية [{$type}] ===");
        $startTime = microtime(true);

        if ($type === 'trivia') {
            $this->info("جاري طلب {$count} أسئلة في قسم [{$cat}] مع الفلترة والتحقق بالـ AI..");
            $result = $service->generateTriviaQuestions($cat, 'medium', $count);
            $elapsed = round((microtime(true) - $startTime) * 1000, 1);

            $this->info("الزمن الكلي: {$elapsed} ms");
            $this->line("تم توليد: {$result['generated']} | المعتمد: {$result['approved']} | المرفوض: {$result['rejected']}");
            if (!empty($result['reasons'])) {
                $this->warn("أسباب الرفض المسجلة: " . implode(' | ', $result['reasons']));
            }
        } elseif ($type === 'spy') {
            $this->info("جاري توليد مجموعة كلمات متجانسة بدقة لحزمة [places]..");
            $result = $service->generateSpyWordGroup('places', 'medium');
            $elapsed = round((microtime(true) - $startTime) * 1000, 1);

            $this->info("الزمن الكلي: {$elapsed} ms");
            $this->info("النتيجة: " . json_encode($result, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));
        }

        return 0;
    }
}
