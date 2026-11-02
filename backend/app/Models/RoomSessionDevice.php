<?php
// Lamma - by Mohamed Ibrahim

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RoomSessionDevice extends Model
{
    public $timestamps = false;

    protected $fillable = [
        'room_session_id',
        'device_id',
        'joined_at',
        'left_at',
    ];

    protected $casts = [
        'joined_at' => 'datetime',
        'left_at' => 'datetime',
    ];

    public function roomSession(): BelongsTo
    {
        return $this->belongsTo(RoomSession::class, 'room_session_id');
    }
}
