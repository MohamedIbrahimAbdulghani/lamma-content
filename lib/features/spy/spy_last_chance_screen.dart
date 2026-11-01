// Lamma - by Mohamed Ibrahim
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/countdown_ring.dart';
import '../../data/providers/game_providers.dart';

class SpyLastChanceScreen extends ConsumerStatefulWidget {
  const SpyLastChanceScreen({super.key});

  @override
  ConsumerState<SpyLastChanceScreen> createState() => _SpyLastChanceScreenState();
}

class _SpyLastChanceScreenState extends ConsumerState<SpyLastChanceScreen> {
  Timer? _timer;
  late int _secondsLeft;
  String? _selectedWord;
  List<String> _words = [];

  @override
  void initState() {
    super.initState();
    final settings = ref.read(spySettingsProvider);
    _secondsLeft = settings.guessSeconds > 0 ? settings.guessSeconds : 15;

    // هنجيب الكلمات من نفس الحزمة اللي الكلمة السرية جاية منها
    _words = _buildWordChoices();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        _timer?.cancel();
        if (mounted) {
          // الوقت خلص من غير تخمين - الجاسوس خسر
          _navigateToResult(spyGuessedCorrectly: false);
        }
      }
    });
  }

  /// بنبني قائمة الكلمات اللي الجاسوس يختار منها
  /// بنجيب الكلمة السرية الحقيقية + 3 كلمات تانية من نفس الفئة/الحزمة
  List<String> _buildWordChoices() {
    final roomState = ref.read(gameRoomProvider);
    final bootstrap = ref.read(bootstrapProvider);
    final secretWord = roomState.secretWord;
    final secretCat = roomState.secretCategory;

    final categoryWords = <String>[];

    // لو عندنا bootstrap data بنجيب الكلمات من نفس الحزمة
    if (bootstrap.data != null) {
      for (final pack in bootstrap.data!.spyPacks) {
        if (pack.words.contains(secretWord) || pack.nameAr == secretCat) {
          categoryWords.addAll(pack.words);
          break;
        }
      }
    }

    // لو مفيش أو أوفلاين، بنجيب كلمات مناسبة لنفس الفئة
    if (categoryWords.isEmpty) {
      if (secretCat.contains('فيلم') || secretCat.contains('أفلام')) {
        categoryWords.addAll([
          'الكيف', 'الفرح', 'الناظر', 'عسل أسود', 'إبراهيم الأبيض',
          'طيور الظلام', 'الإرهاب والكباب', 'بوحة', 'اللمبي', 'صعيدي في الجامعة الأمريكية'
        ]);
      } else if (secretCat.contains('أكل') || secretCat.contains('أكلات') || secretCat.contains('طعام')) {
        categoryWords.addAll([
          'كشري', 'ملوخية بالأرانب', 'حمام محشي', 'فول وطعمية', 'حواوشي',
          'فتة كوارع', 'مسقعة', 'كباب وكفتة', 'شاورما', 'أم علي'
        ]);
      } else {
        // أماكن
        categoryWords.addAll([
          'خان الخليلي', 'شاطئ المعمورة', 'مطار القاهرة', 'برج القاهرة',
          'الأهرامات', 'محطة مصر', 'قلعة قايتباي', 'شارع المعز', 'مجمع التحرير'
        ]);
      }
    }

    // بنشيل الكلمة الصح من القائمة عشان ما تتكررش
    categoryWords.remove(secretWord);

    // بنخلط الكلمات ونختار 3 غلط
    categoryWords.shuffle(Random());
    final wrongWords = categoryWords.take(3).toList();

    // بنضيف الكلمة السرية الصحيحة ونخلط الاختيارات
    final choices = [...wrongWords, secretWord];
    choices.shuffle(Random());

    return choices;
  }

  void _chooseWord(String word) {
    if (_selectedWord != null) return;
    setState(() {
      _selectedWord = word;
    });
    _timer?.cancel();

    final roomState = ref.read(gameRoomProvider);
    final isCorrectGuess = (word == roomState.secretWord);

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _navigateToResult(spyGuessedCorrectly: isCorrectGuess);
      }
    });
  }

  void _navigateToResult({required bool spyGuessedCorrectly}) {
    // بنسجل النتيجة
    ref.read(gameRoomProvider.notifier).setSpyGuessResult(
      spyGuessedCorrectly: spyGuessedCorrectly,
      guessedWord: _selectedWord,
    );
    context.go('/spy/result');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.read(spySettingsProvider);
    final totalSeconds = settings.guessSeconds > 0 ? settings.guessSeconds : 15;
    final progress = _secondsLeft / totalSeconds;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Consumer(
          builder: (context, ref, _) {
            final roomState = ref.watch(gameRoomProvider);
            return Text(
              'جولة ${roomState.currentRound} من ${roomState.totalRounds}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentCoral,
              ),
            );
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'اتكشفت! خمّن الكلمة',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Countdown Ring
              Center(
                child: CountdownRing(
                  progress: progress,
                  size: 160,
                  color: AppTheme.accentCoral,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$_secondsLeft',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentCoral,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'ثانية',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Word options
              Expanded(
                child: ListView.separated(
                  itemCount: _words.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final w = _words[index];
                    final isSelected = w == _selectedWord;
                    return InkWell(
                      onTap: () => _chooseWord(w),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.accentCoral : AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppTheme.accentCoral : AppTheme.textSecondary,
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          w,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? const Color(0xFF101428) : Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
