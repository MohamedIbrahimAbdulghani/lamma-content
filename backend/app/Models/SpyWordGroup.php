<?php
// Lamma - by Mohamed Ibrahim

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SpyWordGroup extends Model
{
    protected $fillable = [
        'pack_slug',
        'title_ar',
        'theme',
        'difficulty',
        'status',
        'content_hash',
        'times_served',
        'reports_count',
        'source',
    ];

    protected $casts = [
        'times_served' => 'integer',
        'reports_count' => 'integer',
    ];

    public function words(): HasMany
    {
        return $this->hasMany(SpyGroupWord::class, 'group_id');
    }

    public function scopeActive($query)
    {
        return $query->where('status', 'active');
    }

    public static function makeContentHash(string $titleAr, array $words): string
    {
        sort($words);
        return hash('sha256', mb_strtolower(trim($titleAr)) . '::' . implode(',', $words));
    }
}
