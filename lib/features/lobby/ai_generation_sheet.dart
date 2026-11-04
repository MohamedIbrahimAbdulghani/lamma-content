// Lamma - by Mohamed Ibrahim

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ai_generation_result_dialog.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../data/api/api_client.dart';
import '../../data/models/question_model.dart';
import '../../data/providers/game_providers.dart';
import '../../data/services/ai_question_service.dart';
import '../../data/services/game_content_service.dart';

/// فتح نافذة تحديث ومزامنة وتوليد المحتوى بالذكاء الاصطناعي
Future<void> showAiGenerationSheet(
  BuildContext context, {
  String gameType = 'all',
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => AiGenerationSheet(gameType: gameType),
  );
}

class AiGenerationSheet extends ConsumerStatefulWidget {
  final String gameType; // 'trivia', 'spy', 'charades', or 'all'

  const AiGenerationSheet({
    super.key,
    this.gameType = 'all',
  });

  @override
  ConsumerState<AiGenerationSheet> createState() => _AiGenerationSheetState();
}

class _AiGenerationSheetState extends ConsumerState<AiGenerationSheet> {
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _statusError;

  int _totalQuestions = 0;
  int _freshQuestions = 0;
  int _spyGroups = 0;
  int _charadesWords = 0;

  // حالة شريط التقدم والخطوات أثناء التوليد
  String _stepText = 'جاري التحضير...';
  int _progressDone = 0;
  int _progressTotal = 15;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    setState(() {
      _isLoading = true;
      _statusError = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final status = await api.fetchSyncStatus();
      if (status != null && mounted) {
        setState(() {
          _totalQuestions = status['total_questions'] as int? ?? 100;
          _freshQuestions = status['fresh_questions_available'] as int? ?? 100;
          _spyGroups = status['spy_groups_available'] as int? ?? 10;
          _charadesWords = status['charades_words_available'] as int? ?? 50;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusError = 'تعذر الاتصال بالخادم. اللعبة تستخدم المخزون المحلي الآمن.';
        });
      }
    }
  }

