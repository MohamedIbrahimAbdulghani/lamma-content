<?php
// Lamma - by Mohamed Ibrahim

namespace App\Helpers;

class ArabicNormalizer
{
    public static function normalize(string $text): string
    {
        // 1. Remove tashkeel (diacritics)
        $tashkeel = [
            '/\x{064B}/u', // Tanwin Fath
            '/\x{064C}/u', // Tanwin Damm
            '/\x{064D}/u', // Tanwin Kasr
            '/\x{064E}/u', // Fatha
            '/\x{064F}/u', // Damma
            '/\x{0650}/u', // Kasra
            '/\x{0651}/u', // Shadda
            '/\x{0652}/u', // Sukun
            '/\x{0670}/u', // Dagger Alif
        ];
        $text = preg_replace($tashkeel, '', $text);

        // 2. Remove Tatweel (Kashida)
        $text = preg_replace('/\x{0640}/u', '', $text);

        // 3. Normalize Alef variants to bare Alef
        $text = preg_replace('/[إأآٱ]/u', 'ا', $text);

        // 4. Normalize Taa Marbouta to Haa
        $text = preg_replace('/ة/u', 'ه', $text);

        // 5. Normalize Alef Maqsura to Yaa
        $text = preg_replace('/ى/u', 'ي', $text);

        // 6. Remove punctuation & symbols
        $text = preg_replace('/[؟\?!\.,،:;\"\'\(\)\[\]\{\}\-_]/u', ' ', $text);

        // 7. Collapse whitespace and lowercase
        $text = mb_strtolower(trim(preg_replace('/\s+/u', ' ', $text)));

        return $text;
    }

    public static function promptHash(string $prompt): string
    {
        return hash('sha256', self::normalize($prompt));
    }

    public static function answerHash(string $categorySlug, string $answer): string
    {
        return hash('sha256', mb_strtolower(trim($categorySlug)) . '::' . self::normalize($answer));
    }

    public static function saltedAnswerHash(int $questionId, string $answer, string $salt = 'LammaSecretSalt2025'): string
    {
        return hash('sha256', $questionId . '::' . self::normalize($answer) . '::' . $salt);
    }

    public static function jaccardSimilarity(string $textA, string $textB): float
    {
        $normA = self::normalize($textA);
        $normB = self::normalize($textB);

        $wordsA = array_filter(explode(' ', $normA));
        $wordsB = array_filter(explode(' ', $normB));

        if (empty($wordsA) || empty($wordsB)) {
            return 0.0;
        }

        $setA = array_unique($wordsA);
        $setB = array_unique($wordsB);

        $intersection = array_intersect($setA, $setB);
        $union = array_unique(array_merge($setA, $setB));

        return count($union) === 0 ? 0.0 : (count($intersection) / count($union));
    }
}
