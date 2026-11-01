// Lamma - by Mohamed Ibrahim

import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/arabic_text_normalizer.dart';
import '../api/api_client.dart';
import 'ai_question_service.dart';
import '../constants/charades_words_bank.dart';
import '../models/bootstrap_data.dart';
import '../models/question_model.dart';
import '../providers/game_providers.dart';
import '../storage/local_storage.dart';

// Rich Egyptian Fallback Bank for Spy Game
const Map<String, List<String>> kFallbackSpyPacks = {
  'places': [
    'خان الخليلي',
    'شاطئ المعمورة',
    'مطار القاهرة',
    'برج القاهرة',
    'الأهرامات',
    'محطة مصر',
    'قلعة قايتباي',
    'شارع المعز',
    'حديقة الأزهر',
    'مجمع التحرير',
    'سوق العتبة',
    'مكتبة الإسكندرية',
    'ساقية الصاوي',
    'ميدان طلعت حرب',
    'المتحف المصري الكبير',
    'قصر البارون',
    'كوبري قصر النيل',
    'كورنيش النيل',
    'سوق الجمعة',
    'حديقة الحيوان بالجيزة',
  ],
  'movies': [
    'الكيف',
    'الفرح',
    'الناظر',
    'عسل أسود',
    'إبراهيم الأبيض',
    'طيور الظلام',
    'الإرهاب والكباب',
    'بوحة',
    'اللمبي',
    'صعيدي في الجامعة الأمريكية',
    'فول الصين العظيم',
    'أبو علي',
    'تيتو',
    'كده رضا',
    'ولاد رزق',
    'الفيل الأزرق',
    'مرجان أحمد مرجان',
    'سهر الليالي',
    'إكس لارج',
    'غبي منه فيه',
  ],
  'food': [
    'كشري',
    'ملوخية بالأرانب',
    'حمام محشي',
    'فول وطعمية',
    'حواوشي',
    'فتة كوارع',
    'مسقعة',
    'كباب وكفتة',
    'شاورما مصري',
    'أم علي',
    'بامية باللحمة الضاني',
    'صينية بطاطس بالفراخ',
    'طاجن عكاوي',
    'كبدة إسكندراني',
    'سجق شرقي',
    'مكرونة بشاميل',
    'رز بلبن بالمستكة',
    'فطير مشلتت',
    'كشك ألماظية',
    'محشي كرنب وممبار',
  ],
};

// Rich Egyptian Fallback Banks for Charades Game per Category
const List<String> kFallbackCharadesMovies = [
  'الناظر',
  'صعيدي في الجامعة الأمريكية',
  'الكيف',
  'الفرح',
  'إبراهيم الأبيض',
  'عسل أسود',
  'طيور الظلام',
  'الإرهاب والكباب',
  'أمير الظلام',
  'بوحة',
  'اللمبي',
  'فول الصين العظيم',
  'مرجان أحمد مرجان',
  'أبو علي',
  'تيتو',
  'واحد من الناس',
  'كده رضا',
  'آسف على الإزعاج',
  'إكس لارج',
  'الحرب العالمية الثالثة',
  'ولاد رزق',
  'الفيل الأزرق',
  'كازابلانكا',
  'وقفة رجالة',
  'بيت الروبي',
  'سفير جهنم',
  'الزوجة الثانية',
  'باب الحديد',
  'الأيدي الناعمة',
  'إشاعة حب',
  'سواق الأتوبيس',
  'كتكوت',
  'اللمبي 8 جيجا',
  'وش إجرام',
  'يا أنا يا خالتي',
  'صاحب صاحبه',
  'جاءنا البيان التالي',
  'همام في أمستردام',
  'رشة جريئة',
  'طباخ الريس',
  'مدرسة المشاغبين',
  'العيال كبرت',
  'المتزوجون',
  'شاهد مشفش حاجة',
  'سك على بناتك',
];

const List<String> kFallbackCharadesJobs = [
  'طبيب جراح',
  'مهندس ديكور',
  'محامي في المحكمة',
  'مدرس في الفصل',
  'طباخ شاورما',
  'ممثل مسرحي',
  'مطرب شعبي',
  'لاعب كرة قدم',
  'ضابط شرطة',
  'طيار حربي',
  'بحار في سفينة',
  'نجار باب وشباك',
  'سباك',
  'كهربائي منازل',
  'رسام بورتريه',
  'مصور فوتوغرافي',
  'صحفي تحقيقات',
  'طبيب أسنان',
  'صيدلي',
  'ممرض طوارئ',
  'حارس مرمى',
  'سائق تاكسي',
  'ميكانيكي سيارات',
  'خياط رجالي',
  'حلاق',
  'بائع خضار',
  'نادل كافيه',
  'فلاح في الغيط',
  'صياد سمك',
  'رائد فضاء',
  'غواص تحت الماء',
  'جزار',
  'حداد',
  'ساعي بريد',
  'منقذ على الشاطئ',
];

const List<String> kFallbackCharadesActions = [
  'بيجري ورا الأتوبيس',
  'بيطير طيارة ورق',
  'بيعوم في البحر',
  'بيرقص في فرح',
  'بيغني في الحمام',
  'بياكل محشي سخن',
  'بيشرب شاي بالنعناع',
  'بينام وهو واقف',
  'بيضحك من غير صوت',
  'بيعيط على بصلة',
  'بينط بالحبل',
  'بيركب عجل',
  'بيسوق عربية مانيوال',
  'بيطبخ ملوخية',
  'بيكتب رسالة سرية',
  'بيقرا كتاب مقلوب',
  'بيرسم لوحة تجريدية',
  'بيلعب بلايستيشن',
  'بيتكلم في الموبايل والشبكة بتقطع',
  'بيصور سيلفي',
  'بيشيل أنبوبة بوتاجاز',
  'بيزق عربية عطلانة',
  'بيصيد سمكة كبيرة',
  'بيغير لمبة محروقة',
  'بيكوي قميص',
  'بيغسل مواعين',
  'بيكنس السجادة',
  'بيخبط على الباب',
  'بيصحي حد نايم تقيل',
  'بيحط شطة زيادة في الأكل',
  'بيشحت ولاعة',
  'بيدور على المفاتيح الضايعة',
  'بيتزحلق على قشرة موز',
  'بيصلح دش فوق السطوح',
  'بيعد فلوس مبلولة',
];

const List<String> kFallbackCharadesMixed = [
  'أهرامات الجيزة',
  'برج القاهرة',
  'نهر النيل',
  'توك توك',
  'عربة فول',
  'طبق كشري',
  'حلة محشي',
  'فانوس رمضان',
  'كوباية شاي',
  'شيشة',
  'بلايستيشن',
  'مروحة سقف',
  'تكييف عطلان',
  'مترو الأنفاق',
  'قطار الصعيد',
  'أسد في جنينة الحيوانات',
  'تمساح النيل',
  'دولفين',
  'فيل بخرطوم',
  'قرد بيقشر سوداني',
  'فرعون مومياء',
  'كابتن ماجد',
  'سبايدرمان فوق كوبري أكتوبر',
  'سوبرمان في وسط البلد',
  'بطمان',
  'طلمبة بنزين',
  'سوق الجمعة',
  'مول العرب',
  'فرح بلدي',
  'قهوة بلدي',
  ...kFallbackCharadesMovies,
  ...kFallbackCharadesJobs,
  ...kFallbackCharadesActions,
];

// للتوافق مع أي مراجع سابقة
const List<String> kFallbackCharadesWords = kFallbackCharadesMovies;

// Exception لما الأسئلة المتاحة في القسم ما تكفيش العدد المطلوب
class InsufficientTriviaQuestionsException implements Exception {
  final String category;
  final int available;
  final int requiredCount;

