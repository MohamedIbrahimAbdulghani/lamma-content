<?php
// Lamma - by Mohamed Ibrahim

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class AiContentResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $rawCat = $this->resource['category_slug'] ?? ($this->resource['category'] ?? null);
        $canonicalCat = $rawCat ? \App\Models\Category::canonicalSlug((string) $rawCat) : null;

        return [
            'type' => $this->resource['type'] ?? 'item',
            'prompt_ar' => $this->resource['prompt_ar'] ?? null,
            'word_ar' => $this->resource['word_ar'] ?? null,
            'category' => $canonicalCat,
            'category_slug' => $canonicalCat,
            'options' => $this->resource['options'] ?? [],
            'correct_index' => $this->resource['correct_index'] ?? 0,
            'difficulty' => $this->resource['difficulty'] ?? 'medium',
            'explanation_ar' => $this->resource['explanation_ar'] ?? null,
        ];
    }
}

