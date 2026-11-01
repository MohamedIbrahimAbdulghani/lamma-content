// Lamma - by Mohamed Ibrahim

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/arabic_text_normalizer.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../data/models/question_model.dart';
import '../../data/providers/game_providers.dart';
import '../../data/services/ai_question_service.dart';
import '../../data/services/game_content_service.dart';

/// دالة مساعدة لفتح الـ Bottom Sheet لتوليد المحتوى بالذكاء الاصطناعي
Future<void> showAiGenerationSheet(
  BuildContext context, {
  String gameType = 'trivia', // 'trivia', 'spy', 'charades'
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => AiGenerationSheet(gameType: gameType),
  );
}

class AiGenerationSheet extends ConsumerStatefulWidget {
  final String gameType;

  const AiGenerationSheet({
    super.key,
    this.gameType = 'trivia',
  });

  @override
  ConsumerState<AiGenerationSheet> createState() => _AiGenerationSheetState();
}

enum _AiSheetStep { config, loading, preview, error }

class _AiGenerationSheetState extends ConsumerState<AiGenerationSheet> {
  _AiSheetStep _step = _AiSheetStep.config;

  // Settings
  String _selectedCategory = 'all';
  String _selectedDifficulty = 'all';
  int _selectedCount = 10;
  final TextEditingController _topicController = TextEditingController();

  // Generated results
  List<QuestionModel> _generatedQuestions = [];
  List<String> _generatedWords = [];

  // Error tracking
  String _errorMessage = '';
  bool _isGenerating = false;
  bool _isCancelled = false;

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  // Categories mapping
  List<Map<String, String>> _getCategories() {
    if (widget.gameType == 'spy') {
      return [
        {'id': 'all', 'title': 'الكل'},
        {'id': 'places', 'title': 'أماكن ومعالم'},
        {'id': 'movies', 'title': 'أفلام ومسلسلات'},
        {'id': 'food', 'title': 'أكلات مصرية'},
      ];
    } else if (widget.gameType == 'charades') {
      return [
        {'id': 'all', 'title': 'الكل'},
        {'id': 'movies', 'title': 'أفلام ومسلسلات'},
        {'id': 'actions', 'title': 'أفعال وحركات'},
        {'id': 'proverbs', 'title': 'أمثال شعبية'},
        {'id': 'jobs', 'title': 'مهن وشخصيات'},
        {'id': 'objects', 'title': 'أشياء وأدوات'},
      ];
    }
    return [
      {'id': 'all', 'title': 'الكل'},
      {'id': 'movies', 'title': 'أفلام ومسلسلات'},
      {'id': 'sports', 'title': 'كورة مصرية'},
      {'id': 'afeehat', 'title': 'إفيهات وقفشات'},
      {'id': 'history', 'title': 'تاريخ وجغرافيا'},
      {'id': 'general', 'title': 'عامة'},
    ];
  }

