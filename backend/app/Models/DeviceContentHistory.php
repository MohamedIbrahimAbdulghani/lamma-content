<?php
// Lamma - by Mohamed Ibrahim

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DeviceContentHistory extends Model
{
    public $timestamps = false;
    protected $table = 'device_content_history';

    protected $fillable = [
        'device_id',
        'content_type',
        'content_id',
        'seen_at',
    ];

    protected $casts = [
        'seen_at' => 'datetime',
        'content_id' => 'integer',
    ];

    public static function markSeen(array $deviceIds, string $contentType, int $contentId): void
    {
        $now = now();
        $records = [];
        foreach (array_unique($deviceIds) as $deviceId) {
            if (!empty($deviceId)) {
                $records[] = [
                    'device_id' => $deviceId,
                    'content_type' => $contentType,
                    'content_id' => $contentId,
                    'seen_at' => $now,
                ];
            }
        }
        if (!empty($records)) {
            static::upsert(
                $records,
                ['device_id', 'content_type', 'content_id'],
                ['seen_at']
            );
        }
    }
}
