<?php
// Lamma - by Mohamed Ibrahim

namespace App\Console\Commands;

use App\Services\GenerateAiContentService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Http;

class AiCheckCommand extends Command
{
    protected $signature = 'ai:check {--model= : تجربة موديل محدد فقط} {--test-trivia : تجربة توليد أسئلة تريفيا حقيقية بصيغة JSON}';
    protected $description = 'فحص واختبار موديلات Gemini AI المتاحة لمفتاح الـ Backend واعتماد أفضلها';

    public function handle(GenerateAiContentService $aiService): int
    {
        $apiKey = config('services.gemini.key');
        $configuredModel = config('services.gemini.model');

        $this->info('=== فحص وتكامل Gemini AI (Lamma Party Game) ===');
        $this->newLine();

        if (empty($apiKey)) {
            $this->error('❌ مفتاح GEMINI_API_KEY غير معين في backend/.env أو غير محمل في config(services.gemini.key)');
            return 1;
        }

        $this->info('✅ مفتاح API محمل بنجاح من الإعدادات (بدون إظهار القيمة لحماية الخصوصية).');
        $this->line("الموديل المطلوب في الإعدادات (config/env): " . ($configuredModel ?: '(غير محدد)'));
        $this->line("الموديل الفعال المعتمد حالياً في الخدمة (Active Model): " . $aiService->getActiveModel());
        $this->newLine();

        $specificModel = $this->option('model');
        $candidates = $specificModel ? [$specificModel] : [
            'gemini-3.8-flash',
            'gemini-flash-latest',
            'gemini-flash-lite-latest',
            'gemini-3.5-flash-lite',
            'gemini-3.7-flash',
            'gemini-2.5-flash-lite',
            'gemini-2.5-flash',
        ];

        $results = [];
        $workingCandidates = [];

        foreach ($candidates as $model) {
            $this->output->write("جاري فحص الموديل [{$model}]... ");

            $url = "https://generativelanguage.googleapis.com/v1beta/models/{$model}:generateContent?key={$apiKey}";
            
            // طلب فحص أساسي
            $payload = [
                'contents' => [
                    [
                        'role' => 'user',
                        'parts' => [
                            ['text' => 'أجب بكلمة واحدة فقط: ما هي عاصمة جمهورية مصر العربية؟'],
                        ],
                    ],
                ],
                'generationConfig' => [
                    'temperature' => 0.5,
                    'maxOutputTokens' => 60,
                ],
            ];

            $start = microtime(true);
            try {
                $response = Http::timeout(12)->post($url, $payload);
                $elapsedMs = round((microtime(true) - $start) * 1000, 1);
                $status = $response->status();

                // إذا فشل بـ 400، نجرب بدون generationConfig بالكامل لتحديد السبب
                if ($status === 400) {
                    $minimalPayload = [
                        'contents' => $payload['contents'],
                    ];
                    $startRetry = microtime(true);
                    $retryResponse = Http::timeout(12)->post($url, $minimalPayload);
                    $retryElapsed = round((microtime(true) - $startRetry) * 1000, 1);
                    if ($retryResponse->successful()) {
                        $elapsedMs = $retryElapsed;
                        $response = $retryResponse;
                        $status = 200;
                        $this->line("\n<comment>  [ملاحظة: الموديل نجح عند إزالة generationConfig الاختياري (كان سبب 400)]</comment>");
                    }
                }

                if ($response->successful()) {
                    $replyText = trim($response->json('candidates.0.content.parts.0.text') ?? '');
                    $this->line("<info>OK</info> ({$elapsedMs}ms) - الرد: {$replyText}");
                    $results[] = [
                        'model' => $model,
                        'status' => 'OK',
                        'http_code' => $status,
                        'latency' => "{$elapsedMs} ms",
                        'details' => $replyText,
                    ];
                    $workingCandidates[] = [
                        'model' => $model,
                        'latency' => $elapsedMs,
                    ];
                } else {
                    $errMsg = $response->json('error.message') ?? $response->body();
                    $cleanErrMsg = preg_replace('/key=[^&\s]+/i', 'key=[HIDDEN]', $errMsg);
                    $this->line("<error>FAIL</error> ({$status}) - {$cleanErrMsg}");
                    $results[] = [
                        'model' => $model,
                        'status' => 'FAIL',
                        'http_code' => $status,
                        'latency' => "{$elapsedMs} ms",
                        'details' => $cleanErrMsg,
                    ];
                }
            } catch (\Throwable $e) {
                $elapsedMs = round((microtime(true) - $start) * 1000, 1);
                $cleanErrMsg = preg_replace('/key=[^&\s]+/i', 'key=[HIDDEN]', $e->getMessage());
                $this->line("<error>FAIL</error> (TIMEOUT/ERR) - {$cleanErrMsg}");
                $results[] = [
                    'model' => $model,
                    'status' => 'FAIL',
                    'http_code' => 'TIMEOUT/ERR',
                    'latency' => "{$elapsedMs} ms",
                    'details' => $cleanErrMsg,
                ];
            }
        }

        $this->newLine();
        $this->table(['الموديل', 'الحالة', 'HTTP Code', 'الزمن', 'التفاصيل / رسالة جوجل'], $results);

        $this->newLine();
        if (!empty($workingCandidates)) {
            // ترتيب الموديلات الناجحة حسب السرعة
            usort($workingCandidates, fn($a, $b) => $a['latency'] <=> $b['latency']);
            $fastest = $workingCandidates[0]['model'];
            $this->info("الموديل المعتمد الموصى به (الأسرع بين الناجحين): {$fastest} (بزمن {$workingCandidates[0]['latency']} ms)");

            if ($this->option('test-trivia')) {
                $this->newLine();
                $this->info("=== تجربة توليد أسئلة تريفيا حقيقية بصيغة JSON باستخدام {$fastest} ===");
                
                $prompt = "المطلوب توليد 3 أسئلة اختيار من متعدد بالعامية المصرية لتحدي الشلة. أجب بصيغة JSON فقط بهذا الهيكل: {\"items\": [{\"prompt_ar\": \"السؤال؟\", \"options\": [\"اختيار 1\", \"اختيار 2\", \"اختيار 3\", \"اختيار 4\"], \"correct_index\": 0, \"category_slug\": \"general\", \"difficulty\": \"medium\", \"explanation_ar\": \"توضيح للإجابة\"}]}";
                $url = "https://generativelanguage.googleapis.com/v1beta/models/{$fastest}:generateContent?key={$apiKey}";
                $payload = [
                    'contents' => [
                        [
                            'role' => 'user',
                            'parts' => [
                                ['text' => $prompt],
                            ],
                        ],
                    ],
                    'generationConfig' => [
                        'temperature' => 0.5,
                        'responseMimeType' => 'application/json',
                        'maxOutputTokens' => 1200,
                    ],
                ];

                $t0 = microtime(true);
                $resp = Http::timeout(25)->post($url, $payload);
                $genElapsed = round((microtime(true) - $t0) * 1000, 1);

                if ($resp->successful()) {
                    $jsonText = $resp->json('candidates.0.content.parts.0.text') ?? '';
                    $decoded = json_decode($jsonText, true);
                    $items = $decoded['items'] ?? $decoded;
                    $this->info("✅ تم التوليد بنجاح في {$genElapsed} ms! عدد الأسئلة: " . count($items));
                    $this->line(json_encode($items, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));
                } else {
                    $this->error("❌ فشل التوليد: " . $resp->body());
                }
            }
        } else {
            $this->error("تحذير: لم ينجح أي موديل من المرشحين.");
        }

        return 0;
    }
}
