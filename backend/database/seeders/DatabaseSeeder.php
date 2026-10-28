<?php
// Lamma - by Mohamed Ibrahim

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $this->call([
            AvatarSeeder::class,
            SpyWordSeeder::class,
            CharadesWordSeeder::class,
            QuestionSeeder::class,
            AppSettingSeeder::class,
            RulePageSeeder::class,
        ]);
    }
}
