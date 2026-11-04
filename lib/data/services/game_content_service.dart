// Lamma - by Mohamed Ibrahim

import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/arabic_text_normalizer.dart';
import '../../core/utils/category_localization.dart';
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
  final String? failureReason;

  const InsufficientTriviaQuestionsException({
    required this.category,
    required this.available,
    required this.requiredCount,
    this.failureReason,
  });

  @override
  String toString() {
    if (failureReason != null && failureReason!.isNotEmpty) {
      return failureReason!;
    }
    final localized = CategoryLocalization.getTriviaCategoryName(category);
    return 'القسم $localized فيه $available سؤال فقط، والمطلوب $requiredCount';
  }
}

class InsufficientSpyWordsException implements Exception {
  final String pack;
  final String? failureReason;

  const InsufficientSpyWordsException({
    required this.pack,
    this.failureReason,
  });

  @override
  String toString() {
    if (failureReason != null && failureReason!.isNotEmpty) {
      return failureReason!;
    }
    final localized = CategoryLocalization.getSpyPackName(pack);
    return 'نفد مخزون الكلمات غير المشاهدة لحزمة $localized';
  }
}

class InsufficientCharadesWordsException implements Exception {
  final String category;
  final String? failureReason;

  const InsufficientCharadesWordsException({
    required this.category,
    this.failureReason,
  });

  @override
  String toString() {
    if (failureReason != null && failureReason!.isNotEmpty) {
      return failureReason!;
    }
    final localized = CategoryLocalization.getCharadesCategoryName(category);
    return 'نفد مخزون الكلمات غير المشاهدة لقسم $localized';
  }
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

  // Room-Scoped Pre-buffered Queues (حجز المحتوى المسبق للغرف لتسريع "العب تاني" إلى أقل من ثانية)
  final Map<String, List<QuestionModel>> _roomPrebufferedTrivia = {};
  final Map<String, List<String>> _roomPrebufferedCharades = {};
  final Map<String, List<Map<String, dynamic>>> _roomPrebufferedSpy = {};
  final Set<String> _activePrebufferTasks = {};

  void setRoomPrebufferedTrivia(String roomCode, List<QuestionModel> questions) {
    _roomPrebufferedTrivia[roomCode.toUpperCase()] = List.from(questions);
  }

  void setRoomPrebufferedCharades(String roomCode, List<String> words) {
    _roomPrebufferedCharades[roomCode.toUpperCase()] = List.from(words);
  }

  void setRoomPrebufferedSpy(String roomCode, List<Map<String, dynamic>> rounds) {
    _roomPrebufferedSpy[roomCode.toUpperCase()] = List.from(rounds);
  }

  bool hasPrebufferedTrivia(String roomCode, int count) {
    final list = _roomPrebufferedTrivia[roomCode.toUpperCase()];
    return list != null && list.length >= count;
  }

  bool hasPrebufferedCharades(String roomCode, int count) {
    final list = _roomPrebufferedCharades[roomCode.toUpperCase()];
    return list != null && list.length >= count;
  }

  bool hasPrebufferedSpy(String roomCode) {
    final list = _roomPrebufferedSpy[roomCode.toUpperCase()];
    return list != null && list.isNotEmpty;
  }

  List<QuestionModel>? consumePrebufferedTrivia(
    String roomCode, {
    int count = 10,
    List<String> categories = const [],
    String difficulty = 'all',
  }) {
    final code = roomCode.toUpperCase();
    final buffered = _roomPrebufferedTrivia[code];
    if (buffered == null || buffered.length < count) return null;

    final consumed = buffered.take(count).toList();
    _roomPrebufferedTrivia[code] = buffered.skip(count).toList();
    return consumed;
  }

  List<String>? consumePrebufferedCharades(String roomCode, {int count = 15}) {
    final code = roomCode.toUpperCase();
    final buffered = _roomPrebufferedCharades[code];
    if (buffered == null || buffered.length < count) return null;

    final consumed = buffered.take(count).toList();
    _roomPrebufferedCharades[code] = buffered.skip(count).toList();
    return consumed;
  }

  Map<String, dynamic>? consumePrebufferedSpyRound(String roomCode) {
    final code = roomCode.toUpperCase();
    final buffered = _roomPrebufferedSpy[code];
    if (buffered == null || buffered.isEmpty) return null;
    return buffered.removeAt(0);
  }

  void clearPrebufferedForRoom(String roomCode) {
    final code = roomCode.toUpperCase();
    _roomPrebufferedTrivia.remove(code);
    _roomPrebufferedCharades.remove(code);
    _roomPrebufferedSpy.remove(code);
  }

  /// تجهيز محتوى الجولة التالية لتحدي الشلة مسبقاً أثناء اللعب
  Future<void> prebufferNextTriviaGame({
    required String roomCode,
    required int count,
    List<String> categories = const [],
    String difficulty = 'all',
    Set<String>? externalSeenPromptHashes,
    Set<String>? externalSeenAnswerHashes,
  }) async {
    final code = roomCode.toUpperCase();
    final taskKey = 'trivia_$code';
    if (_activePrebufferTasks.contains(taskKey)) return;
    _activePrebufferTasks.add(taskKey);

    try {
      final catParam = categories.isNotEmpty && !categories.contains('all') ? categories.join(',') : null;
      final diffParam = difficulty != 'all' && difficulty != 'mixed' ? difficulty : null;

      final batch = await _api.fetchNextRoomQuestionsBatch(
        code,
        count: count,
        categories: catParam,
        difficulty: diffParam,
        excludeHashes: externalSeenPromptHashes?.toList() ?? [],
        excludeAnswerHashes: externalSeenAnswerHashes?.toList() ?? [],
      );

      if (batch.length >= count) {
        setRoomPrebufferedTrivia(code, batch);
      } else {
        final localQuestions = await getTriviaQuestions(
          count: count,
          categories: categories,
          difficulty: difficulty,
          allowAi: true,
          roomCode: code,
          externalSeenPromptHashes: externalSeenPromptHashes,
          externalSeenAnswerHashes: externalSeenAnswerHashes,
        );
        if (localQuestions.length >= count) {
          setRoomPrebufferedTrivia(code, localQuestions);
        }
      }
    } catch (_) {
    } finally {
      _activePrebufferTasks.remove(taskKey);
    }
  }

