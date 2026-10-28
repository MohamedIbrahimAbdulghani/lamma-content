<?php
// Lamma - by Mohamed Ibrahim

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class QuestionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'category_id' => $this->category_id,
            'category_slug' => $this->category?->slug,
            'type' => $this->type,
            'prompt_ar' => $this->prompt_ar,
            'emoji_prompt' => $this->emoji_prompt,
            'options' => $this->options,
            'correct_index' => $this->correct_index,
            'difficulty' => $this->difficulty,
            'explanation_ar' => $this->explanation_ar,
            'source' => $this->source,
        ];
    }
}