  const InsufficientTriviaQuestionsException({
    required this.category,
    required this.available,
    required this.requiredCount,
  });

  @override
  String toString() => 'القسم $category فيه $available سؤال فقط، والمطلوب $requiredCount';
}

// Rich Egyptian Fallback Bank for Trivia Game
const List<QuestionModel> kFallbackTriviaQuestions = [
  QuestionModel(
    id: 1,
    categoryId: 3,
    categorySlug: 'afeehat',
    type: 'mcq',
    promptAr: 'مين صاحب الإفيه الشهير: يا صفيحة زبالة منورة؟',
    options: ['عادل إمام', 'محمد هنيدي', 'أحمد حلمي', 'نجيب الريحاني'],
    correctIndex: 1,
    difficulty: 'medium',
    explanationAr: 'محمد هنيدي في فيلم صعيدي في الجامعة الأمريكية',
    source: 'seed',
  ),
  QuestionModel(
    id: 2,
    categoryId: 1,
    categorySlug: 'movies',
    type: 'mcq',
    promptAr: 'إيه اسم بطل فيلم الكيف المشهور بالدكتور؟',
    options: ['البهظ بيه', 'دكتور صلاح', 'مزاجنجي', 'عبده كفتة'],
    correctIndex: 1,
    difficulty: 'easy',
    explanationAr: 'يحيى الفخراني في دور الدكتور صلاح',
    source: 'seed',
  ),
  QuestionModel(
    id: 3,
    categoryId: 2,
    categorySlug: 'sports',
    type: 'mcq',
    promptAr: 'مين هو الهداف التاريخي للنادي الأهلي في الدوري المصري؟',
    options: ['محمود الخطيب', 'محمد أبو تريكة', 'حسام حسن', 'عماد متعب'],
    correctIndex: 0,
    difficulty: 'medium',
    explanationAr: 'الكابتن محمود الخطيب برصيد 109 هدف',
    source: 'seed',
  ),
  QuestionModel(
    id: 4,
    categoryId: 1,
    categorySlug: 'movies',
    type: 'mcq',
    promptAr: 'مين مخرج فيلم "الأرض" الشهير؟',
    options: ['يوسف شاهين', 'صلاح أبو سيف', 'عاطف الطيب', 'داود عبد السيد'],
    correctIndex: 0,
    difficulty: 'medium',
    explanationAr: 'المخرج يوسف شاهين عام 1970',
    source: 'seed',
  ),
  QuestionModel(
    id: 5,
    categoryId: 3,
    categorySlug: 'afeehat',
    type: 'mcq',
    promptAr: 'في فيلم الناظر، مين جسد شخصية "عاطف"؟',
    options: ['أحمد حلمي', 'علاء ولي الدين', 'محمد سعد', 'حسن حسني'],
    correctIndex: 0,
    difficulty: 'easy',
    explanationAr: 'الفنان أحمد حلمي في دور عاطف',
    source: 'seed',
  ),
  QuestionModel(
    id: 6,
    categoryId: 2,
    categorySlug: 'sports',
    type: 'mcq',
    promptAr: 'منتخب مصر فاز بكأس أمم إفريقيا كام مرة تاريخياً؟',
    options: ['5 مرات', '6 مرات', '7 مرات', '8 مرات'],
    correctIndex: 2,
    difficulty: 'easy',
    explanationAr: 'مصر تحمل الرقم القياسي برصيد 7 ألقاب',
    source: 'seed',
  ),
  QuestionModel(
    id: 7,
    categoryId: 4,
    categorySlug: 'history',
    type: 'mcq',
    promptAr: 'مين بنى قلعة الجبل الشهيرة في القاهرة؟',
    options: ['صلاح الدين الأيوبي', 'محمد علي باشا', 'الظاهر بيبرس', 'قطز'],
    correctIndex: 0,
    difficulty: 'easy',
    explanationAr: 'السلطان الناصر صلاح الدين الأيوبي',
    source: 'seed',
  ),
  QuestionModel(
    id: 8,
    categoryId: 3,
    categorySlug: 'afeehat',
    type: 'mcq',
    promptAr: 'صاحب إفيه: "كله ضرب ضرب مفيش شتيمة؟"',
    options: ['عادل إمام', 'محمد سعد', 'فؤاد المهندس', 'سعيد صالح'],
    correctIndex: 0,
    difficulty: 'easy',
    explanationAr: 'عادل إمام في مسرحية مدرسة المشاغبين',
    source: 'seed',
  ),
  QuestionModel(
    id: 9,
    categoryId: 1,
    categorySlug: 'movies',
    type: 'mcq',
    promptAr: 'إيه اسم القرية في فيلم "الزوجة الثانية"؟',
    options: ['ميت العطار', 'ميت حبيب', 'ميت غمر', 'كفر الدوار'],
    correctIndex: 0,
    difficulty: 'hard',
    explanationAr: 'قرية ميت العطار إخراج صلاح أبو سيف',
    source: 'seed',
  ),
  QuestionModel(
    id: 10,
    categoryId: 2,
    categorySlug: 'sports',
    type: 'mcq',
    promptAr: 'مين صاحب هدف فوز الزمالك بكأس الكونفدرالية 2019؟',
    options: ['محمود علاء', 'يوسف أوباما', 'فرجاني ساسي', 'طارق حامد'],
    correctIndex: 0,
    difficulty: 'medium',
    explanationAr: 'محمود علاء من ضربة جزاء ضد نهضة بركان',
    source: 'seed',
  ),
  QuestionModel(
    id: 11,
    categoryId: 3,
    categorySlug: 'afeehat',
    type: 'mcq',
    promptAr: 'في فيلم "غبي منه فيه"، مين قال: "أنا مش مصدق عيني.. سامعين يا ولاد"؟',
    options: ['طلعت زكريا', 'حسن حسني', 'هاني رمزي', 'سعيد طرابيك'],
    correctIndex: 1,
    difficulty: 'easy',
    explanationAr: 'حسن حسني (عم ضبش)',
    source: 'seed',
  ),
  QuestionModel(
    id: 12,
    categoryId: 1,
    categorySlug: 'movies',
    type: 'mcq',
    promptAr: 'في فيلم "إبراهيم الأبيض"، مين جسد شخصية المعلم زرزور؟',
    options: ['محمود عبد العزيز', 'أحمد السقا', 'عمرو واكد', 'باسم سمرة'],
    correctIndex: 0,
    difficulty: 'easy',
    explanationAr: 'الفنان القدير محمود عبد العزيز',
    source: 'seed',
  ),
  QuestionModel(
    id: 13,
    categoryId: 4,
    categorySlug: 'history',
    type: 'mcq',
    promptAr: 'أي عام تم فيه افتتاح قناة السويس للملاحة لأول مرة؟',
    options: ['1869', '1882', '1956', '1973'],
    correctIndex: 0,
    difficulty: 'medium',
    explanationAr: 'افتتحت رسمياً في 17 نوفمبر 1869 في عهد الخديوي إسماعيل',
    source: 'seed',
  ),
  QuestionModel(
    id: 14,
    categoryId: 3,
    categorySlug: 'afeehat',
    type: 'mcq',
    promptAr: 'صاحب إفيه: "يا باسط الخلج.. نهارنا لبن حليب"؟',
    options: ['محمد سعد', 'محمد هنيدي', 'عادل إمام', 'أحمد مكي'],
    correctIndex: 0,
    difficulty: 'easy',
    explanationAr: 'محمد سعد في فيلم بوحة',
    source: 'seed',
  ),
  QuestionModel(
    id: 15,
    categoryId: 2,
    categorySlug: 'sports',
    type: 'mcq',
    promptAr: 'مين اللاعب المصري الوحيد الحائز على جائزة بوشكاش لأفضل هدف في العالم؟',
    options: ['محمد صلاح', 'محمد أبو تريكة', 'حسام غالي', 'أحمد حسن'],
    correctIndex: 0,
    difficulty: 'easy',
    explanationAr: 'محمد صلاح عن هدفه في مرمى إيفرتون عام 2018',
    source: 'seed',
  ),
  // أسئلة إضافية للأفلام (Movies)
  QuestionModel(
    id: 16,
    categoryId: 1,
    categorySlug: 'movies',
    type: 'mcq',
    promptAr: 'مين بطل فيلم "الناصر صلاح الدين" التاريخي الشهير؟',
    options: ['أحمد مظهر', 'رشدي أباظة', 'صلاح ذو الفقار', 'محمود ياسين'],
    correctIndex: 0,
    difficulty: 'easy',
    explanationAr: 'الفنان أحمد مظهر',
    source: 'seed',
  ),
  QuestionModel(
    id: 17,
    categoryId: 1,
    categorySlug: 'movies',
    type: 'mcq',
    promptAr: 'مين مخرج فيلم "الكيت كات" الشهير للشيخ حسني؟',
    options: ['داود عبد السيد', 'خيري بشارة', 'محمد خان', 'يسري نصر الله'],
    correctIndex: 0,
    difficulty: 'medium',
    explanationAr: 'المخرج داود عبد السيد بطولة محمود عبد العزيز',
    source: 'seed',
  ),
  QuestionModel(
    id: 18,
    categoryId: 1,
    categorySlug: 'movies',
    type: 'mcq',
    promptAr: 'في أي فيلم جسد أحمد زكي شخصية منتصر الهارب؟',
    options: ['الهروب', 'البريء', 'الإمبراطور', 'زوجة رجل مهم'],
    correctIndex: 0,
    difficulty: 'medium',
    explanationAr: 'فيلم الهروب للمخرج عاطف الطيب',
    source: 'seed',
  ),
  QuestionModel(
    id: 19,
    categoryId: 1,
    categorySlug: 'movies',
    type: 'mcq',
    promptAr: 'مين ألف موسيقى فيلم "المصير" ليوسف شاهين؟',
    options: ['كمال الطويل', 'عمار الشريعي', 'عمر خيرت', 'ياسر عبد الرحمن'],
    correctIndex: 0,
    difficulty: 'hard',
    explanationAr: 'الموسيقار كمال الطويل ومحمد نوح',
    source: 'seed',
  ),
  QuestionModel(
    id: 20,
    categoryId: 1,
    categorySlug: 'movies',
    type: 'mcq',
    promptAr: 'مين بطلة فيلم "دعاء الكروان" المأخوذ عن رواية طه حسين؟',
    options: ['فاتن حمامة', 'شادية', 'سعاد حسني', 'ماجدة'],
    correctIndex: 0,
    difficulty: 'easy',
    explanationAr: 'سيدة الشاشة العربية فاتن حمامة',
    source: 'seed',
  ),
  QuestionModel(
    id: 21,
    categoryId: 1,
    categorySlug: 'movies',
    type: 'mcq',
    promptAr: 'في فيلم "عسل أسود"، إيه كان اسم الشخصية التي جسدها أحمد حلمي؟',
    options: ['مصري سيد العربي', 'سعيد حركات', 'عاطف السكري', 'رضا'],
    correctIndex: 0,
    difficulty: 'easy',
    explanationAr: 'مصري سيد العربي العائد من أمريكا',
    source: 'seed',
  ),
  // أسئلة إضافية للكورة والرياضة (Sports)
  QuestionModel(
    id: 22,
    categoryId: 2,
    categorySlug: 'sports',
    type: 'mcq',
    promptAr: 'إيه أقدم نادي كرة قدم تأسس في مصر؟',
    options: ['السكة الحديد', 'الأهلي', 'الزمالك', 'الاتحاد السكندري'],
    correctIndex: 0,
    difficulty: 'medium',
    explanationAr: 'نادي السكة الحديد تأسس عام 1903',
    source: 'seed',
  ),
  QuestionModel(
    id: 23,
    categoryId: 2,
    categorySlug: 'sports',
    type: 'mcq',
    promptAr: 'مين أول لاعب مصري وعربي يسجل هدفاً في كأس العالم؟',
    options: ['عبد الرحمن فوزي', 'مجدي عبد الغني', 'محمد صلاح', 'محمود الخطيب'],
    correctIndex: 0,
    difficulty: 'medium',
    explanationAr: 'عبد الرحمن فوزي عام 1934 في شباك المجر',
    source: 'seed',
  ),
  QuestionModel(
    id: 24,
    categoryId: 2,
    categorySlug: 'sports',
    type: 'mcq',
    promptAr: 'لقب الحارس الأسطوري عصام الحضري الشهير؟',
    options: ['السد العالي', 'الأخطبوط', 'الصقر', 'الوحش'],
    correctIndex: 0,
    difficulty: 'easy',
    explanationAr: 'السد العالي عصام الحضري',
    source: 'seed',
  ),
  QuestionModel(
    id: 25,
    categoryId: 2,
    categorySlug: 'sports',
    type: 'mcq',
    promptAr: 'مين مدرب منتخب مصر اللي فاز بـ 3 بطولات أمم إفريقيا متتالية (2006، 2008، 2010)؟',
    options: ['حسن شحاتة', 'محمود الجوهري', 'هيكتور كوبر', 'محمود فتحي'],
    correctIndex: 0,
    difficulty: 'easy',
    explanationAr: 'المعلم حسن شحاتة',
    source: 'seed',
  ),
  QuestionModel(
    id: 26,
    categoryId: 2,
    categorySlug: 'sports',
    type: 'mcq',
    promptAr: 'مين الفريق صاحب لقب "الشواكيش" في الكرة المصرية؟',
    options: ['الترسانة', 'المقاولون العرب', 'المحلة', 'الإسماعيلي'],
    correctIndex: 0,
    difficulty: 'easy',
    explanationAr: 'نادي الترسانة العريق',
    source: 'seed',
  ),
  QuestionModel(
    id: 27,
    categoryId: 2,
    categorySlug: 'sports',
    type: 'mcq',
    promptAr: 'أي نادي مصري فاز ببطولة كأس الكؤوس الإفريقية 4 مرات محتفظاً بالكأس للأبد؟',
    options: ['الأهلي', 'الزمالك', 'المقاولون العرب', 'الإسماعيلي'],
    correctIndex: 0,
    difficulty: 'hard',
    explanationAr: 'النادي الأهلي أعوام 1984، 1985، 1986، 1993',
    source: 'seed',
  ),
  // أسئلة إضافية للإفيهات (Afeehat)
  QuestionModel(
    id: 28,
    categoryId: 3,
    categorySlug: 'afeehat',
    type: 'mcq',
    promptAr: 'صاحب إفيه: "نشنت يا فالح" في السينما المصرية؟',
    options: ['استيفان روستي', 'زكي رستم', 'محمود المليجي', 'توفيق الدقن'],
    correctIndex: 0,
    difficulty: 'easy',
    explanationAr: 'الفنان استيفان روستي في فيلم حبيبي الأسمر',
    source: 'seed',
  ),
  QuestionModel(
    id: 29,
    categoryId: 3,
    categorySlug: 'afeehat',
    type: 'mcq',
    promptAr: 'مين قال الإفيه الشهير: "أحلى من الشرف مفيش"؟',
    options: ['توفيق الدقن', 'محمود المليجي', 'استيفان روستي', 'فريد شوقي'],
    correctIndex: 0,
    difficulty: 'easy',
    explanationAr: 'الفنان توفيق الدقن في فيلم أحبك يا حسن',
    source: 'seed',
  ),
  QuestionModel(
    id: 30,
    categoryId: 3,
    categorySlug: 'afeehat',
    type: 'mcq',
    promptAr: 'صاحب إفيه: "كتاكيتو بني" في مسرحية المتزوجون؟',
    options: ['نجاح الموجي', 'سمير غانم', 'جورج سيدهم', 'أحمد راتب'],
    correctIndex: 0,
    difficulty: 'easy',
    explanationAr: 'الفنان نجاح الموجي (الواد مزيكا)',
    source: 'seed',
  ),
  QuestionModel(
    id: 31,
    categoryId: 3,
    categorySlug: 'afeehat',
    type: 'mcq',
    promptAr: 'مين صاحب إفيه: "يا صفايح الزبدة السايحة يا براميل القشطة النايحة"؟',
    options: ['عبد الفتاح القصري', 'إسماعيل ياسين', 'حسن فايق', 'علي الكسار'],
    correctIndex: 0,
    difficulty: 'medium',
    explanationAr: 'عبد الفتاح القصري في فيلم سكر هانم',
    source: 'seed',
  ),
  QuestionModel(
    id: 32,
    categoryId: 3,
    categorySlug: 'afeehat',
    type: 'mcq',
    promptAr: 'في فيلم "الكيف"، مين قال: "إحنا في عصر الهبوط يا دكتور.. إحنا اللي فرفرنا الشارع"؟',
    options: ['محمود عبد العزيز', 'يحيى الفخراني', 'جميل راتب', 'فؤاد خليل'],
    correctIndex: 0,
    difficulty: 'hard',
    explanationAr: 'محمود عبد العزيز (مزاجنجي)',
    source: 'seed',
  ),
  // أسئلة إضافية للتاريخ والجغرافيا (History)
  QuestionModel(
    id: 33,
    categoryId: 4,
    categorySlug: 'history',
    type: 'mcq',
    promptAr: 'مين مؤسس مصر الحديثة وباني نهضتها في القرن التاسع عشر؟',
    options: ['محمد علي باشا', 'الخديوي إسماعيل', 'إبراهيم باشا', 'عباس حلمي'],
    correctIndex: 0,
    difficulty: 'easy',
    explanationAr: 'محمد علي باشا والي مصر ومؤسس نهضتها',
    source: 'seed',
  ),
  QuestionModel(
    id: 34,
    categoryId: 4,
    categorySlug: 'history',
    type: 'mcq',
    promptAr: 'أول رئيس لجمهورية مصر بعد ثورة 23 يوليو 1952؟',
    options: ['محمد نجيب', 'جمال عبد الناصر', 'أنور السادات', 'علي ماهر'],
    correctIndex: 0,
    difficulty: 'easy',
    explanationAr: 'اللواء محمد نجيب أول رئيس لمصر',
    source: 'seed',
  ),
  QuestionModel(
    id: 35,
    categoryId: 4,
    categorySlug: 'history',
    type: 'mcq',
    promptAr: 'في أي عام تم توقيع معاهدة السلام المصرية الإسرائيلية في كامب ديفيد؟',
    options: ['1979', '1973', '1981', '1977'],
    correctIndex: 0,
    difficulty: 'medium',
    explanationAr: 'وقّعها الرئيس الراحل أنور السادات عام 1979',
    source: 'seed',
  ),
  QuestionModel(
    id: 36,
    categoryId: 4,
    categorySlug: 'history',
    type: 'mcq',
    promptAr: 'المدينة المصرية التي لُقبت تاريخياً بـ "مدينة الألف مئذنة"؟',
    options: ['القاهرة', 'الإسكندرية', 'الأقصر', 'أسوان'],
    correctIndex: 0,
    difficulty: 'easy',
    explanationAr: 'القاهرة لكثرة جوامعها ومآذنها التاريخية',
    source: 'seed',
  ),
  QuestionModel(
    id: 37,
    categoryId: 4,
    categorySlug: 'history',
    type: 'mcq',
    promptAr: 'مين القائد المملوكي الذي انتصر على المغول في معركة عين جالوت؟',
    options: ['سيف الدين قطز', 'الظاهر بيبرس', 'شجر الدر', 'قلاوون'],
    correctIndex: 0,
    difficulty: 'medium',
    explanationAr: 'السلطان سيف الدين قطز عام 1260م',
    source: 'seed',
  ),
  QuestionModel(
    id: 38,
    categoryId: 4,
    categorySlug: 'history',
    type: 'mcq',
    promptAr: 'إيه اسم الجزيرة المصرية التي استردتها مصر في التحكيم الدولي عام 1989؟',
    options: ['طابا', 'تيران', 'صناع', 'الوراق'],
    correctIndex: 0,
    difficulty: 'hard',
    explanationAr: 'مدينة طابا بالتحكيم الدولي',
    source: 'seed',
  ),
  // أسئلة إضافية للمعلومات العامة (General)
  QuestionModel(
    id: 39,
    categoryId: 5,
    categorySlug: 'general',
    type: 'mcq',
    promptAr: 'إيه أطول نهر في العالم والذي يمر بجمهورية مصر العربية؟',
    options: ['نهر النيل', 'نهر الأمازون', 'نهر المسيسيبي', 'نهر الدانوب'],
    correctIndex: 0,
    difficulty: 'easy',
    explanationAr: 'نهر النيل العظيم شريان الحياة في مصر',
    source: 'seed',
  ),
  QuestionModel(
    id: 40,
    categoryId: 5,
    categorySlug: 'general',
    type: 'mcq',
    promptAr: 'ما هي أعلى قمة جبلية في جمهورية مصر العربية؟',
    options: ['جبل سانت كاترين', 'جبل موسى', 'جبل سربال', 'جبل الشايب'],
    correctIndex: 0,
    difficulty: 'easy',
    explanationAr: 'جبل سانت كاترين في جنوب سيناء بارتفاع 2629 متر',
    source: 'seed',
  ),
  QuestionModel(
    id: 41,
    categoryId: 5,
    categorySlug: 'general',
    type: 'mcq',
    promptAr: 'أي من هذه البحار يحد جمهورية مصر العربية من جهة الشمال؟',
    options: ['البحر الأبيض المتوسط', 'البحر الأحمر', 'البحر الميت', 'بحر قزوين'],
    correctIndex: 0,
    difficulty: 'easy',
    explanationAr: 'البحر الأبيض المتوسط يحد مصر شمالاً',
    source: 'seed',
  ),
  QuestionModel(
    id: 42,
    categoryId: 5,
    categorySlug: 'general',
    type: 'mcq',
    promptAr: 'في أي محافظة مصرية يقع مجمع مصانع الألومنيوم الشهير؟',
    options: ['قنا', 'أسوان', 'سوهاج', 'الأقصر'],
    correctIndex: 0,
    difficulty: 'medium',
    explanationAr: 'في مدينة نجع حمادي بمحافظة قنا',
    source: 'seed',
  ),
  QuestionModel(
    id: 43,
    categoryId: 5,
    categorySlug: 'general',
    type: 'mcq',
    promptAr: 'إيه أكبر واحة في مصر من حيث المساحة؟',
    options: ['واحة الفرافرة', 'واحة سيوة', 'الواحات البحرية', 'الواحات الداخلة'],
    correctIndex: 0,
    difficulty: 'hard',
    explanationAr: 'واحة الفرافرة في الصحراء الغربية',
    source: 'seed',
  ),
  QuestionModel(
    id: 44,
    categoryId: 5,
    categorySlug: 'general',
    type: 'mcq',
    promptAr: 'المتحف التاريخي العريق الواقع في ميدان التحرير بقلب القاهرة؟',
    options: ['المتحف المصري', 'المتحف القومي للحضارة', 'متحف الفن الإسلامي', 'المتحف اليوناني الروماني'],
    correctIndex: 0,
    difficulty: 'easy',
    explanationAr: 'المتحف المصري بميدان التحرير تأسس عام 1902',
    source: 'seed',
  ),
];