  // ==========================================
  // AUTO REPLENISHMENT & CONCURRENCY LOCK
  // ==========================================
  final Map<String, Future<void>> _activeGenerationLocks = {};

  int getAvailableTriviaCount({
    List<String> categories = const [],
    String difficulty = 'all',
    String? roomCode,
    Set<String>? externalSeenPromptHashes,
    Set<String>? externalSeenAnswerHashes,
  }) {
    int count = 0;
    if (roomCode != null && roomCode.isNotEmpty) {
      final prebuffered = _roomPrebufferedTrivia[roomCode.toUpperCase()];
      if (prebuffered != null) {
        count += prebuffered.length;
      }
    }

    final localSeenPrompts = _storage.getSeenTriviaPromptHashes();
    final localSeenAnswers = _storage.getSeenTriviaAnswerHashes();
    final seenIds = _storage.getSeenQuestions();
    final allSeenPrompts = {...localSeenPrompts, ...?externalSeenPromptHashes};
    final allSeenAnswers = {...localSeenAnswers, ...?externalSeenAnswerHashes};

    bool matchesCategory(String cat) {
      if (categories.isEmpty || categories.contains('all')) return true;
      final canonicalCat = CategoryLocalization.getTriviaCategoryName(cat);
      for (final t in categories) {
        if (t == cat || t == canonicalCat || CategoryLocalization.getTriviaCategoryName(t) == canonicalCat) {
          return true;
        }
      }
      return false;
    }

    bool matchesDifficulty(String diff) {
      if (difficulty.isEmpty || difficulty == 'all') return true;
      return diff == difficulty;
    }

    for (final q in _triviaBuffer) {
      final pHash = ArabicTextNormalizer.triviaQuestionHash(q.promptAr);
      final aHash = _safeAnswerHash(q);
      if (!allSeenPrompts.contains(pHash) &&
          !allSeenAnswers.contains(aHash) &&
          !(q.id > 0 && seenIds.contains(q.id)) &&
          matchesCategory(q.categorySlug) &&
          matchesDifficulty(q.difficulty)) {
        count++;
      }
    }

    for (final q in kFallbackTriviaQuestions) {
      final pHash = ArabicTextNormalizer.triviaQuestionHash(q.promptAr);
      final aHash = _safeAnswerHash(q);
      if (!allSeenPrompts.contains(pHash) &&
          !allSeenAnswers.contains(aHash) &&
          !(q.id > 0 && seenIds.contains(q.id)) &&
          matchesCategory(q.categorySlug) &&
          matchesDifficulty(q.difficulty)) {
        count++;
      }
    }

    return count;
  }

  bool shouldReplenishTrivia({
    required int requiredCount,
    List<String> categories = const [],
    String difficulty = 'all',
    String? roomCode,
    Set<String>? externalSeenPromptHashes,
    Set<String>? externalSeenAnswerHashes,
  }) {
    final available = getAvailableTriviaCount(
      categories: categories,
      difficulty: difficulty,
      roomCode: roomCode,
      externalSeenPromptHashes: externalSeenPromptHashes,
      externalSeenAnswerHashes: externalSeenAnswerHashes,
    );
    final safetyMargin = requiredCount * 2;
    return available <= (requiredCount + safetyMargin);
  }

