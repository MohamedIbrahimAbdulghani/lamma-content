// Lamma - by Mohamed Ibrahim

import 'dart:math';
import '../../../data/models/player_model.dart';

/// منطق اختيار وتوزيع دور الجاسوس في لعبة "مين الجاسوس"
class SpySelector {
  /// نسبة استثناء جاسوس الجولة السابقة للسماح له بدخول القرعة مجدداً (الافتراضي: 3%)
  static const double defaultConsecutiveExceptionProbability = 0.03;

  /// مولد عشوائي آمن غير معتمد على seed ثابت
  static final Random _secureRandom = Random.secure();

  /// اختيار الجاسوس/الجواسيس للجولة الحالية بعدالة مطلقة وبناءً على قاعدة منع التكرار
  static List<String> selectSpyIds({
    required List<PlayerModel> activePlayers,
    required List<String> previousSpyIds,
    int neededSpies = 1,
    double exceptionProbability = defaultConsecutiveExceptionProbability,
    Random? random,
  }) {
    final active = activePlayers.where((p) => !p.isKicked).toList();
    if (active.isEmpty) return const [];

    // حالة خاصة: لاعب واحد فقط في الغرفة فهو الجاسوس تلقائياً دون خطأ
    if (active.length == 1) {
      return [active.first.id];
    }

    final rnd = random ?? _secureRandom;
    final clampedSpies = neededSpies.clamp(1, active.length);

    // تقسيم اللاعبين إلى: من لم يكن جاسوساً بالجولة السابقة، ومن كان جاسوساً
    final nonPrevious = active
        .where((p) => !previousSpyIds.contains(p.id))
        .toList();
    final previousActive = active
        .where((p) => previousSpyIds.contains(p.id))
        .toList();

    // فحص احتمال استثناء الجاسوس السابق (3% افتراضياً)
    final bool allowPreviousException =
        previousActive.isNotEmpty && (rnd.nextDouble() < exceptionProbability);

    if (allowPreviousException && previousActive.isNotEmpty) {
      // استثناء: يُسمح لجاسوس الجولة السابقة بالتكرار بنسبة الاستثناء المضبوطة (3%)
      final shuffledPrevious = List<PlayerModel>.from(previousActive)..shuffle(rnd);
      return shuffledPrevious
          .take(clampedSpies)
          .map((p) => p.id)
          .toList();
    }

    // الحالة العامة (97%): استبعاد الجاسوس السابق تماماً من المؤهلين
    final List<PlayerModel> eligible = List<PlayerModel>.from(nonPrevious);

    // إذا لم يكن المؤهلون كافين (مثلاً غادر اللاعبون أو الجميع كانوا جواسيس)
    if (eligible.length < clampedSpies) {
      final remainingNeeded = clampedSpies - eligible.length;
      final extraPool = previousActive.where((p) => !eligible.contains(p)).toList()
        ..shuffle(rnd);
      eligible.addAll(extraPool.take(remainingNeeded));
    }

    // خلط عشوائي آمن للمؤهلين لضمان عدم الاعتماد على ترتيب القائمة أو موقع المضيف
    final shuffled = List<PlayerModel>.from(eligible)..shuffle(rnd);

    return shuffled
        .take(clampedSpies)
        .map((p) => p.id)
        .toList();
  }
}
