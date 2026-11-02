<?php
// Lamma - by Mohamed Ibrahim

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Question extends Model
{
    protected $fillable = [
        'category_id', 'type', 'prompt_ar', 'normalized_prompt', 'emoji_prompt',
        'options', 'correct_index', 'difficulty', 'explanation_ar',
        'source', 'content_hash', 'prompt_hash', 'answer_hash', 'distractors_hash',
        'status', 'rejection_reason', 'times_served', 'reports_count',
        'is_active', 'published_at',
    ];

    protected $casts = [
        'options' => 'array',
        'correct_index' => 'integer',
        'is_active' => 'boolean',
        'published_at' => 'datetime',
        'times_served' => 'integer',
        'reports_count' => 'integer',
    ];

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function seenByDevices(): HasMany
    {
        return $this->hasMany(SeenQuestion::class);
    }

    public function scopeActive($query)
    {
        return $query->where('status', 'active')->where('is_active', true);
    }

    public static function makeContentHash(string $promptAr): string
    {
        return sha1(mb_strtolower(trim($promptAr)));
    }
}