class GameContentService {
  final ApiClient _api;
  final LocalStorage _storage;
  final AiQuestionService _ai;

  // Prefetch Buffers / Cache
  final List<String> _spyBuffer = [];
  final List<QuestionModel> _triviaBuffer = [];
  final List<String> _charadesBuffer = [];

  bool _isPrefetchingSpy = false;
  bool _isPrefetchingTrivia = false;
  bool _isPrefetchingCharades = false;

  bool hasRecycledTrivia = false;
  bool hasRecycledSpy = false;
  bool hasRecycledCharades = false;
  String? lastHintMessage;

  GameContentService(
    this._api,
    this._storage, {
    AiQuestionService? ai,
  }) : _ai = ai ?? AiQuestionService();

  List<QuestionModel> get triviaBuffer => List.unmodifiable(_triviaBuffer);
  List<String> get spyBuffer => List.unmodifiable(_spyBuffer);
  List<String> get charadesBuffer => List.unmodifiable(_charadesBuffer);

  void addGeneratedTriviaQuestions(List<QuestionModel> questions) {
    for (final q in questions) {
      if (!_triviaBuffer.any((b) => ArabicTextNormalizer.areEqual(b.promptAr, q.promptAr))) {
        _triviaBuffer.add(q);
      }
    }
  }

