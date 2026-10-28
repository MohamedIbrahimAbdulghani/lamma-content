<?php
// Lamma - by Mohamed Ibrahim

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class RulePage extends Model
{
    protected $fillable = ['slug', 'title_ar', 'accent', 'sections'];

    protected $casts = [
        'sections' => 'array',
    ];
}
