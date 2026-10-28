<?php
// Lamma - by Mohamed Ibrahim

namespace Database\Seeders;

use App\Models\AppSetting;
use App\Models\ContentVersion;
use Illuminate\Database\Seeder;

class AppSettingSeeder extends Seeder
{
    public function run(): void
    {
        $defaults = [
            'spy' => [
                'rounds' => 3,
                'rounds_min' => 1,
                'rounds_max' => 10,
                'discussion_minutes' => 5,
                'discussion_minutes_min' => 1,
                'discussion_minutes_max' => 10,
                'voting_seconds' => 30,
                'voting_seconds_min' => 15,
                'voting_seconds_max' => 60,
                'last_guess_seconds' => 15,
                'last_guess_seconds_min' => 10,
                'last_guess_seconds_max' => 30,
                'spies' => 'auto',
                'spies_options' => ['auto', 1, 2],
                'auto_spy_rule' => '1 spy for <7 players, 2 for 7+',
                'word_pack' => 'places',
            ],
            'trivia' => [
                'questions' => 10,
                'questions_min' => 5,
                'questions_max' => 30,
                'seconds_per_question' => 15,
                'seconds_per_question_min' => 10,
                'seconds_per_question_max' => 30,
                'difficulty' => 'medium',
                'difficulty_options' => ['easy', 'medium', 'hard', 'mixed'],
                'categories' => ['afeehat', 'kora', 'nokat', 'general', 'guess_movie'],
            ],
            'charades' => [
                'turn_seconds' => 60,
                'turn_seconds_min' => 30,
                'turn_seconds_max' => 120,
                'turns_per_player' => 2,
                'turns_per_player_min' => 1,
                'turns_per_player_max' => 5,
                'category' => 'movies',
            ],
            'scoring' => [
                'spy_not_caught' => 3,
                'spy_caught_guessed_right' => 2,
                'citizens_caught_spy_guessed_wrong' => 2,
                'trivia_correct' => 100,
                'trivia_speed_bonus_max' => 100,
                'trivia_wrong' => 0,
                'charades_correct' => 1,
                'charades_pass' => 0,
            ],
            'anti_cheat' => [
                'max_violations' => 3,
                'grace_seconds' => 2,
            ],
            'ui' => [
                'flash_ms' => 800,
            ],
            'max_players' => 10,
            'min_players' => 3,
        ];

        foreach ($defaults as $key => $value) {
            AppSetting::updateOrCreate(['key' => $key], ['value' => $value]);
        }

        // Initial content version
        if (!ContentVersion::current()) {
            ContentVersion::create([
                'version' => 1,
                'generated_at' => now(),
                'notes' => 'Initial seed',
            ]);
        }
    }
}
