<?php
// Lamma - by Mohamed Ibrahim

namespace App\Http\Requests\Api;

use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\Exceptions\HttpResponseException;

class GetQuestionsRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        $this->merge([
            'x_device_id' => $this->header('X-Device-Id'),
        ]);
    }

    public function rules(): array
    {
        return [
            'x_device_id' => ['required', 'string', 'max:64'],
            'categories' => ['nullable', 'string'],
            'difficulty' => ['nullable', 'in:easy,medium,hard,mixed'],
            'count' => ['nullable', 'integer', 'min:1', 'max:50'],
        ];
    }

    public function messages(): array
    {
        return [
            'x_device_id.required' => 'X-Device-Id header is required',
            'difficulty.in' => 'Difficulty must be one of: easy, medium, hard, mixed',
            'count.integer' => 'Count must be an integer',
            'count.min' => 'Count must be at least 1',
            'count.max' => 'Count cannot exceed 50',
        ];
    }

    protected function failedValidation(Validator $validator)
    {
        throw new HttpResponseException(response()->json([
            'error' => 'Validation error',
            'messages' => $validator->errors(),
        ], 422));
    }
}
