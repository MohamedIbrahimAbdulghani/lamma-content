// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/game_providers.dart';
import '../../data/services/game_content_service.dart';
import '../lobby/ai_generation_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _isResetting = false;

  final List<String> _avatars = [
    '🦁', '🦊', '🐻', '🐼', '🐯', '🐨', '🐸', '🦉',
    '🐵', '🦄', '🐙', '🦖', '🦈', '🦅', '🐺', '🦔',
    '🐧', '🦥', '🦦', '🦩'
  ];

  @override
  void initState() {
    super.initState();
    final storage = ref.read(localStorageProvider);
    _soundEnabled = storage.getSoundEnabled();
    _vibrationEnabled = storage.getVibrationEnabled();
  }

  void _showNameDialog() {
    final currentName = ref.read(currentPlayerNameProvider);
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تعديل اسمك', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF25293E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentSaffron,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(currentPlayerNameProvider.notifier).state = controller.text.trim();
              }
              Navigator.pop(context);
            },
            child: const Text('حفظ', style: TextStyle(color: Color(0xFF101428), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAvatarDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'اختر شخصيتك الرمزية',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 280,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: _avatars.length,
                  itemBuilder: (context, index) {
                    final av = _avatars[index];
                    return InkWell(
                      onTap: () {
                        ref.read(currentPlayerAvatarProvider.notifier).state = av;
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF25293E),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.center,
                        child: Text(av, style: const TextStyle(fontSize: 28)),
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

  void _confirmResetHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'إعادة ضبط سجل الأسئلة والكلمات',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: const Text(
          'تحذير: هذا الإجراء سيعيد ظهور أسئلة وكلمات شاهدتها من قبل في الألعاب القادمة!\n\nسيتم مسح:\n• بصمات الأسئلة والإجابات المشاهدة المخزنة محلياً على هذا الجهاز.\n• سجل كلمات الجاسوس والتمثيل لهذا الجهاز.\n• سجل المشاهدة الخاص بهذا الجهاز على الخادم.\n\n⚠️ ملاحظة هامة: هذا الإجراء لا يؤثر على سجل الغرفة الجارية ولا يمس بيانات أجهزة اللاعبين الآخرين الحاضرين معك.\n\nهل أنت متأكد من رغبتك في إعادة الضبط؟',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCoral,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isResetting = true);
              try {
                await ref.read(gameContentServiceProvider).resetAllHistory();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تمت إعادة ضبط سجل الأسئلة بنجاح! 🎉'),
                      backgroundColor: AppTheme.accentMint,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('حدث خطأ أثناء إعادة ضبط السجل'),
                      backgroundColor: AppTheme.accentCoral,
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isResetting = false);
              }
            },
            child: const Text('نعم، أعد الضبط', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerName = ref.watch(currentPlayerNameProvider);
    final playerAvatar = ref.watch(currentPlayerAvatarProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'الإعدادات',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: ListView(
            children: [
              // Edit Name
              InkWell(
                onTap: _showNameDialog,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 60),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('اسمك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(
                                playerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.accentSaffron),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.edit, size: 18, color: AppTheme.textSecondary),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Edit Avatar
              InkWell(
                onTap: _showAvatarDialog,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 60),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'الصورة الرمزية',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF25293E),
                            child: Text(playerAvatar, style: const TextStyle(fontSize: 20)),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.cached, size: 18, color: AppTheme.textSecondary),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Sound Toggle
              Container(
                constraints: const BoxConstraints(minHeight: 60),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'الأصوات',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    Switch(
                      value: _soundEnabled,
                      activeThumbColor: const Color(0xFF101428),
                      activeTrackColor: AppTheme.accentSaffron,
                      onChanged: (val) {
                        setState(() => _soundEnabled = val);
                        ref.read(localStorageProvider).setSoundEnabled(val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Vibration Toggle
              Container(
                constraints: const BoxConstraints(minHeight: 60),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'الاهتزاز',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    Switch(
                      value: _vibrationEnabled,
                      activeThumbColor: const Color(0xFF101428),
                      activeTrackColor: AppTheme.accentSaffron,
                      onChanged: (val) {
                        setState(() => _vibrationEnabled = val);
                        ref.read(localStorageProvider).setVibrationEnabled(val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // زر إعادة ضبط السجل (Problem 4.6)
              InkWell(
                onTap: _isResetting ? null : _confirmResetHistory,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 60),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.accentCoral.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: const [
                            Icon(Icons.restart_alt, color: AppTheme.accentCoral, size: 22),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'إعادة ضبط سجل الأسئلة',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentCoral,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_isResetting)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentCoral),
                        )
                      else
                        const Icon(Icons.arrow_back, size: 20, color: AppTheme.accentCoral),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // زر توليد الأسئلة بالذكاء الاصطناعي
              InkWell(
                onTap: () => showAiGenerationSheet(context, gameType: 'all'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 60),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.accentMint.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: const [
                            Icon(Icons.auto_awesome, color: AppTheme.accentMint, size: 22),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'توليد الأسئلة بالذكاء الاصطناعي',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Gemini AI',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentMint,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_back, size: 16, color: AppTheme.accentMint),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // How to play link
              InkWell(
                onTap: () => context.push('/how-to'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 60),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Expanded(
                        child: Text(
                          'طريقة اللعب',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      Icon(Icons.arrow_back, size: 22, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // About link
              InkWell(
                onTap: () => context.push('/about'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 60),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Expanded(
                        child: Text(
                          'عن التطبيق',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      Icon(Icons.arrow_back, size: 22, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
