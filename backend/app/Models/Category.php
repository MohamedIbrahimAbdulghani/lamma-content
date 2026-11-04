<?php
// Lamma - by Mohamed Ibrahim

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Category extends Model
{
    protected $fillable = ['slug', 'name_ar', 'emoji', 'kind', 'is_active', 'sort_order'];

    protected $casts = [
        'is_active' => 'boolean',
        'sort_order' => 'integer',
    ];

    public function questions(): HasMany
    {
        return $this->hasMany(Question::class);
    }

    /**
     * تحويل أي معرّف أو اسم قديم إلى المعرّف القياسي المعتمد
     */
    public static function canonicalSlug(string $slug): string
    {
        $normalized = trim(strtolower($slug));
        $map = [
            'guess_movie' => 'movies',
            'movie' => 'movies',
            'films' => 'movies',
            'film' => 'movies',
            'أفلام' => 'movies',
            'مسلسلات' => 'movies',
            'أفلام ومسلسلات' => 'movies',
            'kora' => 'sports',
            'sport' => 'sports',
            'football' => 'sports',
            'كورة' => 'sports',
            'كورة مصرية' => 'sports',
            'كرة القدم' => 'sports',
            'كرة قدم' => 'sports',
            'رياضة' => 'sports',
            'رياضة وكرة قدم' => 'sports',
            'afihat' => 'afeehat',
            'efihat' => 'afeehat',
            'أفيهات' => 'afeehat',
            'إفيهات' => 'afeehat',
            'إفيهات وقفشات' => 'afeehat',
            'تاريخ' => 'history',
            'جغرافيا' => 'history',
            'تاريخ وجغرافيا' => 'history',
            'عام' => 'general',
            'عامة' => 'general',
            'معلومات عامة' => 'general',
        ];

        return $map[$normalized] ?? $normalized;
    }

    /**
     * توسيع قائمة المعرّفات لتشمل المعرّف القياسي وأي أسماء بديلة للتوافق التام
     */
    public static function resolveSlugs(array $slugs): array
    {
        $resolved = [];
        foreach ($slugs as $s) {
            $canonical = self::canonicalSlug((string) $s);
            $resolved[] = $canonical;
            if ($canonical === 'movies') {
                $resolved[] = 'guess_movie';
            } elseif ($canonical === 'sports') {
                $resolved[] = 'kora';
            }
        }

        return array_values(array_unique(array_filter($resolved)));
    }
}
