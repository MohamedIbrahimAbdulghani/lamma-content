<?php
// Lamma - by Mohamed Ibrahim

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class CharadesCategory extends Model
{
    protected $fillable = ['slug', 'name_ar'];

    public function words(): HasMany
    {
        return $this->hasMany(CharadesWord::class, 'category_id');
    }
}
