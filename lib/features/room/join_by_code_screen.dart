// Lamma - by Mohamed Ibrahim

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/providers/game_providers.dart';
import '../../net/client/room_client.dart';
import '../../net/discovery/room_discovery_service.dart';

class JoinByCodeScreen extends ConsumerStatefulWidget {
  const JoinByCodeScreen({super.key});

  @override
  ConsumerState<JoinByCodeScreen> createState() => _JoinByCodeScreenState();
}

class _JoinByCodeScreenState extends ConsumerState<JoinByCodeScreen> {
  String _code = '';
  final TextEditingController _ipController = TextEditingController();
  final FocusNode _keyboardFocusNode = FocusNode();
  bool _isConnecting = false;
  bool _showManualIp = false;

  // حماية من التخمين المتكرر (Rate Limiting)
  int _consecutiveFailures = 0;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _detectLocalSubnet();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _keyboardFocusNode.dispose();
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _detectLocalSubnet() async {
    try {
      final info = NetworkInfo();
      final wifiIp = await info.getWifiIP();
      if (wifiIp != null && wifiIp.isNotEmpty) {
        final segments = wifiIp.split('.');
        if (segments.length == 4) {
          _ipController.text = '${segments[0]}.${segments[1]}.${segments[2]}.';
        }
      }
    } catch (_) {}
  }

  /// تنظيف المدخلات وتحويل الأرقام العربية الهندية والفارسية لأرقام قياسية
  String _sanitizeInput(String input) {
    var sanitized = input.trim();
    const easternDigits = '٠١٢٣٤٥٦٧٨٩';
    const persianDigits = '۰۱۲۳۴۵۶۷۸۹';

    for (int i = 0; i < 10; i++) {
      sanitized = sanitized.replaceAll(easternDigits[i], '$i');
      sanitized = sanitized.replaceAll(persianDigits[i], '$i');
    }

    sanitized = sanitized.replaceAll(RegExp(r'\D'), '');
    return sanitized;
  }

  void _onDigitPress(String digit) {
    if (_lockoutSeconds > 0) return;

    final sanitized = _sanitizeInput(digit);
    if (sanitized.isEmpty) return;

    if (_code.length < 4) {
      setState(() {
        _code += sanitized[0];
      });
    }
  }

  void _onBackspace() {
    if (_lockoutSeconds > 0) return;
    if (_code.isNotEmpty) {
      setState(() {
        _code = _code.substring(0, _code.length - 1);
      });
    }
  }

  void _handleRawTextInput(String value) {
    if (_lockoutSeconds > 0) return;
    final sanitized = _sanitizeInput(value);
    setState(() {
      _code = sanitized.length > 4 ? sanitized.substring(0, 4) : sanitized;
    });
  }

