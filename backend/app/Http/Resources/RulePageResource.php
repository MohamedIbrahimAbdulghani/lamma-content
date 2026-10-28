<?php
// Lamma - by Mohamed Ibrahim

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class RulePageResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'slug' => $this->slug,
            'title_ar' => $this->title_ar,
            'accent' => $this->accent,
            'sections' => $this->sections,
        ];
    }
}
