<?php
// Lamma - by Mohamed Ibrahim

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SpyGroupWord extends Model
{
    protected $fillable = [
        'group_id',
        'word_ar',
        'normalized_word',
        'content_hash',
    ];

    public function group(): BelongsTo
    {
        return $this->belongsTo(SpyWordGroup::class, 'group_id');
    }
}