  /// تفعيل الإيقاف المؤقت بعد 5 محاولات خاطئة متتالية
  void _triggerLockout() {
    setState(() {
      _lockoutSeconds = 30;
    });
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _lockoutSeconds--;
        if (_lockoutSeconds <= 0) {
          timer.cancel();
          _consecutiveFailures = 0;
        }
      });
    });
  }

  Future<void> _submitJoin() async {
    // منع الضغط أثناء الاتصال أو في فترة القفل
    if (_isConnecting || _lockoutSeconds > 0) return;
    if (_code.length != 4) return;

    setState(() => _isConnecting = true);

    final cleanCode = _code.trim();
    final manualIp = _ipController.text.trim();
    final preferredIp = manualIp.isNotEmpty && manualIp.split('.').length == 4 ? manualIp : null;

    // 1. البحث التلقائي عن المضيف في الشبكة المحلية
    String? hostIp = await RoomDiscoveryService.findHostForCode(
      roomCode: cleanCode,
      preferredHostIp: preferredIp,
      timeout: const Duration(seconds: 3),
    );

    // لو ما لقيناش عبر الاكتشاف والمستخدم مدخل IP، نستخدمه كبديل أخير
    if (hostIp == null && preferredIp != null) {
      hostIp = preferredIp;
    }

    if (hostIp == null) {
      setState(() => _isConnecting = false);
      _consecutiveFailures++;

      if (_consecutiveFailures >= 5) {
        _triggerLockout();
      }

      if (mounted) {
        _showRetrySnackbar(
          'تعذر العثور على الغرفة، تأكد من الكود وأن الجهازين متصلان بنفس شبكة الواي فاي',
        );
      }
      return;
    }

    // 2. إنشاء عميل الاتصال
    final storage = ref.read(localStorageProvider);
    final playerName = storage.getPlayerName();
    final playerEmoji = storage.getPlayerEmoji();
    final deviceId = storage.getDeviceId();
    final roomNotifier = ref.read(roomProvider.notifier);

    final client = RoomClient(
      hostIp: hostIp,
      port: 8080,
      roomCode: cleanCode,
      playerName: playerName,
      playerEmoji: playerEmoji,
      deviceId: deviceId,
      storage: storage,
      onStateUpdated: (state) {
        if (mounted) roomNotifier.updateFromNetwork(state);
      },
      onStrikeReceived: (msg, count, isKicked) {
        if (mounted) {
          roomNotifier.showStrikeToast(msg);
          if (isKicked) roomNotifier.setKicked();
        }
      },
      onHostLeft: () {
        if (mounted) roomNotifier.setHostLeft();
      },
      onJoinError: (err) {
        // يتم التعامل مع الخطأ عبر كائن النتيجة JoinResult
      },
    );

    // 3. الاتصال والمصادقة
    final result = await client.connect(timeout: const Duration(seconds: 4));
    setState(() => _isConnecting = false);

    if (!mounted) return;

    if (result.isSuccess) {
      _consecutiveFailures = 0;
      roomNotifier.setClient(client, cleanCode, hostIp);
      try {
        final api = ref.read(apiClientProvider);
        unawaited(api.joinRoomSession(cleanCode));
      } catch (_) {}
      context.push(AppRoutes.lobby);
    } else {
      switch (result.errorKey) {
        case 'wrong_code':
          _consecutiveFailures++;
          if (_consecutiveFailures >= 5) {
            _triggerLockout();
          }
          context.push(AppRoutes.wrongCode);
          break;

        case 'room_full':
          context.push(AppRoutes.roomFull);
          break;

        case 'game_started':
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('بدأت اللعبة بالفعل ولا يمكن الانضمام الآن'),
              backgroundColor: AppColors.spyAccent,
            ),
          );
          break;

        case 'room_closed':
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('هذه الغرفة مغلقة أو انتهت'),
              backgroundColor: AppColors.spyAccent,
            ),
          );
          break;

        case 'timeout':
        case 'network_error':
        default:
          _showRetrySnackbar(result.errorMessage.isNotEmpty
              ? result.errorMessage
              : 'تعذر الاتصال بالمضيف، تأكد من اتصالكما بنفس الشبكة');
          break;
      }
    }
  }

  void _showRetrySnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.spyAccent,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'إعادة المحاولة',
          textColor: Colors.white,
          onPressed: _submitJoin,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // شريط العودة والعنوان
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'اكتب كود الغرفة',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // تنبيه القفل المؤقت عند تكرار الأخطاء
              if (_lockoutSeconds > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.spyAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.spyAccent),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer, color: AppColors.spyAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تم استنفاد المحاولات. برجاء الانتظار $_lockoutSeconds ثانية...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // خيار إظهار إدخال IP المضيف اليدوي عند الحاجة
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _showManualIp ? 'عنوان المضيف (يدوي):' : 'اكتشاف تلقائي عبر الواي فاي',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _showManualIp = !_showManualIp),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _showManualIp ? 'إخفاء' : 'تحديد IP المضيف',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.generalAccent,
                      ),
                    ),
                  ),
                ],
              ),

              if (_showManualIp) ...[
                const SizedBox(height: 8),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _ipController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'عنوان IP المضيف (مثلاً: 192.168.1.8)',
                      hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // مربعات إدخال كود الغرفة (4 أرقام)
              GestureDetector(
                onTap: () => FocusScope.of(context).requestFocus(_keyboardFocusNode),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final hasDigit = index < _code.length;
                    final digit = hasDigit ? _code[index] : '';
                    return Container(
                      width: 64,
                      height: 64,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: hasDigit
                            ? Border.all(color: AppColors.generalAccent, width: 2)
                            : Border.all(color: Colors.white12, width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        digit,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: AppColors.generalAccent,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // حقل خفي لاستقبال إدخال الكيبورد العادي أو اللصق (Paste)
              Opacity(
                opacity: 0,
                child: SizedBox(
                  height: 1,
                  child: TextField(
                    focusNode: _keyboardFocusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    onChanged: _handleRawTextInput,
                  ),
                ),
              ),

              const Spacer(),

              // لوحة الأرقام الرقمية المخصصة
              _buildKeypad(),
              const SizedBox(height: 16),

              // زر الانضمام مع التحقق من الاكتمال ومنع التكرار
              PrimaryButton(
                label: 'انضم',
                isLoading: _isConnecting,
                backgroundColor: AppColors.generalAccent,
                onPressed: (_code.length == 4 && !_isConnecting && _lockoutSeconds <= 0)
                    ? _submitJoin
                    : null,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    final isLocked = _lockoutSeconds > 0;
    return Opacity(
      opacity: isLocked ? 0.4 : 1.0,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['1', '2', '3'].map((d) => _buildKey(d)).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['4', '5', '6'].map((d) => _buildKey(d)).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['7', '8', '9'].map((d) => _buildKey(d)).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 80, height: 56),
              _buildKey('0'),
              InkWell(
                onTap: isLocked ? null : _onBackspace,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 80,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.backspace, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String digit) {
    final isLocked = _lockoutSeconds > 0;
    return InkWell(
      onTap: isLocked ? null : () => _onDigitPress(digit),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
