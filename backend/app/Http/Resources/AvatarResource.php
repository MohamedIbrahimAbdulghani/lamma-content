<?php
// Lamma - by Mohamed Ibrahim

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class AvatarResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'emoji' => $this->emoji,
            'name_ar' => $this->name_ar,
            'sort_order' => $this->sort_order,
        ];
    }
}
