<?php
// Lamma - by Mohamed Ibrahim

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CharadesWord extends Model
{
    protected $fillable = ['category_id', 'word_ar', 'content_hash', 'is_active', 'source'];

    protected $casts = [
        'is_active' => 'boolean',
    ];

    public function category(): BelongsTo
    {
        return $this->belongsTo(CharadesCategory::class, 'category_id');
    }

    public static function makeContentHash(string $word): string
    {
        return sha1(mb_strtolower(trim($word)));
    }
}
