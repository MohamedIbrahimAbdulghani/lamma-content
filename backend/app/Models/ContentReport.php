<?php
// Lamma - by Mohamed Ibrahim

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ContentReport extends Model
{
    public const UPDATED_AT = null;

    protected $fillable = [
        'device_id',
        'content_type',
        'content_id',
        'reason',
        'created_at',
    ];

    protected $casts = [
        'created_at' => 'datetime',
        'content_id' => 'integer',
    ];
}
