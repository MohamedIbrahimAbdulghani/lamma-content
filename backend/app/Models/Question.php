<?php
// Lamma - by Mohamed Ibrahim

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Question extends Model
{
    protected $fillable = [
        'category_id', 'type', 'prompt_ar', 'emoji_prompt',
        'options', 'correct_index', 'difficulty', 'explanation_ar',
        'source', 'content_hash', 'is_active', 'published_at',
    ];

    protected $casts = [
        'options' => 'array',
        'correct_index' => 'integer',
        'is_active' => 'boolean',
        'published_at' => 'datetime',
    ];

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function seenByDevices(): HasMany
    {
        return $this->hasMany(SeenQuestion::class);
    }

    public static function makeContentHash(string $promptAr): string
    {
        return sha1(mb_strtolower(trim($promptAr)));
    }
}
