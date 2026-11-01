<?php
// Lamma - by Mohamed Ibrahim

namespace App\Helpers;

class ArabicTextNormalizer
{
    /**
     * تطبيع النصوص العربية لمنع تكرار الكلمات والأسئلة بسبب التشكيل أو الهمزات أو المسافات
     */
    public static function normalize(string $text): string
    {
        // 1. إزالة التشكيل والتنوين والشدة والتطويل (الكشيدة)
        $text = preg_replace('/[\x{064B}-\x{0652}\x{0640}]/u', '', $text);

        // 2. توحيد الهمزات والألف
        $text = preg_replace('/[أإآٱ]/u', 'ا', $text);

        // 3. توحيد التاء المربوطة والهاء
        $text = preg_replace('/ة/u', 'ه', $text);

        // 4. توحيد الياء والألف المقصورة
        $text = preg_replace('/ى/u', 'ي', $text);

        // 5. إزالة علامات الترقيم والأقواس الشائعة
        $text = preg_replace('/[،؟!.":؛\(\)\[\]«»\-]/u', ' ', $text);

        // 6. تقليص المسافات المتعددة وإزالة الفراغات من البداية والنهاية
        $text = preg_replace('/\s+/u', ' ', $text);

        return mb_strtolower(trim($text), 'UTF-8');
    }

    /**
     * مقارنة نصين بعد التطبيع
     */
    public static function matches(string $a, string $b): bool
    {
        return self::normalize($a) === self::normalize($b);
    }
}

