<?php
// Lamma - by Mohamed Ibrahim

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SeenQuestion extends Model
{
    public $timestamps = false;

    protected $fillable = ['device_id', 'question_id', 'seen_at'];

    protected $casts = [
        'seen_at' => 'datetime',
    ];

    public function question(): BelongsTo
    {
        return $this->belongsTo(Question::class);
    }
}
