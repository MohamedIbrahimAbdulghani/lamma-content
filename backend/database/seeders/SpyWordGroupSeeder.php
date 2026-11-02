<?php
// Lamma - by Mohamed Ibrahim

namespace Database\Seeders;

use App\Models\SpyGroupWord;
use App\Models\SpyWordGroup;
use Illuminate\Database\Seeder;

class SpyWordGroupSeeder extends Seeder
{
    public function run(): void
    {
        $groups = [
            [
                'pack_slug' => 'places',
                'title_ar' => 'مدن ومصايف ساحلية مصرية',
                'theme' => 'سياحة ومصايف',
                'difficulty' => 'easy',
                'words' => [
                    'شرم الشيخ', 'الغردقة', 'الإسكندرية', 'مرسى مطروح',
                    'دهب', 'بورسعيد', 'رأس البر', 'الجونة', 'طابا', 'العلمين الجديدة',
                ],
            ],
            [
                'pack_slug' => 'places',
                'title_ar' => 'غرف ومرافق المنزل',
                'theme' => 'البيت المصري',
                'difficulty' => 'easy',
                'words' => [
                    'المطبخ', 'الحمام', 'غرفة النوم', 'الصالون',
                    'البلكونة', 'غرفة السفرة', 'الرووف', 'الطرقة', 'غرفة الأطفال',
                ],
            ],
            [
                'pack_slug' => 'places',
                'title_ar' => 'معالم تاريخية وأثرية بالقاهرة',
                'theme' => 'تاريخ وتراث',
                'difficulty' => 'medium',
                'words' => [
                    'الأهرامات', 'برج القاهرة', 'قلعة صلاح الدين', 'شارع المعز',
                    'خان الخليلي', 'قصر البارون', 'حديقة الأزهر', 'المتحف المصري الكبير',
                    'ساقية الصاوي', 'مجمع الأديان',
                ],
            ],
            [
                'pack_slug' => 'places',
                'title_ar' => 'أماكن ترفيه وخروج للصحاب',
                'theme' => 'خروجات ولمات',
                'difficulty' => 'easy',
                'words' => [
                    'السينما', 'الكافيه', 'المول التجاري', 'حديقة الحيوان',
                    'النادي الرياضي', 'الاستاد', 'شاطئ البحر', 'الملاهي', 'بولينج',
                ],
            ],
            [
                'pack_slug' => 'places',
                'title_ar' => 'وسائل مواصلات شعبية',
                'theme' => 'الشارع المصري',
                'difficulty' => 'medium',
                'words' => [
                    'مترو الأنفاق', 'الميكروباص', 'التوكتوك', 'قطار الصعيد',
                    'التاكسي الأبيض', 'أتوبيس النقل العام', 'الترام', 'الفلوكة النيلية',
                ],
            ],
            [
                'pack_slug' => 'foods',
                'title_ar' => 'أكلات شعبية مصرية أصيلة',
                'theme' => 'طعام شعبي',
                'difficulty' => 'easy',
                'words' => [
                    'كشري', 'حواوشي بلدي', 'فتة كوارع', 'طعمية سخنة',
                    'فول بالزيت الحار', 'مسقعة باللحمة', 'ملوخية بالأرانب',
                    'كبدة إسكندراني', 'بامية ضاني', 'صينية بطاطس بالفراخ',
                ],
            ],
            [
                'pack_slug' => 'foods',
                'title_ar' => 'حلويات ومشروبات السهرة المصرية',
                'theme' => 'حلويات وسهرات',
                'difficulty' => 'medium',
                'words' => [
                    'أم علي', 'بسبوسة بالقشطة', 'كنافة نابلسية', 'رز بلبن بالمستكة',
                    'بلح الشام', 'عصير قصب', 'شاي كشري بنعناع', 'سحلب بالمكسرات', 'كركديه مثلج',
                ],
            ],
            [
                'pack_slug' => 'movies',
                'title_ar' => 'أفلام كوميدية كلاسيكية للصحاب',
                'theme' => 'سينما كوميدية',
                'difficulty' => 'easy',
                'words' => [
                    'الناظر', 'صعيدي في الجامعة الأمريكية', 'غبي منه فيه',
                    'الكيف', 'بوحة', 'اللمبي', 'مرجان أحمد مرجان',
                    'إكس لارج', 'كده رضا', 'الفرح',
                ],
            ],
            [
                'pack_slug' => 'mixed',
                'title_ar' => 'مهن وخدمات في الشارع المصري',
                'theme' => 'مهن حرة',
                'difficulty' => 'hard',
                'words' => [
                    'الحلاق', 'المكوجي', 'الجزار', 'السباك',
                    'الميكانيكي', 'النجار', 'البقال', 'الفواكهي', 'الكهربائي',
                ],
            ],
        ];

        foreach ($groups as $gData) {
            $words = $gData['words'];
            $hash = SpyWordGroup::makeContentHash($gData['title_ar'], $words);

            $group = SpyWordGroup::firstOrCreate(
                ['content_hash' => $hash],
                [
                    'pack_slug' => $gData['pack_slug'],
                    'title_ar' => $gData['title_ar'],
                    'theme' => $gData['theme'],
                    'difficulty' => $gData['difficulty'],
                    'status' => 'active',
                    'source' => 'seed',
                ]
            );

            foreach ($words as $word) {
                $norm = mb_strtolower(trim($word));
                $wHash = hash('sha256', $norm);
                SpyGroupWord::firstOrCreate(
                    [
                        'group_id' => $group->id,
                        'content_hash' => $wHash,
                    ],
                    [
                        'word_ar' => $word,
                        'normalized_word' => $norm,
                    ]
                );
            }
        }
    }
}