  void addGeneratedSpyWords(List<String> words) {
    for (final w in words) {
      if (!_spyBuffer.any((b) => ArabicTextNormalizer.areEqual(b, w))) {
        _spyBuffer.add(w);
      }
    }
  }

  void addGeneratedCharadesWords(List<String> words) {
    for (final w in words) {
      if (!_charadesBuffer.any((b) => ArabicTextNormalizer.areEqual(b, w))) {
        _charadesBuffer.add(w);
      }
    }
  }

  // ==========================================
  // 1. مين الجاسوس (SPY GAME)
  // ==========================================

  /// جلب كلمة/مكان سري للجاسوس بدون تكرار
  Future<String?> getNextSpyWord({
    required String packSlug,
    BootstrapData? bootstrapData,
    Set<String>? externalSeenHashes,
  }) async {
    final localSeen = _storage.getSeenSpyHashes();
    final allSeen = {...localSeen, ...?externalSeenHashes};

    // 1. تنقية البافر من أي كلمات شوهدت سابقاً
    _spyBuffer.removeWhere((w) {
      final h = ArabicTextNormalizer.wordHash(w);
      return allSeen.contains(h);
    });

    // 2. فحص prefetch في الخلفية
    if (_spyBuffer.length <= 5) {
      _triggerPrefetchSpy(packSlug, bootstrapData, allSeen);
    }

    // 3. لو البافر فيه كلمة متاحة
    if (_spyBuffer.isNotEmpty) {
      final picked = _spyBuffer.removeAt(0);
      final h = ArabicTextNormalizer.wordHash(picked);
      await _storage.markSpyHashesSeen([h]);
      await _storage.markSpyWordsSeen([picked]);
      return picked;
    }

    // 4. محاولة التوليد المباشر بالذكاء الاصطناعي مع مهلة 4 ثوانٍ
    try {
      final aiWords = await _ai.generateSpyWords(
        count: 15,
        category: packSlug,
        avoidWords: localSeen.take(30).toList(),
      ).timeout(const Duration(seconds: 4));

      for (final w in aiWords) {
        final h = ArabicTextNormalizer.wordHash(w);
        if (!allSeen.contains(h) && !_spyBuffer.any((b) => ArabicTextNormalizer.areEqual(b, w))) {
          _spyBuffer.add(w);
        }
      }
    } catch (_) {}

    if (_spyBuffer.isNotEmpty) {
      final picked = _spyBuffer.removeAt(0);
      final h = ArabicTextNormalizer.wordHash(picked);
      await _storage.markSpyHashesSeen([h]);
      await _storage.markSpyWordsSeen([picked]);
      return picked;
    }

    // 5. Fallback لبنك المحتوى المحلي (الكلمات غير المشاهدة أولاً)
    final fallbackList = _getFallbackSpyWords(packSlug, bootstrapData);
    final unseenFallback = fallbackList.where((w) {
      final h = ArabicTextNormalizer.wordHash(w);
      return !allSeen.contains(h);
    }).toList();

    if (unseenFallback.isNotEmpty) {
      unseenFallback.shuffle(Random());
      final picked = unseenFallback.first;
      final h = ArabicTextNormalizer.wordHash(picked);
      await _storage.markSpyHashesSeen([h]);
      await _storage.markSpyWordsSeen([picked]);
      return picked;
    }

    // 6. كل الكلمات المتاحة شوهدت: استهلاك الأقدم مشاهدة كحل أخير (FIFO Recycle) مع تلميح للمضيف
    hasRecycledSpy = true;
    lastHintMessage = 'اتصل بالإنترنت لمحتوى جديد';
    final seenList = localSeen.toList();
    final seenIndexMap = <String, int>{};
    for (var i = 0; i < seenList.length; i++) {
      seenIndexMap[seenList[i]] = i;
    }
    final sortedFallback = List<String>.from(fallbackList);
    final wordRanks = <String, int>{};
    for (final w in sortedFallback) {
      wordRanks[w] = seenIndexMap[ArabicTextNormalizer.wordHash(w)] ?? -1;
    }
    sortedFallback.sort((a, b) => wordRanks[a]!.compareTo(wordRanks[b]!));

    final picked = sortedFallback.isNotEmpty ? sortedFallback.first : (fallbackList.isNotEmpty ? fallbackList.first : 'الأهرامات');
    final h = ArabicTextNormalizer.wordHash(picked);
    await _storage.markSpyHashesSeen([h]);
    await _storage.markSpyWordsSeen([picked]);
    return picked;
  }

