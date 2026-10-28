<?php
// Lamma - by Mohamed Ibrahim

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Avatar extends Model
{
    protected $fillable = ['emoji', 'name_ar', 'sort_order'];

    protected $casts = [
        'sort_order' => 'integer',
    ];
}
