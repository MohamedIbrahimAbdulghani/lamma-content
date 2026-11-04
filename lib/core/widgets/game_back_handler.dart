// Lamma - Game Back Handler & Navigation Scope
// Mohamed Ibrahim

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/game_strings.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';
import '../../data/providers/game_providers.dart';
import '../../features/trivia/presentation/controllers/trivia_controller.dart';
import '../../features/charades/controllers/charades_controller.dart';
import 'game_back_dialog.dart';

/// معالج مركزي لسلوك الرجوع للمضيف واللاعبين في كافة الألعاب
class GameBackHandler {
  /// استدعاء تأكيد الرجوع وفق دور المستخدم (مضيف أو لاعب عادي)
  static Future<void> handleBack(BuildContext context, WidgetRef ref) async {
    final roomState = ref.read(gameRoomProvider);

    if (roomState.isHost) {
      // 1. المضيف: تأكيد الرجوع للوبي وإلغاء الجولة
      await GameBackDialog.showHostReturnDialog(
        context,
        onConfirm: () async {
          // إلغاء مؤقتات الجولة المحلية فوراً
          ref.read(triviaGameProvider.notifier).cancelRound();
          ref.read(charadesGameProvider.notifier).cancelRound();

          // إعادة الغرفة لحالة اللوبي وبث التحديث لجميع اللاعبين
          ref.read(gameRoomProvider.notifier).hostReturnToLobby();

          if (context.mounted) {
            context.go(AppRoutes.lobby);
          }
        },
      );
    } else {
      // 2. اللاعب غير المضيف: تأكيد مغادرة الغرفة
      await GameBackDialog.showPlayerLeaveDialog(
        context,
        onConfirm: () async {
          // إلغاء مؤقتات الجولة المحلية
          ref.read(triviaGameProvider.notifier).cancelRound();
          ref.read(charadesGameProvider.notifier).cancelRound();

          // مغادرة الغرفة وفصل الاتصال وتحديث القائمة لدى الخادم
          await ref.read(gameRoomProvider.notifier).playerLeaveRoom();

          if (context.mounted) {
            context.go(AppRoutes.home);
          }
        },
      );
    }
  }
}

/// حاوية تغليف لجميع شاشات الألعاب للتحكم في زر النظام وإيماءة الرجوع وحالات الغرفة
class GameBackScope extends ConsumerWidget {
  final Widget child;
  final VoidCallback? onCleanup;

  const GameBackScope({
    super.key,
    required this.child,
    this.onCleanup,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // استماع لحالات الغرفة للعملاء غير المضيفين
    ref.listen<ActiveRoomState>(gameRoomProvider, (previous, next) {
      if (!next.isHost) {
        // انقطاع أو خروج المضيف
        if (next.hostLeft) {
          onCleanup?.call();
          if (context.mounted) {
            context.go(AppRoutes.hostLeft);
          }
          return;
        }

        // طرد اللاعب
        if (next.isKicked) {
          onCleanup?.call();
          if (context.mounted) {
            context.go(AppRoutes.kicked);
          }
          return;
        }

        // عودة المضيف باللوبي أو انخفاض عدد اللاعبين عن الحد الأدنى
        if (next.currentPhase == 'lobby' &&
            (previous?.currentPhase != 'lobby' || previous == null)) {
          onCleanup?.call();
          ref.read(triviaGameProvider.notifier).cancelRound();
          ref.read(charadesGameProvider.notifier).cancelRound();

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  GameStrings.roundCancelledReturnedToLobby,
                  style: TextStyle(fontFamily: 'Cairo'),
                ),
                backgroundColor: AppTheme.accentCoral,
                duration: Duration(seconds: 3),
              ),
            );
            context.go(AppRoutes.lobby);
          }
          return;
        }
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        GameBackHandler.handleBack(context, ref);
      },
      child: child,
    );
  }
}

/// زر رجوع قياسي لشريط التطبيق العلوي (AppBar)
class GameBackButton extends ConsumerWidget {
  final VoidCallback? onPressed;
  final Color? color;

  const GameBackButton({
    super.key,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(
        Icons.arrow_forward_rounded,
        color: color ?? Colors.white,
      ),
      tooltip: 'رجوع',
      onPressed: onPressed ?? () => GameBackHandler.handleBack(context, ref),
    );
  }
}

/// زر رجوع دائري أنيق للشاشات التي لا تحتوي على AppBar مخصص
class GameBackCircularButton extends ConsumerWidget {
  final VoidCallback? onPressed;
  final double size;

  const GameBackCircularButton({
    super.key,
    this.onPressed,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.arrow_forward_rounded,
          color: Colors.white,
          size: 20,
        ),
        tooltip: 'رجوع',
        onPressed: onPressed ?? () => GameBackHandler.handleBack(context, ref),
      ),
    );
  }
}
