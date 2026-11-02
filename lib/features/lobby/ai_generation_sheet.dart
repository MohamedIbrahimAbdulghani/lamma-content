// Lamma - by Mohamed Ibrahim

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../data/providers/game_providers.dart';

/// فتح نافذة تحديث ومزامنة المحتوى الذاتي (بدون أي معاينة للأسئلة أو الإجابات لضمان النزاهة التامة)
Future<void> showAiGenerationSheet(
  BuildContext context, {
  String gameType = 'trivia',
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

class _AiGenerationSheetState extends ConsumerState<AiGenerationSheet> {
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _errorMessage;

  int _totalQuestions = 0;
  int _freshQuestions = 0;
  int _spyGroups = 0;
  int _charadesWords = 0;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
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
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'تعذر الاتصال بالخادم. اللعبة تستخدم المخزون المحلي الآمن.';
        });
      }
    }
  }

  Future<void> _syncNow() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final api = ref.read(apiClientProvider);
      final storage = ref.read(localStorageProvider);

      // مزامنة السجل المحلي في الخلفية
      await api.syncDeviceHistory(
        seenTriviaIds: storage.getSeenQuestions().toList(),
      );

      // استعلام الحالة المحدثة
      final status = await api.fetchSyncStatus();
      if (status != null && mounted) {
        setState(() {
          _totalQuestions = status['total_questions'] as int? ?? _totalQuestions;
          _freshQuestions = status['fresh_questions_available'] as int? ?? _freshQuestions;
          _spyGroups = status['spy_groups_available'] as int? ?? _spyGroups;
          _charadesWords = status['charades_words_available'] as int? ?? _charadesWords;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت مزامنة وتجديد المخزون الذاتي بنجاح ⚡'),
            backgroundColor: AppTheme.accentMint,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم استئناف اللعب بالمخزون المحلي الجاهز 🎮'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          // Drag handle
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

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentSaffron.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppTheme.accentSaffron,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تحديث ومزامنة المحتوى الذكي ⚡',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
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

          // Fair-play notice card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bg.withOpacity(0.6),
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
                    'حفاظاً على نزاهة المنافسة ومتعة اللعب، لا يمكن لأي لاعب (بما في ذلك المضيف) استعراض الأسئلة أو الإجابات مسبقاً. يقوم الذكاء الاصطناعي بتوليد وفلترة الأسئلة بدقة وتقديمها وقت السؤال فقط.',
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

          // Stock indicators
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

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 12, color: AppTheme.accentSaffron),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 20),

          // Progress indicator during sync
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: LinearProgressIndicator(color: AppTheme.accentSaffron),
            ),

          // Action buttons
          PrimaryButton(
            title: _isSyncing ? 'جاري التحديث والتجديد...' : 'تحديث وتعويض المخزون الآن 🔄',
            isLoading: _isSyncing,
            onPressed: _isSyncing ? null : _syncNow,
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            title: 'تم، جاهز للعب 🚀',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
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
        color: AppTheme.bg.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
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
