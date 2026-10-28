<?php
// Lamma - by Mohamed Ibrahim

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ContentVersion extends Model
{
    public $timestamps = false;

    protected $fillable = ['version', 'generated_at', 'notes'];

    protected $casts = [
        'version' => 'integer',
        'generated_at' => 'datetime',
    ];

    public static function current(): ?self
    {
        return static::orderBy('version', 'desc')->first();
    }

    public static function bump(string $notes = ''): self
    {
        $current = static::current();
        $nextVersion = ($current?->version ?? 0) + 1;

        return static::create([
            'version' => $nextVersion,
            'generated_at' => now(),
            'notes' => $notes,
        ]);
    }
}