  Future<void> _startGeneration() async {
    if (_isGenerating) return;

    setState(() {
      _isGenerating = true;
      _isCancelled = false;
      _step = _AiSheetStep.loading;
      _errorMessage = '';
    });

    try {
      final aiService = ref.read(aiQuestionServiceProvider);
      final specificTopic = _topicController.text.trim();

      if (widget.gameType == 'trivia') {
        // المرحلة 1: قراءة السجل وبناء الـ Sets
        final stage1Timer = Stopwatch()..start();
        final seenPrompts = ref.read(localStorageProvider).getSeenTriviaPromptHashes();
        final seenAnswers = ref.read(localStorageProvider).getSeenTriviaAnswerHashes();
        stage1Timer.stop();
        debugPrint('[AI_TIMING] Stage 1 (Read History & Build Sets): ${stage1Timer.elapsedMilliseconds}ms | Seen: ${seenPrompts.length} prompts');

        // المرحلة 2: استدعاء خدمة الـ AI عبر الشبكة
        final stage2Timer = Stopwatch()..start();
        final rawQuestions = await aiService.generateTriviaQuestions(
          count: _selectedCount,
          category: _selectedCategory != 'all' ? _selectedCategory : null,
          difficulty: _selectedDifficulty != 'all' ? _selectedDifficulty : null,
          specificTopic: specificTopic.isNotEmpty ? specificTopic : null,
        );
        stage2Timer.stop();
        debugPrint('[AI_TIMING] Stage 2 (Network AI Generation): ${stage2Timer.elapsedMilliseconds}ms | Received: ${rawQuestions.length} raw');

        if (_isCancelled) return;

        // المرحلة 3 و 4: فلترة وتطبيع وحساب بصمات في Isolate منفصل (compute) لمنع أي تجميد للـ UI thread
        final stage3Timer = Stopwatch()..start();
        List<QuestionModel> validQuestions = await compute(
          _filterTriviaWorker,
          _TriviaFilterPayload(
            questions: rawQuestions,
            seenPrompts: seenPrompts,
            seenAnswers: seenAnswers,
            maxCount: _selectedCount,
          ),
        );
        stage3Timer.stop();
        debugPrint('[AI_TIMING] Stage 3 & 4 (Isolate Compute Normalization & Deduplication): ${stage3Timer.elapsedMilliseconds}ms | Valid: ${validQuestions.length}');

        // إذا كان هناك عناصر ناقصة بسبب التصفية، نحاول محاولة تكميلية
        if (validQuestions.length < _selectedCount && !_isCancelled) {
          try {
            final missingCount = _selectedCount - validQuestions.length;
            final extraQuestions = await aiService.generateTriviaQuestions(
              count: missingCount + 2,
              category: _selectedCategory != 'all' ? _selectedCategory : null,
              difficulty: _selectedDifficulty != 'all' ? _selectedDifficulty : null,
              specificTopic: specificTopic.isNotEmpty ? specificTopic : null,
              avoidTopics: validQuestions.map((q) => q.promptAr).take(20).toList(),
            );

            final extraValid = await compute(
              _filterTriviaWorker,
              _TriviaFilterPayload(
                questions: extraQuestions,
                seenPrompts: {
                  ...seenPrompts,
                  ...validQuestions.map((q) => ArabicTextNormalizer.triviaQuestionHash(q.promptAr)),
                },
                seenAnswers: {
                  ...seenAnswers,
                  ...validQuestions.map((q) => ArabicTextNormalizer.triviaAnswerHash(q.categorySlug, q.options[q.correctIndex])),
                },
                maxCount: missingCount,
              ),
            );
            validQuestions.addAll(extraValid);
          } catch (_) {}
        }

        if (_isCancelled) return;

        if (validQuestions.isEmpty) {
          throw const AiInvalidResponseException('لم يتم توليد أي أسئلة جديدة غير مكررة. جرب اختيار موضوع أو قسم مختلف.');
        }

        setState(() {
          _generatedQuestions = validQuestions;
          _step = _AiSheetStep.preview;
          _isGenerating = false;
        });
      } else if (widget.gameType == 'spy') {
        final stage1Timer = Stopwatch()..start();
        final seenHashes = ref.read(localStorageProvider).getSeenSpyHashes();
        stage1Timer.stop();
        debugPrint('[AI_TIMING] Stage 1 (Read Spy History): ${stage1Timer.elapsedMilliseconds}ms | Seen: ${seenHashes.length}');

        final stage2Timer = Stopwatch()..start();
        final rawWords = await aiService.generateSpyWords(
          count: _selectedCount,
          category: _selectedCategory != 'all' ? _selectedCategory : null,
          specificTopic: specificTopic.isNotEmpty ? specificTopic : null,
        );
        stage2Timer.stop();
        debugPrint('[AI_TIMING] Stage 2 (Network AI Spy Words): ${stage2Timer.elapsedMilliseconds}ms');

        if (_isCancelled) return;

        final stage3Timer = Stopwatch()..start();
        final validWords = await compute(
          _filterWordsWorker,
          _WordsFilterPayload(
            words: rawWords,
            seenHashes: seenHashes,
            maxCount: _selectedCount,
          ),
        );
        stage3Timer.stop();
        debugPrint('[AI_TIMING] Stage 3 & 4 (Isolate Spy Normalization & Deduplication): ${stage3Timer.elapsedMilliseconds}ms | Valid: ${validWords.length}');

        setState(() {
          _generatedWords = validWords;
          _step = _AiSheetStep.preview;
          _isGenerating = false;
        });
      } else {
        // Charades
        final stage1Timer = Stopwatch()..start();
        final seenHashes = ref.read(localStorageProvider).getSeenCharadesHashes();
        stage1Timer.stop();
        debugPrint('[AI_TIMING] Stage 1 (Read Charades History): ${stage1Timer.elapsedMilliseconds}ms | Seen: ${seenHashes.length}');

        final stage2Timer = Stopwatch()..start();
        final rawWords = await aiService.generateCharadesWords(
          count: _selectedCount,
          category: _selectedCategory != 'all' ? _selectedCategory : null,
          specificTopic: specificTopic.isNotEmpty ? specificTopic : null,
        );
        stage2Timer.stop();
        debugPrint('[AI_TIMING] Stage 2 (Network AI Charades Words): ${stage2Timer.elapsedMilliseconds}ms');

        if (_isCancelled) return;

        final stage3Timer = Stopwatch()..start();
        final validWords = await compute(
          _filterWordsWorker,
          _WordsFilterPayload(
            words: rawWords,
            seenHashes: seenHashes,
            maxCount: _selectedCount,
          ),
        );
        stage3Timer.stop();
        debugPrint('[AI_TIMING] Stage 3 & 4 (Isolate Charades Normalization & Deduplication): ${stage3Timer.elapsedMilliseconds}ms | Valid: ${validWords.length}');

        setState(() {
          _generatedWords = validWords;
          _step = _AiSheetStep.preview;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (_isCancelled) return;
      setState(() {
        _errorMessage = e is AiException ? e.message : 'حدث خطأ غير متوقع: $e';
        _step = _AiSheetStep.error;
        _isGenerating = false;
      });
    }
  }

  void _cancelGeneration() {
    _isCancelled = true;
    setState(() {
      _isGenerating = false;
      _step = _AiSheetStep.config;
    });
  }

  Future<void> _regenerateMissing() async {
    final needed = _selectedCount - _generatedQuestions.length;
    if (needed <= 0) return;

    setState(() {
      _isGenerating = true;
      _step = _AiSheetStep.loading;
    });

    try {
      final aiService = ref.read(aiQuestionServiceProvider);
      final seenPrompts = ref.read(localStorageProvider).getSeenTriviaPromptHashes();
      final seenAnswers = ref.read(localStorageProvider).getSeenTriviaAnswerHashes();

      final more = await aiService.generateTriviaQuestions(
        count: needed + 2,
        category: _selectedCategory != 'all' ? _selectedCategory : null,
        difficulty: _selectedDifficulty != 'all' ? _selectedDifficulty : null,
        avoidTopics: _generatedQuestions.map((q) => q.promptAr).toList(),
      );

      final extraValid = await compute(
        _filterTriviaWorker,
        _TriviaFilterPayload(
          questions: more,
          seenPrompts: {
            ...seenPrompts,
            ..._generatedQuestions.map((q) => ArabicTextNormalizer.triviaQuestionHash(q.promptAr)),
          },
          seenAnswers: {
            ...seenAnswers,
            ..._generatedQuestions.map((q) => ArabicTextNormalizer.triviaAnswerHash(q.categorySlug, q.options[q.correctIndex])),
          },
          maxCount: needed,
        ),
      );

      _generatedQuestions.addAll(extraValid);

      setState(() {
        _step = _AiSheetStep.preview;
        _isGenerating = false;
      });
    } catch (_) {
      setState(() {
        _step = _AiSheetStep.preview;
        _isGenerating = false;
      });
    }
  }

  void _addToGame() {
    final contentService = ref.read(gameContentServiceProvider);

    if (widget.gameType == 'trivia') {
      contentService.addGeneratedTriviaQuestions(_generatedQuestions);
      final count = _generatedQuestions.length;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('عندك $count سؤال جديد جاهز للعبة! 🎉'),
          backgroundColor: AppTheme.accentMint,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (widget.gameType == 'spy') {
      contentService.addGeneratedSpyWords(_generatedWords);
      final count = _generatedWords.length;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمت إضافة $count كلمة جديدة للجاسوس بنجاح! 🕵️'),
          backgroundColor: AppTheme.accentMint,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      contentService.addGeneratedCharadesWords(_generatedWords);
      final count = _generatedWords.length;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمت إضافة $count كلمة جديدة للتمثيل بنجاح! 🎭'),
          backgroundColor: AppTheme.accentMint,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppTheme.accentMint, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.gameType == 'trivia'
                            ? 'توليد أسئلة بالذكاء الاصطناعي'
                            : (widget.gameType == 'spy' ? 'توليد كلمات الجاسوس بالـ AI' : 'توليد عبارات تمثيل بالـ AI'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 24),

          // Content body based on current step
          Flexible(
            child: SingleChildScrollView(
              child: _buildCurrentStepView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_step) {
      case _AiSheetStep.config:
        return _buildConfigView();
      case _AiSheetStep.loading:
        return _buildLoadingView();
      case _AiSheetStep.preview:
        return _buildPreviewView();
      case _AiSheetStep.error:
        return _buildErrorView();
    }
  }

  // 1. شاشة الإعدادات
  Widget _buildConfigView() {
    final categories = _getCategories();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Category Selection
        const Text(
          'القسم المطلوب',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((cat) {
            final isSelected = _selectedCategory == cat['id'];
            return ChoiceChip(
              label: Text(cat['title']!),
              selected: isSelected,
              selectedColor: AppTheme.accentMint,
              backgroundColor: const Color(0xFF25293E),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF101428) : Colors.white,
                fontWeight: FontWeight.bold,
              ),
              onSelected: (val) {
                if (val) setState(() => _selectedCategory = cat['id']!);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Difficulty (for trivia)
        if (widget.gameType == 'trivia') ...[
          const Text(
            'مستوى الصعوبة',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildDiffOption('الكل', 'all'),
              const SizedBox(width: 8),
              _buildDiffOption('سهل', 'easy'),
              const SizedBox(width: 8),
              _buildDiffOption('متوسط', 'medium'),
              const SizedBox(width: 8),
              _buildDiffOption('حراق', 'hard'),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Count selection
        const Text(
          'عدد العناصر المطلوبة',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [5, 10, 15, 20].map((count) {
            final isSelected = _selectedCount == count;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => setState(() => _selectedCount = count),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.accentSaffron : const Color(0xFF25293E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF101428) : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Optional specific topic
        const Text(
          'موضوع محدد (اختياري)',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _topicController,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: widget.gameType == 'trivia'
                ? 'مثلاً: كورة القدم المصرية، مسلسلات رمضان 2024...'
                : 'مثلاً: شوارع القاهرة، أفلام عادل إمام...',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF25293E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 24),

        // Action button
        PrimaryButton(
          title: 'ولّد الآن بالذكاء الاصطناعي',
          icon: Icons.auto_awesome,
          accentColor: AppTheme.accentMint,
          onPressed: _startGeneration,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDiffOption(String title, String val) {
    final isSelected = _selectedDifficulty == val;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedDifficulty = val),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accentMint : const Color(0xFF25293E),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? const Color(0xFF101428) : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // 2. شاشة التحميل أثناء التوليد
  Widget _buildLoadingView() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 54,
            height: 54,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              color: AppTheme.accentMint,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'جاري التوليد بالذكاء الاصطناعي... 🧠✨',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'بنصنع محتوى جديد ومسلي خصيصاً للمتكم بدون تكرار',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SecondaryButton(
            title: 'إلغاء',
            icon: Icons.close,
            onPressed: _cancelGeneration,
          ),
        ],
      ),
    );
  }

  // 3. شاشة المعاينة بعد التوليد
  Widget _buildPreviewView() {
    if (widget.gameType == 'trivia') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الأسئلة المولدة (${_generatedQuestions.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_generatedQuestions.length < _selectedCount)
                TextButton.icon(
                  onPressed: _isGenerating ? null : _regenerateMissing,
                  icon: const Icon(Icons.refresh, size: 16, color: AppTheme.accentSaffron),
                  label: const Text(
                    'توليد الناقص',
                    style: TextStyle(color: AppTheme.accentSaffron, fontSize: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _generatedQuestions.length,
            itemBuilder: (ctx, index) {
              final q = _generatedQuestions[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF25293E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${index + 1}. ${q.promptAr}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppTheme.accentCoral, size: 20),
                          onPressed: () {
                            setState(() {
                              _generatedQuestions.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // الخيارات
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(q.options.length, (optIdx) {
                        final isCorrect = optIdx == q.correctIndex;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCorrect
                                ? AppTheme.accentMint.withValues(alpha: 0.2)
                                : Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCorrect ? AppTheme.accentMint : Colors.white12,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isCorrect) ...[
                                const Icon(Icons.check, size: 14, color: AppTheme.accentMint),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                q.options[optIdx],
                                style: TextStyle(
                                  color: isCorrect ? AppTheme.accentMint : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          PrimaryButton(
            title: 'إضافة للعبة (${_generatedQuestions.length} سؤال)',
            icon: Icons.check,
            accentColor: AppTheme.accentMint,
            onPressed: _generatedQuestions.isNotEmpty ? _addToGame : null,
          ),
          const SizedBox(height: 8),
        ],
      );
    } else {
      // Words preview for Spy / Charades
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'الكلمات المولدة (${_generatedWords.length})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_generatedWords.length, (idx) {
              final w = _generatedWords[idx];
              return Chip(
                backgroundColor: const Color(0xFF25293E),
                label: Text(w, style: const TextStyle(color: Colors.white)),
                deleteIcon: const Icon(Icons.close, size: 16, color: AppTheme.accentCoral),
                onDeleted: () {
                  setState(() {
                    _generatedWords.removeAt(idx);
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 24),

          PrimaryButton(
            title: 'إضافة للعبة (${_generatedWords.length} كلمة)',
            icon: Icons.check,
            accentColor: AppTheme.accentMint,
            onPressed: _generatedWords.isNotEmpty ? _addToGame : null,
          ),
          const SizedBox(height: 8),
        ],
      );
    }
  }

  // 4. شاشة الخطأ مع إعادة المحاولة
  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 54, color: AppTheme.accentCoral),
          const SizedBox(height: 16),
          const Text(
            'تعذر التوليد',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _errorMessage,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  title: 'تعديل الإعدادات',
                  icon: Icons.arrow_forward,
                  fontSize: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  onPressed: () => setState(() => _step = _AiSheetStep.config),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  title: 'إعادة المحاولة',
                  icon: Icons.refresh,
                  fontSize: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  accentColor: AppTheme.accentCoral,
                  onPressed: _startGeneration,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// كائنات تمرير البيانات ودوال الـ compute Isolate للفلترة ومنع تعليق واجهة المستخدم

class _TriviaFilterPayload {
  final List<QuestionModel> questions;
  final Set<String> seenPrompts;
  final Set<String> seenAnswers;
  final int maxCount;

  const _TriviaFilterPayload({
    required this.questions,
    required this.seenPrompts,
    required this.seenAnswers,
    this.maxCount = 100,
  });
}

List<QuestionModel> _filterTriviaWorker(_TriviaFilterPayload payload) {
  final valid = <QuestionModel>[];
  final batchPrompts = <String>{};
  final batchAnswers = <String>{};

  for (final q in payload.questions) {
    if (valid.length >= payload.maxCount) break;
    final pHash = ArabicTextNormalizer.triviaQuestionHash(q.promptAr);
    final aHash = ArabicTextNormalizer.triviaAnswerHash(q.categorySlug, q.options[q.correctIndex]);

    if (!payload.seenPrompts.contains(pHash) &&
        !payload.seenAnswers.contains(aHash) &&
        batchPrompts.add(pHash) &&
        batchAnswers.add(aHash)) {
      valid.add(q);
    }
  }
  return valid;
}

class _WordsFilterPayload {
  final List<String> words;
  final Set<String> seenHashes;
  final int maxCount;

  const _WordsFilterPayload({
    required this.words,
    required this.seenHashes,
    this.maxCount = 100,
  });
}

List<String> _filterWordsWorker(_WordsFilterPayload payload) {
  final valid = <String>[];
  final batchHashes = <String>{};
  final batchNormWords = <String>{};

  for (final w in payload.words) {
    if (valid.length >= payload.maxCount) break;
    final h = ArabicTextNormalizer.wordHash(w);
    final norm = ArabicTextNormalizer.normalize(w);

    if (!payload.seenHashes.contains(h) &&
        batchHashes.add(h) &&
        batchNormWords.add(norm)) {
      valid.add(w);
    }
  }
  return valid;
}