  void _triggerPrefetchSpy(String packSlug, BootstrapData? bootstrapData, [Set<String>? seenHashes]) {
    if (_isPrefetchingSpy) return;
    _isPrefetchingSpy = true;

    Future.microtask(() async {
      try {
        final seen = seenHashes ?? _storage.getSeenSpyHashes();
        final aiWords = await _ai.generateSpyWords(
          count: 15,
          category: packSlug,
          avoidWords: seen.take(30).toList(),
        );

        for (final word in aiWords) {
          final h = ArabicTextNormalizer.wordHash(word);
          if (!seen.contains(h) && !_spyBuffer.any((b) => ArabicTextNormalizer.areEqual(b, word))) {
            _spyBuffer.add(word);
          }
        }
      } catch (_) {
      } finally {
        _isPrefetchingSpy = false;
      }
    });
  }

  List<String> _getFallbackSpyWords(String packSlug, BootstrapData? bootstrapData) {
    final list = <String>[];
    if (bootstrapData != null) {
      for (final pack in bootstrapData.spyPacks) {
        if (pack.slug == packSlug || packSlug == 'mixed') {
          list.addAll(pack.words);
        }
      }
    }
    if (list.isEmpty) {
      if (packSlug == 'movies') {
        list.addAll(kFallbackSpyPacks['movies']!);
      } else if (packSlug == 'food') {
        list.addAll(kFallbackSpyPacks['food']!);
      } else {
        list.addAll(kFallbackSpyPacks['places']!);
      }
    }
    return list;
  }

  // ==========================================
  // 2. تحدي الشلة (TRIVIA GAME)
  // ==========================================

