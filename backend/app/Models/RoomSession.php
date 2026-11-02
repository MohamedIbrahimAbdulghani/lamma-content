<?php
// Lamma - by Mohamed Ibrahim

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class RoomSession extends Model
{
    protected $fillable = [
        'room_code',
        'host_device_id',
        'status',
        'current_game',
    ];

    public function devices(): HasMany
    {
        return $this->hasMany(RoomSessionDevice::class, 'room_session_id');
    }

    public function activeDeviceIds(): array
    {
        $ids = $this->devices()
            ->whereNull('left_at')
            ->pluck('device_id')
            ->all();

        if (!empty($this->host_device_id) && !in_array($this->host_device_id, $ids, true)) {
            $ids[] = $this->host_device_id;
        }

        return array_values(array_unique(array_filter($ids)));
    }
}
