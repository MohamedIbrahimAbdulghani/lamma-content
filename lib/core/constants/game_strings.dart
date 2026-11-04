// Lamma - Game Strings & Localization Constants
// Mohamed Ibrahim

abstract class GameStrings {
  // الحوارات وأزرار الرجوع
  static const String hostReturnDialogTitle = 'الرجوع للوبي ⚠️';
  static const String hostReturnDialogMessage =
      'الرجوع للوبي سيلغي هذه الجولة. هل تريد المتابعة؟';
  static const String hostReturnConfirmButton = 'نعم، الرجوع للوبي';

  static const String playerLeaveDialogTitle = 'مغادرة الغرفة 🚪';
  static const String playerLeaveDialogMessage = 'هل تريد مغادرة الغرفة؟';
  static const String playerLeaveConfirmButton = 'نعم، مغادرة';

  static const String cancelDialogButton = 'إلغاء';

  // تنبيهات الغرفة واللاعبين
  static const String insufficientPlayersTitle = 'نقص في عدد اللاعبين ⚠️';
  static const String insufficientPlayersMessage =
      'تم إنهاء الجولة والعودة للوبي لعدم وجود لاعبين كافيين لاستمرار اللعبة.';

  static const String hostLeftTitle = 'المضيف خرج من اللعبة';
  static const String reconnectingMessage = 'بنحاول نرجّعك للغرفة...';
  static const String roundCancelledReturnedToLobby = 'تم إلغاء الجولة والعودة للوبي';
}