  Future<void> autoReplenishTriviaIfNeeded({
    required int requiredCount,
    List<String> categories = const [],
    String difficulty = 'all',
    String? roomCode,
    Set<String>? externalSeenPromptHashes,
    Set<String>? externalSeenAnswerHashes,
    void Function(int current, int target)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final safetyMargin = requiredCount * 2;
    final threshold = requiredCount + safetyMargin;
    final available = getAvailableTriviaCount(
      categories: categories,
      difficulty: difficulty,
      roomCode: roomCode,
      externalSeenPromptHashes: externalSeenPromptHashes,
      externalSeenAnswerHashes: externalSeenAnswerHashes,
    );

    if (available > threshold) return;

    final targetReplenish = threshold - available;
    final key = 'trivia:${categories.join(",")}:$difficulty';

    if (_activeGenerationLocks.containsKey(key)) {
      await _activeGenerationLocks[key];
      return;
    }

    final completer = Completer<void>();
    _activeGenerationLocks[key] = completer.future;

    try {
      final fetched = await getTriviaQuestions(
        count: targetReplenish < 5 ? 5 : targetReplenish,
        categories: categories,
        difficulty: difficulty,
        roomCode: roomCode,
        allowAi: true,
        onProgress: onProgress,
        cancelToken: cancelToken,
        externalSeenPromptHashes: externalSeenPromptHashes,
        externalSeenAnswerHashes: externalSeenAnswerHashes,
      );

      for (final q in fetched) {
        if (!_triviaBuffer.contains(q)) {
          _triviaBuffer.add(q);
        }
      }
      completer.complete();
    } on InsufficientTriviaQuestionsException catch (_) {
      completer.complete();
    } catch (e, st) {
      completer.completeError(e, st);
    } finally {
      _activeGenerationLocks.remove(key);
    }
  }

  int getAvailableCharadesCount({
    String category = 'movies',
    String? roomCode,
    Set<String>? externalSeenHashes,
  }) {
    int count = 0;
    if (roomCode != null && roomCode.isNotEmpty) {
      final prebuffered = _roomPrebufferedCharades[roomCode.toUpperCase()];
      if (prebuffered != null) {
        count += prebuffered.length;
      }
    }

    final cat = normalizeCharadesCategory(category);
    final localSeen = _storage.getSeenCharadesHashes();
    final allSeen = {...localSeen, ...?externalSeenHashes};

    for (final w in _charadesBuffer) {
      final h = ArabicTextNormalizer.wordHash(w);
      if (!allSeen.contains(h) && isActableCharadesWord(w)) {
        count++;
      }
    }

    final pool = CharadesWordsBank.getWordsForCategory(cat);
    for (final w in pool) {
      final h = ArabicTextNormalizer.wordHash(w);
      if (!allSeen.contains(h) && isActableCharadesWord(w)) {
        count++;
      }
    }

    return count;
  }

  bool shouldReplenishCharades({
    required int requiredCount,
    String category = 'movies',
    String? roomCode,
    Set<String>? externalSeenHashes,
  }) {
    final available = getAvailableCharadesCount(
      category: category,
      roomCode: roomCode,
      externalSeenHashes: externalSeenHashes,
    );
    final safetyMargin = requiredCount * 2;
    return available <= (requiredCount + safetyMargin);
  }

  Future<void> autoReplenishCharadesIfNeeded({
    required int requiredCount,
    String category = 'movies',
    String? roomCode,
    Set<String>? externalSeenHashes,
    void Function(int current, int target)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final safetyMargin = requiredCount * 2;
    final threshold = requiredCount + safetyMargin;
    final available = getAvailableCharadesCount(
      category: category,
      roomCode: roomCode,
      externalSeenHashes: externalSeenHashes,
    );

    if (available > threshold) return;

    final targetReplenish = threshold - available;
    final key = 'charades:$category';

    if (_activeGenerationLocks.containsKey(key)) {
      await _activeGenerationLocks[key];
      return;
    }

    final completer = Completer<void>();
    _activeGenerationLocks[key] = completer.future;

    try {
      final fetched = await getCharadesWords(
        count: targetReplenish < 5 ? 5 : targetReplenish,
        category: category,
        roomCode: roomCode,
        externalSeenHashes: externalSeenHashes,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );

      for (final w in fetched) {
        if (!_charadesBuffer.contains(w)) {
          _charadesBuffer.add(w);
        }
      }
      completer.complete();
    } catch (e, st) {
      completer.completeError(e, st);
    } finally {
      _activeGenerationLocks.remove(key);
    }
  }

  int getAvailableSpyCount({
    String packSlug = 'places',
    String difficulty = 'medium',
    String? roomCode,
  }) {
    int count = 0;
    if (roomCode != null && roomCode.isNotEmpty) {
      final prebuffered = _roomPrebufferedSpy[roomCode.toUpperCase()];
      if (prebuffered != null) {
        count += prebuffered.length;
      }
    }

    final localSeen = _storage.getSeenSpyHashes();

    for (final w in _spyBuffer) {
      final h = ArabicTextNormalizer.wordHash(w);
      if (!localSeen.contains(h)) {
        count++;
      }
    }

    final normPack = (packSlug == 'food' || packSlug == 'foods') ? 'food' : packSlug;
    final List<String> pool;
    if (normPack == 'mixed') {
      pool = kFallbackSpyPacks.values.expand((element) => element).toList();
    } else {
      pool = kFallbackSpyPacks[normPack] ?? [];
    }
    for (final w in pool) {
      final h = ArabicTextNormalizer.wordHash(w);
      if (!localSeen.contains(h)) {
        count++;
      }
    }

    return count;
  }

  bool shouldReplenishSpy({
    required int requiredCount,
    String packSlug = 'places',
    String difficulty = 'medium',
    String? roomCode,
  }) {
    final available = getAvailableSpyCount(
      packSlug: packSlug,
      difficulty: difficulty,
      roomCode: roomCode,
    );
    final safetyMargin = requiredCount * 2;
    return available <= (requiredCount + safetyMargin);
  }

  Future<void> autoReplenishSpyIfNeeded({
    required int requiredCount,
    String packSlug = 'places',
    String difficulty = 'medium',
    String? roomCode,
    void Function(int current, int target)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final safetyMargin = requiredCount * 2;
    final threshold = requiredCount + safetyMargin;
    final available = getAvailableSpyCount(
      packSlug: packSlug,
      difficulty: difficulty,
      roomCode: roomCode,
    );

    if (available > threshold) return;

    final targetReplenish = threshold - available;
    final key = 'spy:$packSlug:$difficulty';

    if (_activeGenerationLocks.containsKey(key)) {
      await _activeGenerationLocks[key];
      return;
    }

    final completer = Completer<void>();
    _activeGenerationLocks[key] = completer.future;

    try {
      final rawItems = await _api.generateAiContent(
        gameType: 'spy',
        category: (packSlug == 'food') ? 'foods' : packSlug,
        count: targetReplenish < 5 ? 5 : targetReplenish,
        cancelToken: cancelToken,
      ).timeout(const Duration(seconds: 22));

      final localSeen = _storage.getSeenSpyHashes();
      for (final item in rawItems) {
        final w = (item['word_ar'] ?? item['word'] ?? item['prompt_ar'] ?? '').toString().trim();
        if (w.isEmpty) continue;
        final h = ArabicTextNormalizer.wordHash(w);
        if (!localSeen.contains(h) && !_spyBuffer.contains(w)) {
          _spyBuffer.add(w);
        }
      }
      completer.complete();
    } catch (e, st) {
      completer.completeError(e, st);
    } finally {
      _activeGenerationLocks.remove(key);
    }
  }

  /// تجهيز محتوى الجولة التالية لمثّل ومتتكلمش مسبقاً أثناء اللعب
  Future<void> prebufferNextCharadesGame({
    required String roomCode,
    required int count,
    String category = 'movies',
    Set<String>? externalSeenHashes,
  }) async {
    final code = roomCode.toUpperCase();
    final taskKey = 'charades_$code';
    if (_activePrebufferTasks.contains(taskKey)) return;
    _activePrebufferTasks.add(taskKey);

    try {
      final batch = await _api.fetchNextCharadesBatch(
        code,
        count: count,
        category: category,
        excludeWords: externalSeenHashes?.toList() ?? [],
      );

      if (batch.length >= count) {
        setRoomPrebufferedCharades(code, batch);
      } else {
        final localWords = await getCharadesWords(
          count: count,
          category: category,
          externalSeenHashes: externalSeenHashes,
        );
        if (localWords.length >= count) {
          setRoomPrebufferedCharades(code, localWords);
        }
      }
    } catch (_) {
    } finally {
      _activePrebufferTasks.remove(taskKey);
    }
  }

  /// تجهيز محتوى الجولة التالية لمين الجاسوس مسبقاً أثناء اللعب
  Future<void> prebufferNextSpyGame({
    required String roomCode,
    required int rounds,
    String packSlug = 'places',
  }) async {
    final code = roomCode.toUpperCase();
    final taskKey = 'spy_$code';
    if (_activePrebufferTasks.contains(taskKey)) return;
    _activePrebufferTasks.add(taskKey);

    try {
      final batch = await _api.fetchNextSpyBatch(
        code,
        rounds: rounds,
        packSlug: packSlug,
      );

      if (batch.length >= rounds) {
        setRoomPrebufferedSpy(code, batch);
      }
    } catch (_) {
    } finally {
      _activePrebufferTasks.remove(taskKey);
    }
  }

  GameContentService(
    this._api,
    this._storage, {
    AiQuestionService? ai,
  }) : _ai = ai ?? AiQuestionService(storage: _storage);

  List<QuestionModel> get triviaBuffer => List.unmodifiable(_triviaBuffer);
  List<String> get spyBuffer => List.unmodifiable(_spyBuffer);
  List<String> get charadesBuffer => List.unmodifiable(_charadesBuffer);

  String _safeAnswerHash(QuestionModel q) {
    final opt = (q.correctIndex >= 0 && q.correctIndex < q.options.length)
        ? q.options[q.correctIndex]
        : (q.saltedHash ?? '');
    return ArabicTextNormalizer.triviaAnswerHash(q.categorySlug, opt);
  }

  /// عدد العناصر الجاهزة في المخزون المؤقت المطابقة للمعايير وغير المشاهدة
  int getStockCount(String gameType, {String? category, String? difficulty}) {
    if (gameType == 'trivia') {
      final seenPrompts = _storage.getSeenTriviaPromptHashes();
      final seenAnswers = _storage.getSeenTriviaAnswerHashes();
      return _triviaBuffer.where((q) {
        if (category != null && category != 'all' && q.categorySlug != category) return false;
        if (difficulty != null && difficulty != 'all' && q.difficulty != difficulty) return false;
        final pHash = ArabicTextNormalizer.triviaQuestionHash(q.promptAr);
        final aHash = _safeAnswerHash(q);
        return !seenPrompts.contains(pHash) && !seenAnswers.contains(aHash);
      }).length;
    } else if (gameType == 'spy') {
      final seenHashes = _storage.getSeenSpyHashes();
      return _spyBuffer.where((w) {
        final h = ArabicTextNormalizer.wordHash(w);
        return !seenHashes.contains(h);
      }).length;
    } else {
      final seenHashes = _storage.getSeenCharadesHashes();
      return _charadesBuffer.where((w) {
        final h = ArabicTextNormalizer.wordHash(w);
        return !seenHashes.contains(h);
      }).length;
    }
  }

  /// استهلاك فوري للأسئلة الجاهزة في المخزون المسبق
  List<QuestionModel> takeStockTrivia({
    required int count,
    String? category,
    String? difficulty,
    Set<String>? externalSeenPromptHashes,
    Set<String>? externalSeenAnswerHashes,
  }) {
    final localSeenPrompts = _storage.getSeenTriviaPromptHashes();
    final localSeenAnswers = _storage.getSeenTriviaAnswerHashes();
    final allSeenPrompts = {...localSeenPrompts, ...?externalSeenPromptHashes};
    final allSeenAnswers = {...localSeenAnswers, ...?externalSeenAnswerHashes};

    final taken = <QuestionModel>[];
    final remaining = <QuestionModel>[];

    for (final q in _triviaBuffer) {
      if (taken.length < count) {
        if (category != null && category != 'all' && q.categorySlug != category) {
          remaining.add(q);
          continue;
        }
        if (difficulty != null && difficulty != 'all' && q.difficulty != difficulty) {
          remaining.add(q);
          continue;
        }
        final pHash = ArabicTextNormalizer.triviaQuestionHash(q.promptAr);
        final aHash = _safeAnswerHash(q);
        if (!allSeenPrompts.contains(pHash) &&
            !allSeenAnswers.contains(aHash) &&
            !taken.any((t) => ArabicTextNormalizer.isSimilar(t.promptAr, q.promptAr, threshold: 0.70))) {
          taken.add(q);
          continue;
        }
      }
      remaining.add(q);
    }

    _triviaBuffer.clear();
    _triviaBuffer.addAll(remaining);

    if (_triviaBuffer.length <= 6) {
      final cats = category != null && category != 'all' ? [category] : <String>[];
      _triggerPrefetchTrivia(cats, difficulty);
    }

    return taken;
  }

  /// استهلاك فوري لكلمات الجاسوس أو التمثيل من المخزون المسبق
  List<String> takeStockWords(
    String gameType, {
    required int count,
    String? category,
    Set<String>? externalSeenHashes,
  }) {
    final isSpy = gameType == 'spy';
    final buffer = isSpy ? _spyBuffer : _charadesBuffer;
    final localSeen = isSpy ? _storage.getSeenSpyHashes() : _storage.getSeenCharadesHashes();
    final allSeen = {...localSeen, ...?externalSeenHashes};

    final taken = <String>[];
    final remaining = <String>[];

    for (final w in buffer) {
      if (taken.length < count) {
        final h = ArabicTextNormalizer.wordHash(w);
        if (!allSeen.contains(h) &&
            !taken.any((t) => ArabicTextNormalizer.isSimilar(t, w, threshold: 0.75))) {
          taken.add(w);
          continue;
        }
      }
      remaining.add(w);
    }

    buffer.clear();
    buffer.addAll(remaining);

    if (buffer.length <= 6) {
      if (isSpy) {
        _triggerPrefetchSpy(category ?? 'places', null, allSeen);
      } else {
        _triggerPrefetchCharades(category ?? 'movies', allSeen);
      }
    }

    return taken;
  }

  /// التجديد التلقائي للمخزون المسبق عند فتح التطبيق
  Future<void> prefetchStartup() async {
    Future.microtask(() async {
      try {
        final triviaSettings = _storage.getSavedTriviaSettings();
        final cats = (triviaSettings?['categories'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['movies', 'sports'];
        final diff = (triviaSettings?['difficulty'] as String?) ?? 'all';
        if (_triviaBuffer.length < 15) {
          _triggerPrefetchTrivia(cats, diff);
        }

        final spySettings = _storage.getSavedSpySettings();
        final pack = (spySettings?['wordPack'] as String?) ?? 'places';
        if (_spyBuffer.length < 15) {
          _triggerPrefetchSpy(pack, null);
        }

        final charadesSettings = _storage.getSavedCharadesSettings();
        final charCat = (charadesSettings?['category'] as String?) ?? 'movies';
        if (_charadesBuffer.length < 15) {
          _triggerPrefetchCharades(charCat);
        }
      } catch (_) {}
    });
  }

  /// التجديد التلقائي للمخزون المسبق عند دخول اللوبي
  Future<void> prefetchLobby(
    String gameType, {
    Map<String, dynamic>? settings,
    Set<String>? externalSeenHashes,
  }) async {
    Future.microtask(() async {
      try {
        if (gameType == 'trivia') {
          if (_triviaBuffer.length <= 10) {
            final cats = (settings?['categories'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
            final diff = (settings?['difficulty'] as String?) ?? 'all';
            _triggerPrefetchTrivia(cats, diff);
          }
        } else if (gameType == 'spy') {
          if (_spyBuffer.length <= 10) {
            final pack = (settings?['wordPack'] as String?) ?? 'places';
            _triggerPrefetchSpy(pack, null, externalSeenHashes);
          }
        } else if (gameType == 'charades') {
          if (_charadesBuffer.length <= 10) {
            final cat = (settings?['category'] as String?) ?? 'movies';
            _triggerPrefetchCharades(cat, externalSeenHashes);
          }
        }
      } catch (_) {}
    });
  }

  void addGeneratedTriviaQuestions(List<QuestionModel> questions) {
    for (final q in questions) {
      if (!_triviaBuffer.any((b) =>
          ArabicTextNormalizer.areEqual(b.promptAr, q.promptAr) ||
          ArabicTextNormalizer.isSimilar(b.promptAr, q.promptAr, threshold: 0.70))) {
        _triviaBuffer.add(q);
      }
    }
  }

  void addGeneratedSpyWords(List<String> words) {
    for (final w in words) {
      if (!_spyBuffer.any((b) =>
          ArabicTextNormalizer.areEqual(b, w) ||
          ArabicTextNormalizer.isSimilar(b, w, threshold: 0.75))) {
        _spyBuffer.add(w);
      }
    }
  }

  void addGeneratedCharadesWords(List<String> words) {
    for (final w in words) {
      if (!_charadesBuffer.any((b) =>
          ArabicTextNormalizer.areEqual(b, w) ||
          ArabicTextNormalizer.isSimilar(b, w, threshold: 0.75))) {
        _charadesBuffer.add(w);
      }
    }
  }


  // ==========================================
  // تسجيل المشاهدة لحظة التقديم الفعلي (Live Presentation Recording)
  // ==========================================

  /// تسجيل تقديم سؤال لتحدي الشلة لحظة عرضه الفعلي للاعبين
  Future<void> markTriviaQuestionPresented(
    QuestionModel q, {
    dynamic roomServer,
    ApiClient? api,
  }) async {
    final pHash = ArabicTextNormalizer.triviaQuestionHash(q.promptAr);
    final aHash = _safeAnswerHash(q);
    await _storage.markTriviaHashesSeen(promptHashes: [pHash], answerHashes: [aHash]);
    await _storage.markTriviaQuestionTextsSeen([q.promptAr]);
    if (q.id > 0) {
      await _storage.markQuestionsSeen([q.id]);
      try {
        await (api ?? _api).markQuestionsSeen([q.id]);
      } catch (_) {}
    }
    roomServer?.recordSeenTriviaAcrossRoom([pHash], [aHash]);
  }

  /// تسجيل تقديم كلمة للتمثيل لحظة عرضها الفعلي للاعب
  Future<void> markCharadesWordPresented(
    String word, {
    dynamic roomServer,
  }) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return;
    final h = ArabicTextNormalizer.wordHash(trimmed);
    await _storage.markCharadesHashesSeen([h]);
    await _storage.markCharadesWordsSeen([trimmed]);
    roomServer?.recordSeenCharadesAcrossRoom([h]);
  }

  /// تسجيل تقديم جولة مين الجاسوس (الكلمة والخيارات) لحظة بدئها
  Future<void> markSpyRoundPresented(
    String secretWord, {
    List<String> spyChoices = const [],
    dynamic roomServer,
  }) async {
    final trimmed = secretWord.trim();
    if (trimmed.isEmpty) return;
    final wHash = ArabicTextNormalizer.wordHash(trimmed);
    final allHashes = <String>[wHash];
    final allWords = <String>[trimmed];
    for (final choice in spyChoices) {
      final cTrim = choice.trim();
      if (cTrim.isNotEmpty) {
        allHashes.add(ArabicTextNormalizer.wordHash(cTrim));
        allWords.add(cTrim);
      }
    }
    await _storage.markSpyHashesSeen(allHashes);
    await _storage.markSpyWordsSeen(allWords);
    if (roomServer != null) {
      for (final h in allHashes) {
        roomServer.recordSeenSpyAcrossRoom(h);
      }
    }
  }

  // ==========================================
  // 1. مين الجاسوس (SPY GAME)
  // ==========================================

  Future<String?> getNextSpyWord({
    required String packSlug,
    BootstrapData? bootstrapData,
    Set<String>? externalSeenHashes,
    String? previousWord,
    String? roomCode,
    CancelToken? cancelToken,
  }) async {
    // 0. التحقق من التجهيز المسبق المحجوز للغرفة
    if (roomCode != null && roomCode.isNotEmpty) {
      final prebuffered = consumePrebufferedSpyRound(roomCode);
      if (prebuffered != null) {
        final secWord = prebuffered['secret_word'] as String?;
        if (secWord != null && secWord.isNotEmpty) {
          return secWord;
        }
      }
    }

    final localSeen = _storage.getSeenSpyHashes();
    final allSeen = {...localSeen, ...?externalSeenHashes};

    // 1. تنقية البافر من أي كلمات شوهدت سابقاً أو تطابق الكلمة السابقة
    _spyBuffer.removeWhere((w) {
      final h = ArabicTextNormalizer.wordHash(w);
      return allSeen.contains(h) ||
          (previousWord != null && ArabicTextNormalizer.areEqual(w, previousWord));
    });

    // 2. فحص prefetch في الخلفية
    if (_spyBuffer.length <= 5) {
      _triggerPrefetchSpy(packSlug, bootstrapData, allSeen);
    }

    // 3. لو البافر فيه كلمة متاحة
    if (_spyBuffer.isNotEmpty) {
      final picked = _spyBuffer.removeAt(0);
      return picked;
    }

    // 4. محاولة التوليد عبر Backend Proxy مع مهلة 22 ثانية
    try {
      final rawItems = await _api.generateAiContent(
        gameType: 'spy',
        category: (packSlug == 'food') ? 'foods' : packSlug,
        count: 15,
        excludeItems: localSeen.take(30).toList(),
        cancelToken: cancelToken,
      ).timeout(const Duration(seconds: 22));

      for (final item in rawItems) {
        final w = (item['word_ar'] ?? item['word'] ?? item['prompt_ar'] ?? '').toString().trim();
        if (w.isEmpty) continue;
        final h = ArabicTextNormalizer.wordHash(w);
        final matchesPrev = previousWord != null && ArabicTextNormalizer.areEqual(w, previousWord);
        if (!allSeen.contains(h) &&
            !matchesPrev &&
            !_spyBuffer.any((b) => ArabicTextNormalizer.areEqual(b, w))) {
          _spyBuffer.add(w);
        }
      }
    } catch (_) {}

    if (_spyBuffer.isNotEmpty) {
      final picked = _spyBuffer.removeAt(0);
      return picked;
    }

    // 5. Fallback لبنك المحتوى المحلي (الكلمات غير المشاهدة أولاً وغير المطابقة للكلمة السابقة)
    final fallbackList = _getFallbackSpyWords(packSlug, bootstrapData);
    final unseenFallback = fallbackList.where((w) {
      final h = ArabicTextNormalizer.wordHash(w);
      final matchesPrev = previousWord != null && ArabicTextNormalizer.areEqual(w, previousWord);
      return !allSeen.contains(h) && !matchesPrev;
    }).toList();

    if (unseenFallback.isNotEmpty) {
      unseenFallback.shuffle(Random());
      final picked = unseenFallback.first;
      return picked;
    }

    // 6. ممنوع التدوير الصامت للأقدم مشاهدة عند النفاد
    return null;
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
    final normPack = (packSlug == 'foods' || packSlug == 'food') ? 'food' : packSlug;
    final list = <String>[];
    if (bootstrapData != null) {
      for (final pack in bootstrapData.spyPacks) {
        final pSlug = (pack.slug == 'foods' || pack.slug == 'food') ? 'food' : pack.slug;
        if (pSlug == normPack || normPack == 'mixed') {
          list.addAll(pack.words);
        }
      }
    }
    if (list.isEmpty) {
      if (normPack == 'mixed') {
        kFallbackSpyPacks.values.forEach(list.addAll);
      } else if (kFallbackSpyPacks.containsKey(normPack)) {
        list.addAll(kFallbackSpyPacks[normPack]!);
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
    String? roomCode,
    Set<String>? externalSeenPromptHashes,
    Set<String>? externalSeenAnswerHashes,
    void Function(int current, int target)? onProgress,
    CancelToken? cancelToken,
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

    // دالة تحقق صارمة من مطابقة القسم مع دعم الأسماء البديلة والمعربة
    bool matchesCategory(String cat) {
      if (targetCategories.isEmpty || targetCategories.contains('all')) return true;
      final canonicalCat = CategoryLocalization.getTriviaCategoryName(cat);
      for (final t in targetCategories) {
        if (t == cat || t == canonicalCat || CategoryLocalization.getTriviaCategoryName(t) == canonicalCat) {
          return true;
        }
      }
      return false;
    }

    // دالة تحقق صارمة من مطابقة الصعوبة
    bool matchesDifficulty(String diff) {
      if (difficulty.isEmpty || difficulty == 'all') return true;
      return diff == difficulty;
    }

    bool isAllowed(QuestionModel q, List<QuestionModel> currentResult) {
      if (!matchesCategory(q.categorySlug) || !matchesDifficulty(q.difficulty)) return false;
      final pHash = ArabicTextNormalizer.triviaQuestionHash(q.promptAr);
      final aHash = _safeAnswerHash(q);

      if (allSeenPrompts.contains(pHash) || allSeenAnswers.contains(aHash)) return false;
      if (q.id > 0 && seenIds.contains(q.id)) return false;

      if (currentResult.any((r) {
        final rpHash = ArabicTextNormalizer.triviaQuestionHash(r.promptAr);
        final raHash = _safeAnswerHash(r);
        if (rpHash == pHash || raHash == aHash) return true;
        return ArabicTextNormalizer.isSimilar(r.promptAr, q.promptAr, threshold: 0.70);
      })) {
        return false;
      }
      return true;
    }

    final result = <QuestionModel>[];

    // 0. التحقق من التجهيز المسبق المحجوز للغرفة (Zero-latency Instant Play Again)
    if (roomCode != null && roomCode.isNotEmpty) {
      final prebuffered = consumePrebufferedTrivia(
        roomCode,
        count: count,
        categories: targetCategories,
        difficulty: difficulty,
      );
      if (prebuffered != null && prebuffered.length >= count) {
        // إطلاق تجهيز مسبق في الخلفية للعبة التالية فوراً
        unawaited(prebufferNextTriviaGame(
          roomCode: roomCode,
          count: count,
          categories: targetCategories,
          difficulty: difficulty,
          externalSeenPromptHashes: externalSeenPromptHashes,
          externalSeenAnswerHashes: externalSeenAnswerHashes,
        ));
        return prebuffered;
      }
    }

    // جلب من خادم الجلسة المركزي للغرفة بدفعة واحدة فائقة السرعة أولاً
    if (roomCode != null && roomCode.isNotEmpty) {
      try {
        final catParam = targetCategories.isNotEmpty && !targetCategories.contains('all')
            ? targetCategories.join(',')
            : null;

        final batch = await _api.fetchNextRoomQuestionsBatch(
          roomCode,
          count: count,
          categories: catParam,
          difficulty: difficulty != 'all' ? difficulty : null,
          excludeHashes: allSeenPrompts.toList(),
          excludeAnswerHashes: allSeenAnswers.toList(),
        );

        for (final q in batch) {
          if (isAllowed(q, result)) {
            result.add(q);
          }
        }

        // إذا كان هناك نقص طفيف نكمل بالسؤال الفردي
        if (result.length < count) {
          int attempts = 0;
          final maxAttempts = (count - result.length) * 2;
          while (result.length < count && attempts < maxAttempts) {
            attempts++;
            final q = await _api.fetchNextRoomQuestion(
              roomCode,
              categories: catParam,
              difficulty: difficulty != 'all' ? difficulty : null,
              excludeHashes: allSeenPrompts.toList(),
              excludeAnswerHashes: allSeenAnswers.toList(),
            );
            if (q == null) break;
            if (isAllowed(q, result)) {
              result.add(q);
            }
          }
        }
      } catch (_) {}
    }

    if (result.length >= count) {
      return result.take(count).toList();
    }

    // 1. تنقية البافر
    _triviaBuffer.removeWhere((q) {
      final pHash = ArabicTextNormalizer.triviaQuestionHash(q.promptAr);
      final aHash = _safeAnswerHash(q);
      return allSeenPrompts.contains(pHash) || allSeenAnswers.contains(aHash) || (q.id > 0 && seenIds.contains(q.id));
    });

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
      return result.take(count).toList();
    }

    // 3. توليد بالذكاء الاصطناعي (AI) دفعة جديدة مع إعادة المحاولة حتى 3 مرات للعدد الناقص
    String? lastAiError;
    if (result.length < count && allowAi) {
      int retryCount = 0;
      while (result.length < count && retryCount < 3) {
        if (cancelToken != null && cancelToken.isCancelled) {
          throw const AiCancelledException();
        }
        retryCount++;
        try {
          final missing = count - result.length;
          final batchCount = missing < 5 ? 5 : (missing + 3);

          List<QuestionModel> aiQuestions = [];

          // فحص ApiClient أولاً مع مهلة كافية 22 ثانية
          try {
            final rawItems = await _api.generateAiContent(
              gameType: 'trivia',
              categories: targetCategories.isNotEmpty && !targetCategories.contains('all')
                  ? targetCategories
                  : null,
              difficulty: difficulty,
              count: batchCount,
              excludeItems: result.map((r) => r.promptAr).take(20).toList(),
              cancelToken: cancelToken,
            ).timeout(const Duration(seconds: 22));

            if (rawItems.isNotEmpty) {
              for (var i = 0; i < rawItems.length; i++) {
                final item = rawItems[i];
                final prompt = (item['prompt_ar'] ?? item['prompt']) as String?;
                final options = (item['options'] as List<dynamic>?)
                    ?.map((e) => e.toString().trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                final correctIndex = item['correct_index'] as int? ?? 0;
                final rawCat = (item['category_slug'] ?? item['category']) as String?;
                final itemCat = CategoryLocalization.canonicalTriviaSlug(
                  rawCat ?? (targetCategories.isNotEmpty ? targetCategories.first : 'general'),
                );
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
          } catch (e) {
            if (e is AiCancelledException) rethrow;
            if (e is AiNoInternetException) {
              lastAiError = 'لا يوجد اتصال بالإنترنت لتجهيز أسئلة جديدة في قسم ${CategoryLocalization.getTriviaCategoriesLabel(targetCategories)}';
            } else if (e is AiRateLimitException) {
              lastAiError = 'تم تجاوز حد الاستخدام المتاح للذكاء الاصطناعي مؤقتاً';
            } else if (e is AiTimeoutException) {
              lastAiError = 'انتهت مهلة الاتصال بالخادم أثناء تجهيز أسئلة قسم ${CategoryLocalization.getTriviaCategoriesLabel(targetCategories)}';
            } else if (e is AiServiceException || e is AiInvalidKeyException) {
              lastAiError = 'حدث خطأ من الخادم أثناء توليد أسئلة قسم ${CategoryLocalization.getTriviaCategoriesLabel(targetCategories)}';
            } else if (e is DioException) {
              if (e.type == DioExceptionType.cancel) throw const AiCancelledException();
              if (e.type == DioExceptionType.connectionTimeout ||
                  e.type == DioExceptionType.receiveTimeout ||
                  e.type == DioExceptionType.sendTimeout) {
                lastAiError = 'انتهت مهلة الاتصال بالخادم أثناء تجهيز أسئلة قسم ${CategoryLocalization.getTriviaCategoriesLabel(targetCategories)}';
              } else if (e.type == DioExceptionType.connectionError) {
                lastAiError = 'لا يوجد اتصال بالإنترنت لتجهيز أسئلة جديدة في قسم ${CategoryLocalization.getTriviaCategoriesLabel(targetCategories)}';
              } else if (e.response?.statusCode == 429) {
                lastAiError = 'تم تجاوز حد الاستخدام المتاح للذكاء الاصطناعي مؤقتاً';
              } else {
                lastAiError = 'حدث خطأ من الخادم أثناء توليد أسئلة قسم ${CategoryLocalization.getTriviaCategoriesLabel(targetCategories)}';
              }
            } else if (e is TimeoutException) {
              lastAiError = 'انتهت مهلة تجهيز الأسئلة في قسم ${CategoryLocalization.getTriviaCategoriesLabel(targetCategories)}';
            }
          }

          for (final q in aiQuestions) {
            if (isAllowed(q, result)) {
              if (result.length < count) {
                result.add(q);
                onProgress?.call(result.length, count);
              } else {
                _triviaBuffer.add(q);
              }
            }
          }
        } catch (e) {
          if (e is AiCancelledException) rethrow;
          break; // في حالة انقطاع الإنترنت أو الخطأ، التحول فوراً للمصادر المحلية
        }
      }
    }

    if (result.length >= count) {
      return result.take(count).toList();
    }

    // 4. Fallback لبنك الأسئلة المحلي (غير المعروض أولاً)
    final candidates = <QuestionModel>[...kFallbackTriviaQuestions];

    final matchingUnseen = candidates.where((q) => isAllowed(q, result)).toList();
    matchingUnseen.shuffle(Random());

    for (final q in matchingUnseen) {
      result.add(q);
      onProgress?.call(result.length, count);
      if (result.length >= count) break;
    }

    if (result.length >= count) {
      return result.take(count).toList();
    }

    // 5. في حالة نفاد الأسئلة غير المعروضة بالكامل:
    final categoryLabel = CategoryLocalization.getTriviaCategoriesLabel(targetCategories);
    throw InsufficientTriviaQuestionsException(
      category: categoryLabel,
      available: result.length,
      requiredCount: count,
      failureReason: lastAiError,
    );
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
    if (pool.length < count && targetCategories.isEmpty) {
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
        final rawItems = await _api.generateAiContent(
          gameType: 'trivia',
          categories: targetCategories.isNotEmpty && !targetCategories.contains('all') ? targetCategories : null,
          difficulty: difficulty != 'all' ? difficulty : null,
          count: 15,
        );

        final aiQuestions = <QuestionModel>[];
        for (int i = 0; i < rawItems.length; i++) {
          final item = rawItems[i];
          final prompt = (item['prompt_ar'] ?? item['prompt']) as String?;
          final optionsRaw = item['options'] as List<dynamic>?;
          final options = optionsRaw?.map((e) => e.toString().trim()).toList();
          final correctIndex = int.tryParse(item['correct_index']?.toString() ?? '0') ?? 0;
          final itemCat = (item['category_slug'] ?? item['category'] ?? 'general').toString();
          final itemDiff = (item['difficulty'] ?? 'medium').toString();

          if (prompt != null && prompt.trim().length >= 5 && options != null && options.length == 4) {
            aiQuestions.add(QuestionModel(
              id: -1 * (DateTime.now().millisecondsSinceEpoch % 1000000 + i + 1),
              categoryId: 1,
              categorySlug: itemCat,
              type: 'mcq',
              promptAr: prompt.trim(),
              options: options,
              correctIndex: correctIndex,
              difficulty: itemDiff,
              explanationAr: item['explanation_ar'] as String?,
              source: 'backend_ai',
            ));
          }
        }

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

    // استبعاد الأرقام (أرقام عربية أو لاتينية) منعاً للمفاهيم والمصطلحات الرقمية
    if (RegExp(r'[0-9\u0660-\u0669]').hasMatch(trimmed)) return false;

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
      'حبل مشنقه',
      'حبل المشنقه',
      'ابن القاضي شنق نفسه',
    ];

    for (final bad in multiWordBanned) {
      final normBad = ArabicTextNormalizer.normalize(bad);
      if (norm.contains(normBad)) {
        return false;
      }
    }

    // استبعاد المفاهيم المجردة والسياسية والتقنية والمحتوى المسيء
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
      'جيجا',
      'ميجا',
      'تيرابايت',
      'سيرفر',
      'خوارزميه',
      'هاكر',
      'سوفتوير',
      'هاردوير',
      'مشنقه',
      'شنق',
      'انتحار',
      'صبر',
      'تاني',
      'ضمير',
      'خلود',
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

  Future<List<String>> getCharadesWords({
    required int count,
    String? category,
    BootstrapData? bootstrapData,
    Set<String>? externalSeenHashes,
    String? roomCode,
    void Function(int current, int target)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final cat = normalizeCharadesCategory(category);

    // 0. التحقق من التجهيز المسبق المحجوز للغرفة
    if (roomCode != null && roomCode.isNotEmpty) {
      final prebuffered = consumePrebufferedCharades(roomCode, count: count);
      if (prebuffered != null && prebuffered.length >= count) {
        unawaited(prebufferNextCharadesGame(roomCode: roomCode, count: count, category: cat, externalSeenHashes: externalSeenHashes));
        return prebuffered;
      }
    }

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
        onProgress?.call(result.length, count);
      }
    }

    if (result.length >= count) {
      return result;
    }

    // 4. توليد بالذكاء الاصطناعي عبر Backend Proxy لو لسه العدد ناقص مع مهلة 22 ثانية
    try {
      final rawItems = await _api.generateAiContent(
        gameType: 'charades',
        category: cat,
        count: (count - result.length) + 10,
        excludeItems: localSeen.take(30).toList(),
        cancelToken: cancelToken,
      ).timeout(const Duration(seconds: 22));

      final aiWords = rawItems
          .map((item) => (item['word_ar'] ?? item['word'] ?? item['prompt_ar'] ?? '').toString())
          .where((w) => w.trim().isNotEmpty)
          .toList();

      for (final word in aiWords) {
        final trimmed = word.trim();
        final h = ArabicTextNormalizer.wordHash(trimmed);
        if (isActableCharadesWord(trimmed) &&
            !allSeen.contains(h) &&
            !result.contains(trimmed) &&
            !_charadesBuffer.contains(trimmed)) {
          if (result.length < count) {
            result.add(trimmed);
            onProgress?.call(result.length, count);
          } else {
            _charadesBuffer.add(trimmed);
          }
        }
      }
    } catch (e) {
      if (e is AiCancelledException) rethrow;
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

    // إذا كان المطلوب كبيراً جداً، ندمج من البنك الشامل الكلمات غير المشاهدة فقط إذا كانت الفئة مختلطة mixed
    if (result.length < count && cat == 'mixed') {
      final allPool = CharadesWordsBank.mixed.where((w) {
        final h = ArabicTextNormalizer.wordHash(w);
        return !allSeen.contains(h) && !result.contains(w);
      }).toList()..shuffle(Random());
      for (final w in allPool) {
        result.add(w);
        if (result.length >= count) break;
      }
    }

    // إذا استُهلكت جميع الكلمات غير المشاهدة محلياً للقسم،
    // نملأ النقص بإعادة تدوير كلمات نفس القسم فقط
    if (result.length < count) {
      final fallbackPool = _getFallbackCharadesWords(cat, bootstrapData)..shuffle(Random());
      for (final w in fallbackPool) {
        if (!result.contains(w) && isActableCharadesWord(w)) {
          result.add(w);
          if (result.length >= count) break;
        }
      }
    }

    if (result.length < count && cat == 'mixed') {
      final mixedPool = CharadesWordsBank.mixed..shuffle(Random());
      for (final w in mixedPool) {
        if (!result.contains(w) && isActableCharadesWord(w)) {
          result.add(w);
          if (result.length >= count) break;
        }
      }
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
        final rawItems = await _api.generateAiContent(
          gameType: 'charades',
          category: cat,
          count: 20,
          excludeItems: seen.take(30).toList(),
        );

        final aiWords = rawItems
            .map((item) => (item['word_ar'] ?? item['word'] ?? item['prompt_ar'] ?? '').toString())
            .where((w) => w.trim().isNotEmpty)
            .toList();

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

    // 3. ضمان نهائي بعدم إرجاع قائمة فارغة فقط إذا كانت الفئة مختلطة mixed
    if (list.isEmpty && cat == 'mixed') {
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
  final storage = ref.watch(localStorageProvider);
  return AiQuestionService(storage: storage);
});

final gameContentServiceProvider = Provider<GameContentService>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(localStorageProvider);
  final ai = ref.watch(aiQuestionServiceProvider);
  return GameContentService(api, storage, ai: ai);
});