  /// جلب أسئلة لتحدي الشلة مع تطبيق صارم للأقسام والصعوبة والعدد وبدون تكرار
  Future<List<QuestionModel>> getTriviaQuestions({
    required int count,
    List<String> categories = const [],
    String? category,
    String difficulty = 'all',
    BootstrapData? bootstrapData,
    bool allowAi = true,
    Set<String>? externalSeenPromptHashes,
    Set<String>? externalSeenAnswerHashes,
  }) async {
    // توحيد الأقسام المختارة
    final targetCategories = <String>[];
    if (categories.isNotEmpty) {
      targetCategories.addAll(categories);
    } else if (category != null && category.isNotEmpty) {
      targetCategories.add(category);
    }

    final localSeenPrompts = _storage.getSeenTriviaPromptHashes();
    final localSeenAnswers = _storage.getSeenTriviaAnswerHashes();
    final seenIds = _storage.getSeenQuestions();

    final allSeenPrompts = {...localSeenPrompts, ...?externalSeenPromptHashes};
    final allSeenAnswers = {...localSeenAnswers, ...?externalSeenAnswerHashes};

    // دالة تحقق صارمة من مطابقة القسم
    bool matchesCategory(String cat) {
      if (targetCategories.isEmpty || targetCategories.contains('all')) return true;
      return targetCategories.contains(cat);
    }

    // دالة تحقق صارمة من مطابقة الصعوبة
    bool matchesDifficulty(String diff) {
      if (difficulty.isEmpty || difficulty == 'all') return true;
      return diff == difficulty;
    }

    bool isAllowed(QuestionModel q, List<QuestionModel> currentResult) {
      if (!matchesCategory(q.categorySlug) || !matchesDifficulty(q.difficulty)) return false;
      final pHash = ArabicTextNormalizer.triviaQuestionHash(q.promptAr);
      final aHash = ArabicTextNormalizer.triviaAnswerHash(q.categorySlug, q.options[q.correctIndex]);

      if (allSeenPrompts.contains(pHash) || allSeenAnswers.contains(aHash)) return false;
      if (q.id > 0 && seenIds.contains(q.id)) return false;

      if (currentResult.any((r) {
        final rpHash = ArabicTextNormalizer.triviaQuestionHash(r.promptAr);
        final raHash = ArabicTextNormalizer.triviaAnswerHash(r.categorySlug, r.options[r.correctIndex]);
        return rpHash == pHash || raHash == aHash;
      })) {
        return false;
      }
      return true;
    }

    // 1. تنقية البافر
    _triviaBuffer.removeWhere((q) {
      final pHash = ArabicTextNormalizer.triviaQuestionHash(q.promptAr);
      final aHash = ArabicTextNormalizer.triviaAnswerHash(q.categorySlug, q.options[q.correctIndex]);
      return allSeenPrompts.contains(pHash) || allSeenAnswers.contains(aHash) || (q.id > 0 && seenIds.contains(q.id));
    });

    if (_triviaBuffer.length <= 5 && allowAi) {
      _triggerPrefetchTrivia(targetCategories, difficulty);
    }

    final result = <QuestionModel>[];

    // 2. أخذ من البافر فقط ما يطابق الأقسام والصعوبة المختارة حصراً
    final remainingBuffer = <QuestionModel>[];
    for (final q in _triviaBuffer) {
      if (result.length < count && isAllowed(q, result)) {
        result.add(q);
      } else {
        remainingBuffer.add(q);
      }
    }
    _triviaBuffer.clear();
    _triviaBuffer.addAll(remainingBuffer);

    if (result.length >= count) {
      await _recordSeenTrivia(result);
      return result.take(count).toList();
    }

    // 3. توليد بالذكاء الاصطناعي (AI) دفعة جديدة مع إعادة المحاولة حتى 3 مرات للعدد الناقص
    if (result.length < count && allowAi) {
      int retryCount = 0;
      while (result.length < count && retryCount < 3) {
        retryCount++;
        try {
          final missing = count - result.length;
          final batchCount = missing < 5 ? 5 : (missing + 3);

          List<QuestionModel> aiQuestions = [];

          // فحص ApiClient أولاً (للتوافق مع الـ mock في الاختبارات والبروكسي) مع مهلة 4 ثوانٍ
          try {
            final rawItems = await _api.generateAiContent(
              gameType: 'trivia',
              categories: targetCategories.isNotEmpty && !targetCategories.contains('all')
                  ? targetCategories
                  : null,
              difficulty: difficulty,
              count: batchCount,
              excludeItems: result.map((r) => r.promptAr).take(20).toList(),
            ).timeout(const Duration(seconds: 4));

            if (rawItems.isNotEmpty) {
              for (var i = 0; i < rawItems.length; i++) {
                final item = rawItems[i];
                final prompt = (item['prompt_ar'] ?? item['prompt']) as String?;
                final options = (item['options'] as List<dynamic>?)
                    ?.map((e) => e.toString().trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                final correctIndex = item['correct_index'] as int? ?? 0;
                final itemCat = (item['category_slug'] ?? item['category']) as String? ??
                    (targetCategories.isNotEmpty ? targetCategories.first : 'general');
                final itemDiff = item['difficulty'] as String? ?? 'medium';

                if (prompt != null &&
                    prompt.trim().length >= 5 &&
                    options != null &&
                    options.length == 4 &&
                    options.toSet().length == 4 &&
                    correctIndex >= 0 &&
                    correctIndex <= 3 &&
                    matchesCategory(itemCat) &&
                    matchesDifficulty(itemDiff)) {
                  aiQuestions.add(QuestionModel(
                    id: -1 * (DateTime.now().millisecondsSinceEpoch % 1000000 + result.length + i + 1),
                    categoryId: 1,
                    categorySlug: itemCat,
                    type: 'mcq',
                    promptAr: prompt.trim(),
                    options: options,
                    correctIndex: correctIndex,
                    difficulty: itemDiff,
                    explanationAr: item['explanation_ar'] as String?,
                    source: 'gemini',
                  ));
                }
              }
            }
          } catch (_) {}

          // إذا لم ينتج عن ApiClient نتائج، نطلب مباشرة عبر خدمة الذكاء الاصطناعي (Gemini) مع مهلة 4 ثوانٍ
          if (aiQuestions.isEmpty) {
            aiQuestions = await _ai.generateTriviaQuestions(
              count: batchCount,
              categories: targetCategories.isNotEmpty && !targetCategories.contains('all')
                  ? targetCategories
                  : null,
              difficulty: difficulty != 'all' ? difficulty : null,
              avoidTopics: result.map((r) => r.promptAr).take(20).toList(),
            ).timeout(const Duration(seconds: 4));
          }

          for (final q in aiQuestions) {
            if (isAllowed(q, result)) {
              if (result.length < count) {
                result.add(q);
              } else {
                _triviaBuffer.add(q);
              }
            }
          }
        } catch (_) {
          break; // في حالة انقطاع الإنترنت أو الخطأ، التحول فوراً للمصادر المحلية
        }
      }
    }

    if (result.length >= count) {
      await _recordSeenTrivia(result);
      return result.take(count).toList();
    }

    // 4. Fallback لبنك الأسئلة المحلي (غير المعروض أولاً)
    final candidates = <QuestionModel>[...kFallbackTriviaQuestions];

    final matchingUnseen = candidates.where((q) => isAllowed(q, result)).toList();
    matchingUnseen.shuffle(Random());

    for (final q in matchingUnseen) {
      result.add(q);
      if (result.length >= count) break;
    }

    if (result.length >= count) {
      await _recordSeenTrivia(result);
      return result.take(count).toList();
    }

    // إذا تم تعطيل الـ AI بشكل صريح وكان البنك المحلي غير كافٍ للقسم والصعوبة
    if (result.length < count && !allowAi) {
      final categoryLabel = targetCategories.isNotEmpty ? targetCategories.join(' و ') : 'المختارة';
      throw InsufficientTriviaQuestionsException(
        category: categoryLabel,
        available: result.length,
        requiredCount: count,
      );
    }

    // 5. في حالة نفاد الأسئلة غير المعروضة بالكامل:
    // نستخدم الأقدم مشاهدة كحل أخير (FIFO Recycle) مع وضع تلميح للمضيف دون توقف أو رسالة خطأ
    hasRecycledTrivia = true;
    lastHintMessage = 'اتصل بالإنترنت لمحتوى جديد';

    final seenPromptList = localSeenPrompts.toList();
    final promptIndexMap = <String, int>{};
    for (var i = 0; i < seenPromptList.length; i++) {
      promptIndexMap[seenPromptList[i]] = i;
    }

    final matchingAll = candidates.where((q) {
      return matchesCategory(q.categorySlug) &&
          matchesDifficulty(q.difficulty) &&
          !result.any((r) => r.id == q.id);
    }).toList();

    final candidateRanks = <QuestionModel, int>{};
    for (final q in matchingAll) {
      final h = ArabicTextNormalizer.triviaQuestionHash(q.promptAr);
      candidateRanks[q] = promptIndexMap[h] ?? -1;
    }
    matchingAll.sort((a, b) => candidateRanks[a]!.compareTo(candidateRanks[b]!));

    for (final q in matchingAll) {
      result.add(q);
      if (result.length >= count) break;
    }

    // ضمان نهائي بعدم رجوع قائمة فارغة إطلاقاً
    if (result.isEmpty && candidates.isNotEmpty) {
      final forced = List<QuestionModel>.from(candidates)..shuffle(Random());
      result.addAll(forced.take(count));
    }

    await _recordSeenTrivia(result);
    return result;
  }

  /// إرجاع أسئلة فورية من البنك المحلي بدون انتظار الـ AI مع تفعيل تنبيه استهلاك البنك
  List<QuestionModel> getFallbackTriviaQuestions({
    required int count,
    List<String> categories = const [],
    String difficulty = 'all',
  }) {
    hasRecycledTrivia = true;
    lastHintMessage = 'اتصل بالإنترنت لمحتوى جديد';
    final targetCategories = categories.where((c) => c.isNotEmpty && c != 'all').toList();
    bool matchesCategory(String cat) {
      if (targetCategories.isEmpty) return true;
      return targetCategories.contains(cat);
    }
    bool matchesDifficulty(String diff) {
      if (difficulty.isEmpty || difficulty == 'all') return true;
      return diff == difficulty;
    }
    final pool = kFallbackTriviaQuestions.where((q) => matchesCategory(q.categorySlug) && matchesDifficulty(q.difficulty)).toList();
    if (pool.length < count) {
      pool.addAll(kFallbackTriviaQuestions.where((q) => !pool.contains(q)));
    }
    pool.shuffle(Random());
    return pool.take(count).toList();
  }

  void _triggerPrefetchTrivia(List<String> targetCategories, String? difficulty) {
    if (_isPrefetchingTrivia) return;
    _isPrefetchingTrivia = true;

    Future.microtask(() async {
      try {
        final seen = _storage.getSeenTriviaPromptHashes();
        final aiQuestions = await _ai.generateTriviaQuestions(
          count: 15,
          categories: targetCategories.isNotEmpty && !targetCategories.contains('all') ? targetCategories : null,
          difficulty: difficulty != 'all' ? difficulty : null,
        );

        for (final q in aiQuestions) {
          final pHash = ArabicTextNormalizer.triviaQuestionHash(q.promptAr);
          if (!seen.contains(pHash) && !_triviaBuffer.any((b) => ArabicTextNormalizer.areEqual(b.promptAr, q.promptAr))) {
            _triviaBuffer.add(q);
          }
        }
      } catch (_) {
      } finally {
        _isPrefetchingTrivia = false;
      }
    });
  }

  Future<void> _recordSeenTrivia(List<QuestionModel> questions) async {
    final promptHashes = questions.map((q) => ArabicTextNormalizer.triviaQuestionHash(q.promptAr)).toList();
    final answerHashes = questions.map((q) => ArabicTextNormalizer.triviaAnswerHash(q.categorySlug, q.options[q.correctIndex])).toList();
    final prompts = questions.map((q) => q.promptAr).toList();
    final ids = questions.where((q) => q.id > 0).map((q) => q.id).toList();

    await _storage.markTriviaHashesSeen(promptHashes: promptHashes, answerHashes: answerHashes);
    await _storage.markTriviaQuestionTextsSeen(prompts);
    if (ids.isNotEmpty) {
      await _storage.markQuestionsSeen(ids);
      await _api.markQuestionsSeen(ids);
    }
  }

  // ==========================================
  // 3. مثّل ومتتكلمش (CHARADES GAME)
  // ==========================================

  /// توحيد ومعايرة كود الفئة لضمان التطابق مع الباك إند والبنك المحلي
  static String normalizeCharadesCategory(String? category) {
    if (category == null || category.trim().isEmpty || category == 'all' || category == 'الكل') {
      return 'mixed';
    }
    final lower = category.trim().toLowerCase();
    if (lower == 'movies' || lower == 'movie' || lower == 'أفلام') {
      return 'movies';
    }
    if (lower == 'series' || lower == 'مسلسلات') {
      return 'series';
    }
    if (lower == 'verbs' || lower == 'actions' || lower == 'verb' || lower == 'action' || lower == 'أفعال') {
      return 'actions';
    }
    if (lower == 'jobs' || lower == 'job' || lower == 'مهن') {
      return 'jobs';
    }
    if (lower == 'animals' || lower == 'animal' || lower == 'حيوانات') {
      return 'animals';
    }
    if (lower == 'places' || lower == 'place' || lower == 'أماكن') {
      return 'places';
    }
    if (lower == 'things' || lower == 'thing' || lower == 'أشياء') {
      return 'things';
    }
    if (lower == 'proverbs' || lower == 'proverb' || lower == 'أمثال') {
      return 'proverbs';
    }
    if (lower == 'mixed' || lower == 'الكل') {
      return 'mixed';
    }
    return lower;
  }

  /// فحص جودة الكلمة وقابليتها للتمثيل الحركي دون كلام
  static bool isActableCharadesWord(String word) {
    final trimmed = word.trim();
    if (trimmed.length < 2 || trimmed.length > 60) return false;

    // حد أقصى 4 كلمات: عبارات أطول من 4 كلمات تُرفض
    final tokens = trimmed.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty || tokens.length > 4) return false;

    final norm = ArabicTextNormalizer.normalize(trimmed);
    final normTokens = tokens.map((t) => ArabicTextNormalizer.normalize(t)).toList();

    // استبعاد العبارات والمفاهيم المجردة المركبة
    const multiWordBanned = [
      'ذكاء اصطناعي',
      'الذكاء الاصطناعي',
      'احتباس حراري',
      'الاحتباس الحراري',
      'تضخم اقتصادي',
      'التضخم الاقتصادي',
      'تغير مناخي',
      'التغير المناخي',
    ];

    for (final bad in multiWordBanned) {
      final normBad = ArabicTextNormalizer.normalize(bad);
      if (norm.contains(normBad)) {
        return false;
      }
    }

    // استبعاد المفاهيم المجردة والسياسية والتقنية الصعبة
    const singleWordBanned = [
      'ديمقراطيه',
      'اقتصاد',
      'سياسه',
      'عداله',
      'بيروقراطيه',
      'راسماليه',
      'اشتراكيه',
      'عولمه',
      'تضخم',
      'فلسفه',
      'تكنولوجيا',
      'انترنت',
      'برمجه',
      'نسبيه',
      'ميثولوجي',
      'جيوسياسي',
    ];

    for (final token in normTokens) {
      final stripped = (token.length > 3 && token.startsWith('ال')) ? token.substring(2) : token;
      for (final bad in singleWordBanned) {
        final normBad = ArabicTextNormalizer.normalize(bad);
        if (token == normBad || stripped == normBad) {
          return false;
        }
      }
    }

    return true;
  }

