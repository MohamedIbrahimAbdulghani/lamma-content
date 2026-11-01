<?php
// Lamma - by Mohamed Ibrahim

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class GenerateContentApiRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'game_type' => ['required', 'string', 'in:spy,trivia,charades'],
            'category' => ['nullable', 'string', 'max:50'],
            'categories' => ['nullable', 'array'],
            'categories.*' => ['string'],
            'difficulty' => ['nullable', 'string', 'in:all,easy,medium,hard'],
            'count' => ['nullable', 'integer', 'min:1', 'max:50'],
            'exclude_items' => ['nullable', 'array'],
            'exclude_items.*' => ['string'],
        ];
    }

    public function messages(): array
    {
        return [
            'game_type.required' => 'نوع اللعبة مطلوب (spy, trivia, charades).',
            'game_type.in' => 'نوع اللعبة غير صالح.',
            'count.integer' => 'العدد يجب أن يكون رقماً صحيحاً.',
        ];
    }
}