  Future<void> _startGeneration() async {
    if (_isGenerating) return;

    final targetContext = context;
    final api = ref.read(apiClientProvider);
    final storage = ref.read(localStorageProvider);
    final contentService = ref.read(gameContentServiceProvider);

    setState(() {
      _isGenerating = true;
      _cancelToken = CancelToken();
      _progressDone = 0;
      _stepText = 'جاري الاتصال بالذكاء الاصطناعي...';
    });

    final isGeneral = widget.gameType == 'all' || widget.gameType == 'general';
    final targetTotal = isGeneral ? 18 : 10;
    setState(() => _progressTotal = targetTotal);

    int addedTrivia = 0;
    int addedSpy = 0;
    int addedCharades = 0;
    String? failureReason;
    String? debugDetails;

    try {
      if (widget.gameType == 'trivia') {
        setState(() => _stepText = 'جاري توليد واختبار أسئلة التحدي...');
        final raw = await api.generateAiContent(
          gameType: 'trivia',
          count: 10,
          cancelToken: _cancelToken,
        );

        setState(() => _stepText = 'جاري التحقق والفلترة...');
        final List<QuestionModel> questions = [];
        for (int i = 0; i < raw.length; i++) {
          final item = raw[i];
          final prompt = (item['prompt_ar'] ?? item['prompt']) as String?;
          final options = (item['options'] as List<dynamic>?)?.map((e) => e.toString().trim()).toList();
          final correctIndex = item['correct_index'] as int? ?? 0;
          if (prompt != null && prompt.trim().length >= 5 && options != null && options.length == 4) {
            questions.add(QuestionModel(
              id: -1 * (DateTime.now().millisecondsSinceEpoch % 1000000 + i + 1),
              categoryId: 1,
              categorySlug: (item['category_slug'] ?? 'general').toString(),
              type: 'mcq',
              promptAr: prompt.trim(),
              options: options,
              correctIndex: correctIndex,
              difficulty: (item['difficulty'] ?? 'medium').toString(),
              explanationAr: item['explanation_ar'] as String?,
              source: 'gemini',
            ));
          }
        }
        contentService.addGeneratedTriviaQuestions(questions);
        addedTrivia = questions.length;
        setState(() => _progressDone = addedTrivia);
      } else if (widget.gameType == 'spy') {
        setState(() => _stepText = 'جاري توليد كلمات ومجموعات الجاسوس...');
        final raw = await api.generateAiContent(
          gameType: 'spy',
          category: 'places',
          count: 10,
          cancelToken: _cancelToken,
        );

        setState(() => _stepText = 'جاري التدقيق والإضافة للمخزون...');
        final words = raw
            .map((item) => (item['word_ar'] ?? item['word'] ?? item['prompt_ar'] ?? '').toString().trim())
            .where((w) => w.isNotEmpty)
            .toList();

        contentService.addGeneratedSpyWords(words);
        addedSpy = words.length;
        setState(() => _progressDone = addedSpy);
      } else if (widget.gameType == 'charades') {
        setState(() => _stepText = 'جاري توليد عبارات حركية للتمثيل...');
        final raw = await api.generateAiContent(
          gameType: 'charades',
          category: 'movies',
          count: 10,
          cancelToken: _cancelToken,
        );

        setState(() => _stepText = 'جاري فحص القابلية الحركية...');
        final words = raw
            .map((item) => (item['word_ar'] ?? item['word'] ?? item['prompt_ar'] ?? '').toString().trim())
            .where((w) => GameContentService.isActableCharadesWord(w))
            .toList();

        contentService.addGeneratedCharadesWords(words);
        addedCharades = words.length;
        setState(() => _progressDone = addedCharades);
      } else {
        // الإعدادات العامة: توليد متوازن للألعاب الثلاث معاً بدفعات سريعة
        setState(() => _stepText = 'جاري توليد محتوى متوازن للألعاب الثلاث...');

        final results = await Future.wait([
          api.generateAiContent(gameType: 'trivia', count: 6, cancelToken: _cancelToken).then((raw) {
            final List<QuestionModel> qList = [];
            for (int i = 0; i < raw.length; i++) {
              final item = raw[i];
              final prompt = (item['prompt_ar'] ?? item['prompt']) as String?;
              final options = (item['options'] as List<dynamic>?)?.map((e) => e.toString().trim()).toList();
              final cIdx = item['correct_index'] as int? ?? 0;
              if (prompt != null && options != null && options.length == 4) {
                qList.add(QuestionModel(
                  id: -1 * (DateTime.now().millisecondsSinceEpoch % 1000000 + i + 1),
                  categoryId: 1,
                  categorySlug: (item['category_slug'] ?? 'general').toString(),
                  type: 'mcq',
                  promptAr: prompt.trim(),
                  options: options,
                  correctIndex: cIdx,
                  difficulty: (item['difficulty'] ?? 'medium').toString(),
                  explanationAr: item['explanation_ar'] as String?,
                  source: 'gemini',
                ));
              }
            }
            contentService.addGeneratedTriviaQuestions(qList);
            addedTrivia = qList.length;
            if (mounted) setState(() => _progressDone += addedTrivia);
          }).catchError((_) {}),
          api.generateAiContent(gameType: 'spy', count: 6, cancelToken: _cancelToken).then((raw) {
            final words = raw
                .map((item) => (item['word_ar'] ?? item['word'] ?? item['prompt_ar'] ?? '').toString().trim())
                .where((w) => w.isNotEmpty)
                .toList();
            contentService.addGeneratedSpyWords(words);
            addedSpy = words.length;
            if (mounted) setState(() => _progressDone += addedSpy);
          }).catchError((_) {}),
          api.generateAiContent(gameType: 'charades', count: 6, cancelToken: _cancelToken).then((raw) {
            final words = raw
                .map((item) => (item['word_ar'] ?? item['word'] ?? item['prompt_ar'] ?? '').toString().trim())
                .where((w) => GameContentService.isActableCharadesWord(w))
                .toList();
            contentService.addGeneratedCharadesWords(words);
            addedCharades = words.length;
            if (mounted) setState(() => _progressDone += addedCharades);
          }).catchError((_) {}),
        ]);
        results.length; // touch
      }

      // مزامنة السجل بعد التوليد
      await api.syncDeviceHistory(
        seenTriviaIds: storage.getSeenQuestions().toList(),
      );
    } on AiCancelledException {
      // ألغى المستخدم العملية: لا تظهر أي نافذة نجاح ولا خطأ
      if (mounted) {
        setState(() => _isGenerating = false);
        Navigator.of(context).pop();
      }
      return;
    } on AiNoInternetException catch (e) {
      failureReason = 'لا يوجد اتصال بالإنترنت';
      debugDetails = e.message;
    } on AiTimeoutException catch (e) {
      failureReason = 'انتهت المهلة';
      debugDetails = e.message;
    } on AiRateLimitException catch (e) {
      failureReason = 'تجاوز الحد المجاني فحاول لاحقاً';
      debugDetails = e.message;
    } on AiInvalidKeyException catch (e) {
      failureReason = 'مفتاح الخدمة غير صالح';
      debugDetails = e.message;
    } on AiServiceException catch (e) {
      if (e.message.contains('404')) {
        failureReason = 'الموديل غير متاح';
      } else {
        failureReason = 'رد غير صالح من الذكاء الاصطناعي';
      }
      debugDetails = e.message;
    } catch (e) {
      failureReason = 'الخادم غير متاح';
      debugDetails = e.toString();
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }

    // فحص سلامة الواجهة قبل إظهار النافذة المنبثقة
    if (!targetContext.mounted) return;

    // إغلاق نافذة الـ BottomSheet الحالية أولاً
    Navigator.of(targetContext).pop();

    final totalAdded = addedTrivia + addedSpy + addedCharades;

    if (totalAdded >= targetTotal) {
      // 1. نجاح كامل
      final msg = isGeneral
          ? 'تمت إضافة $totalAdded عنصر جديد وتحديث المخزون بنجاح ⚡'
          : (widget.gameType == 'trivia'
              ? 'تمت إضافة $totalAdded سؤال جديد جاهز للعب 🎯'
              : 'تمت إضافة $totalAdded كلمة جديدة جاهزة للعب 🎮');

      final details = isGeneral
          ? 'تحدي الشلة: $addedTrivia • مين الجاسوس: $addedSpy • مثّل ومتتكلمش: $addedCharades'
          : null;

      await showAiGenerationResultDialog(
        targetContext,
        type: AiResultType.success,
        message: msg,
        details: details,
        storage: storage,
      );
    } else if (totalAdded > 0) {
      // 2. نجاح جزئي
      final cause = failureReason != null ? ' بسبب $failureReason' : '';
      final msg = 'أُضيف $totalAdded من $targetTotal، والباقي لم يكتمل$cause.';
      final details = isGeneral
          ? 'تحدي الشلة: $addedTrivia • مين الجاسوس: $addedSpy • مثّل ومتتكلمش: $addedCharades'
          : null;

      await showAiGenerationResultDialog(
        targetContext,
        type: AiResultType.partial,
        message: msg,
        details: details,
        debugInfo: debugDetails,
        storage: storage,
      );
    } else {
      // 3. فشل كامل
      final msg = failureReason ?? 'الخادم غير متاح حالياً. يرجى التأكد من تشغيل السيرفر والمحاولة لاحقاً.';

      await showAiGenerationResultDialog(
        targetContext,
        type: AiResultType.failure,
        message: msg,
        debugInfo: debugDetails,
        onRetry: () => showAiGenerationSheet(targetContext, gameType: widget.gameType),
        storage: storage,
      );
    }
  }