  /// جلب مجموعة كلمات قابلة للتمثيل بدون تكرار، مع ضمان عدم نفاد الكلمات إطلاقاً
  Future<List<String>> getCharadesWords({
    required int count,
    String? category,
    BootstrapData? bootstrapData,
    Set<String>? externalSeenHashes,
  }) async {
    final cat = normalizeCharadesCategory(category);
    final localSeen = _storage.getSeenCharadesHashes();
    final allSeen = {...localSeen, ...?externalSeenHashes};

    // 1. تنقية البافر من الكلمات المشاهدة سابقاً
    _charadesBuffer.removeWhere((w) {
      final h = ArabicTextNormalizer.wordHash(w);
      return allSeen.contains(h);
    });

    // 2. فحص prefetch لجلب المزيد في الخلفية
    if (_charadesBuffer.length <= 5) {
      _triggerPrefetchCharades(cat, allSeen);
    }

    final result = <String>[];

    // 3. أخذ من البافر المتاح
    while (_charadesBuffer.isNotEmpty && result.length < count) {
      final candidate = _charadesBuffer.removeAt(0);
      final h = ArabicTextNormalizer.wordHash(candidate);
      if (isActableCharadesWord(candidate) && !allSeen.contains(h) && !result.contains(candidate)) {
        result.add(candidate);
      }
    }

    if (result.length >= count) {
      final hashes = result.map((w) => ArabicTextNormalizer.wordHash(w)).toList();
      await _storage.markCharadesHashesSeen(hashes);
      await _storage.markCharadesWordsSeen(result);
      return result;
    }

    // 4. توليد بالذكاء الاصطناعي لو لسه العدد ناقص مع مهلة 4 ثوانٍ
    try {
      final aiWords = await _ai.generateCharadesWords(
        count: (count - result.length) + 10,
        category: cat,
        avoidWords: localSeen.take(30).toList(),
      ).timeout(const Duration(seconds: 4));

      for (final word in aiWords) {
        final trimmed = word.trim();
        final h = ArabicTextNormalizer.wordHash(trimmed);
        if (isActableCharadesWord(trimmed) &&
            !allSeen.contains(h) &&
            !result.contains(trimmed) &&
            !_charadesBuffer.contains(trimmed)) {
          if (result.length < count) {
            result.add(trimmed);
          } else {
            _charadesBuffer.add(trimmed);
          }
        }
      }
    } catch (_) {
      // لو فشل الـ AI أو بدون إنترنت، نواصل فوراً للمصادر المحلية بدون توقف
    }

    // 5. جلب من بنك الكلمات المحلي للقسم المختار (غير المعروض أولاً)
    final fallbackPool = _getFallbackCharadesWords(cat, bootstrapData);

    if (result.length < count) {
      final unseenFallback = fallbackPool.where((w) {
        final h = ArabicTextNormalizer.wordHash(w);
        return !allSeen.contains(h) && !result.contains(w);
      }).toList()..shuffle(Random());

      for (final w in unseenFallback) {
        result.add(w);
        if (result.length >= count) break;
      }
    }

    // 6. تفضيل الأقدم مشاهدة عند استنزاف الكلمات (FIFO Recycle) مع تلميح للمضيف
    if (result.length < count) {
      hasRecycledCharades = true;
      lastHintMessage = 'اتصل بالإنترنت لمحتوى جديد';

      final seenList = localSeen.toList();
      final seenIndexMap = <String, int>{};
      for (var i = 0; i < seenList.length; i++) {
        seenIndexMap[seenList[i]] = i;
      }

      final seenPool = fallbackPool.where((w) => !result.contains(w)).toList();
      final wordRanks = <String, int>{};
      for (final w in seenPool) {
        wordRanks[w] = seenIndexMap[ArabicTextNormalizer.wordHash(w)] ?? -1;
      }
      seenPool.sort((a, b) => wordRanks[a]!.compareTo(wordRanks[b]!));

      for (final w in seenPool) {
        result.add(w);
        if (result.length >= count) break;
      }
    }

    // إذا كان المطلوب كبيراً جداً، ندمج من البنك الشامل
    if (result.length < count) {
      final allPool = CharadesWordsBank.mixed.where((w) => !result.contains(w)).toList()..shuffle(Random());
      for (final w in allPool) {
        result.add(w);
        if (result.length >= count) break;
      }
    }

    // ضمان نهائي بعدم إرجاع قائمة فارغة
    if (result.isEmpty && fallbackPool.isNotEmpty) {
      final forced = List<String>.from(fallbackPool)..shuffle(Random());
      result.addAll(forced.take(count));
    }

    if (result.isNotEmpty) {
      final hashes = result.map((w) => ArabicTextNormalizer.wordHash(w)).toList();
      await _storage.markCharadesHashesSeen(hashes);
      await _storage.markCharadesWordsSeen(result);
    }

    return result;
  }

