<?php
// Lamma - by Mohamed Ibrahim

namespace App\Console\Commands;

use App\Helpers\ArabicNormalizer;
use App\Models\Question;
use Illuminate\Console\Command;

class NormalizeContentCommand extends Command
{
    protected $signature = 'content:normalize';
    protected $description = 'Normalize prompts and calculate hashes for all questions in database';

    public function handle(): int
    {
        $this->info('Normalizing and indexing questions...');
        $questions = Question::with('category')->get();
        $count = 0;

        foreach ($questions as $q) {
            $norm = ArabicNormalizer::normalize($q->prompt_ar);
            $pHash = ArabicNormalizer::promptHash($q->prompt_ar);
            $correctOpt = $q->options[$q->correct_index] ?? '';
            $catSlug = $q->category?->slug ?? 'general';
            $aHash = ArabicNormalizer::answerHash($catSlug, $correctOpt);

            $distractors = $q->options;
            unset($distractors[$q->correct_index]);
            sort($distractors);
            $dHash = hash('sha256', implode('|', array_map([ArabicNormalizer::class, 'normalize'], $distractors)));

            $q->update([
                'normalized_prompt' => $norm,
                'prompt_hash' => $pHash,
                'answer_hash' => $aHash,
                'distractors_hash' => $dHash,
                'status' => $q->status ?? 'active',
            ]);
            $count++;
        }

        $this->info("Successfully indexed {$count} questions.");
        return 0;
    }
}