  void _cancelGeneration() {
    _cancelToken?.cancel();
    if (mounted) {
      setState(() => _isGenerating = false);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _getGameAccent(widget.gameType);

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // مقبض السحب
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // الرأس مع أيقونة وهوية اللعبة
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getGameIcon(widget.gameType),
                  color: themeColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getHeaderTitle(widget.gameType),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'توليد وفحص وتجديد ذاتي بالكامل دون تدخل بشري',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // بطاقة النزاهة واللعب العادل (لا معاينة للأسئلة)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bg.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: AppTheme.accentMint, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'حفاظاً على نزاهة المنافسة ومتعة اللعب، لا يمكن لأي لاعب (بما في ذلك المضيف) استعراض الأسئلة أو الإجابات مسبقاً. يقوم الذكاء الاصطناعي بتوليد وفلترة المحتوى بدقة وتقديمه وقت اللعب فقط.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // إحصائيات المخزون
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _buildStockBadge(
                    title: 'أسئلة التحدي الجديدة',
                    count: '$_freshQuestions',
                    subtitle: 'جاهزة لك في السحابة',
                    icon: Icons.quiz_outlined,
                    color: AppTheme.accentMint,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStockBadge(
                    title: 'مجموعات الجاسوس',
                    count: '$_spyGroups',
                    subtitle: 'متجانسة ومترابطة',
                    icon: Icons.groups_outlined,
                    color: AppTheme.accentSaffron,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildStockBadge(
              title: 'إجمالي بنك المحتوى المفحوص',
              count: '$_totalQuestions سؤال / كلمة نشطة',
              subtitle: 'يتم تعويض المستهلك منها تلقائياً في الخلفية',
              icon: Icons.storage_outlined,
              color: Colors.cyanAccent,
            ),
          ],

          if (_statusError != null) ...[
            const SizedBox(height: 12),
            Text(
              _statusError!,
              style: const TextStyle(fontSize: 12, color: AppTheme.accentSaffron),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 20),

          // حالة وشريط التقدم التفاعلي الحقيقي أثناء التوليد
          if (_isGenerating) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.bg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: themeColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _stepText,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'أُنجز $_progressDone من $_progressTotal',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _progressTotal > 0 ? (_progressDone / _progressTotal).clamp(0.05, 1.0) : null,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SecondaryButton(
              title: 'إلغاء التوليد ❌',
              onPressed: _cancelGeneration,
            ),
          ] else ...[
            PrimaryButton(
              title: 'توليد وتعويض المخزون الآن ⚡',
              accentColor: themeColor,
              onPressed: _startGeneration,
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              title: 'تم، جاهز للعب 🚀',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ],
      ),
    );
  }

  Color _getGameAccent(String gameType) {
    switch (gameType) {
      case 'trivia':
        return AppTheme.accentMint;
      case 'spy':
        return AppTheme.accentSaffron;
      case 'charades':
        return AppTheme.accentCoral;
      default:
        return AppTheme.accentSaffron;
    }
  }

  IconData _getGameIcon(String gameType) {
    switch (gameType) {
      case 'trivia':
        return Icons.quiz_outlined;
      case 'spy':
        return Icons.search_outlined;
      case 'charades':
        return Icons.theater_comedy_outlined;
      default:
        return Icons.auto_awesome;
    }
  }

  String _getHeaderTitle(String gameType) {
    switch (gameType) {
      case 'trivia':
        return 'توليد أسئلة تحدي الشلة 🧠';
      case 'spy':
        return 'توليد مجموعات مين الجاسوس 🕵️';
      case 'charades':
        return 'توليد كلمات مثّل ومتتكلمش 🎭';
      default:
        return 'تحديث ومزامنة المحتوى الذكي ⚡';
    }
  }

  Widget _buildStockBadge({
    required String title,
    required String count,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bg.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