  void _triggerPrefetchCharades(String? category, [Set<String>? seenHashes]) {
    if (_isPrefetchingCharades) return;
    _isPrefetchingCharades = true;

    Future.microtask(() async {
      try {
        final cat = normalizeCharadesCategory(category);
        final seen = seenHashes ?? _storage.getSeenCharadesHashes();
        final aiWords = await _ai.generateCharadesWords(
          count: 20,
          category: cat,
          avoidWords: seen.take(30).toList(),
        );

        for (final word in aiWords) {
          final trimmed = word.trim();
          final h = ArabicTextNormalizer.wordHash(trimmed);
          if (isActableCharadesWord(trimmed) &&
              !seen.contains(h) &&
              !_charadesBuffer.contains(trimmed)) {
            _charadesBuffer.add(trimmed);
          }
        }
      } catch (_) {
      } finally {
        _isPrefetchingCharades = false;
      }
    });
  }

  List<String> _getFallbackCharadesWords(String? category, BootstrapData? bootstrapData) {
    final cat = normalizeCharadesCategory(category);
    final list = <String>[];

    // 1. فحص بيانات الـ Bootstrap المخزنة محلياً للفئة المحددة (مع فلتر الجودة)
    if (bootstrapData != null && bootstrapData.charadesCategories.isNotEmpty) {
      for (final c in bootstrapData.charadesCategories) {
        final cSlug = normalizeCharadesCategory(c.slug);
        if (cat == 'mixed' || cSlug == cat) {
          list.addAll(c.words.where((w) => isActableCharadesWord(w)));
        }
      }
    }

    // 2. إذا كانت فارغة أو غير متوفرة، نستخدم بنك الكلمات الشامل للقسم المطلوب
    if (list.isEmpty) {
      list.addAll(CharadesWordsBank.getWordsForCategory(cat));
    }

    // 3. ضمان نهائي بعدم إرجاع قائمة فارغة
    if (list.isEmpty) {
      list.addAll(CharadesWordsBank.mixed);
    }

    return list;
  }

  // ==========================================
  // 4. إعادة ضبط السجل (RESET HISTORY)
  // ==========================================

  /// مسح سجل الأسئلة والكلمات التي لُعبت بالكامل من التخزين والسيرفر
  Future<void> resetAllHistory() async {
    _spyBuffer.clear();
    _triviaBuffer.clear();
    _charadesBuffer.clear();
    hasRecycledTrivia = false;
    hasRecycledSpy = false;
    hasRecycledCharades = false;
    lastHintMessage = null;

    await _storage.clearAllSeenHistory();
    await _api.resetDeviceHistory();
  }
}

final aiQuestionServiceProvider = Provider<AiQuestionService>((ref) {
  return AiQuestionService();
});

final gameContentServiceProvider = Provider<GameContentService>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(localStorageProvider);
  final ai = ref.watch(aiQuestionServiceProvider);
  return GameContentService(api, storage, ai: ai);
});

