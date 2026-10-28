<?php
// Lamma - by Mohamed Ibrahim

namespace Database\Seeders;

use App\Models\Avatar;
use Illuminate\Database\Seeder;

class AvatarSeeder extends Seeder
{
    public function run(): void
    {
        $avatars = [
            ['emoji' => '🦁', 'name_ar' => 'أسد', 'sort_order' => 1],
            ['emoji' => '🐯', 'name_ar' => 'نمر', 'sort_order' => 2],
            ['emoji' => '🦊', 'name_ar' => 'ثعلب', 'sort_order' => 3],
            ['emoji' => '🐺', 'name_ar' => 'ذئب', 'sort_order' => 4],
            ['emoji' => '🐻', 'name_ar' => 'دب', 'sort_order' => 5],
            ['emoji' => '🦝', 'name_ar' => 'راكون', 'sort_order' => 6],
            ['emoji' => '🐼', 'name_ar' => 'باندا', 'sort_order' => 7],
            ['emoji' => '🐸', 'name_ar' => 'ضفدع', 'sort_order' => 8],
            ['emoji' => '🦉', 'name_ar' => 'بومة', 'sort_order' => 9],
            ['emoji' => '🐬', 'name_ar' => 'دولفين', 'sort_order' => 10],
            ['emoji' => '🦈', 'name_ar' => 'قرش', 'sort_order' => 11],
            ['emoji' => '🦋', 'name_ar' => 'فراشة', 'sort_order' => 12],
            ['emoji' => '🐉', 'name_ar' => 'تنين', 'sort_order' => 13],
            ['emoji' => '🦄', 'name_ar' => 'يونيكورن', 'sort_order' => 14],
            ['emoji' => '🐢', 'name_ar' => 'سلحفاة', 'sort_order' => 15],
            ['emoji' => '🦅', 'name_ar' => 'نسر', 'sort_order' => 16],
            ['emoji' => '🐊', 'name_ar' => 'تمساح', 'sort_order' => 17],
            ['emoji' => '🦁', 'name_ar' => 'أسد', 'sort_order' => 18],
            ['emoji' => '🐧', 'name_ar' => 'بطريق', 'sort_order' => 19],
            ['emoji' => '🦜', 'name_ar' => 'ببغاء', 'sort_order' => 20],
            ['emoji' => '🐝', 'name_ar' => 'نحلة', 'sort_order' => 21],
            ['emoji' => '🦔', 'name_ar' => 'قنفذ', 'sort_order' => 22],
        ];

        foreach ($avatars as $avatar) {
            Avatar::firstOrCreate(['emoji' => $avatar['emoji'], 'name_ar' => $avatar['name_ar']], $avatar);
        }
    }
}
