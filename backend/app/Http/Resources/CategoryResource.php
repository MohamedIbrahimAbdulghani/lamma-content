<?php
// Lamma - by Mohamed Ibrahim

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CategoryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'slug' => $this->slug,
            'name_ar' => $this->name_ar,
            'emoji' => $this->emoji,
            'kind' => $this->kind,
            'is_active' => $this->is_active,
            'sort_order' => $this->sort_order,
        ];
    }
}
