// Lamma - by Mohamed Ibrahim
import 'package:go_router/go_router.dart';
import 'app_routes.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/room/create_room_screen.dart';
import '../../features/room/join_room_screen.dart';
import '../../features/room/join_by_code_screen.dart';
import '../../features/lobby/lobby_screen.dart';
import '../../features/lobby/host_settings_spy_screen.dart';
import '../../features/lobby/host_settings_trivia_screen.dart';
import '../../features/lobby/host_settings_charades_screen.dart';
import '../../features/spy/spy_role_screen.dart';
import '../../features/spy/spy_discussion_screen.dart';
import '../../features/spy/spy_voting_screen.dart';
import '../../features/spy/spy_last_chance_screen.dart';
import '../../features/spy/spy_result_screen.dart';
import '../../features/trivia/trivia_play_screen.dart';
import '../../features/trivia/trivia_leaderboard_screen.dart';
import '../../features/charades/charades_handoff_screen.dart';
import '../../features/charades/charades_instructions_screen.dart';
import '../../features/charades/charades_play_screen.dart';
import '../../features/charades/charades_spectator_screen.dart';
import '../../features/charades/charades_round_summary_screen.dart';
import '../../features/feedback/strike_warning_screen.dart';
import '../../features/feedback/kicked_screen.dart';
import '../../features/feedback/host_left_screen.dart';
import '../../features/feedback/reconnecting_screen.dart';
import '../../features/feedback/wrong_code_screen.dart';
import '../../features/feedback/room_full_screen.dart';
import '../../features/feedback/final_results_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/about_screen.dart';
import '../../features/howto/how_to_menu_screen.dart';
import '../../features/howto/app_guide_screen.dart';
import '../../features/howto/spy_rules_screen.dart';
import '../../features/howto/trivia_rules_screen.dart';
import '../../features/howto/charades_rules_screen.dart';
import '../../features/howto/anti_cheat_rules_screen.dart';

final appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
    GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: AppRoutes.createRoom,
      builder: (context, state) {
        final mode = state.uri.queryParameters['mode'] ?? 'spy';
        return CreateRoomScreen(initialMode: mode);
      },
    ),
    GoRoute(path: AppRoutes.joinRoom, builder: (context, state) => const JoinRoomScreen()),
    // المسار الموحد لشاشة كتابة الكود
    GoRoute(path: AppRoutes.joinByCode, builder: (context, state) => const JoinByCodeScreen()),
    // تحويل المسار القديم تلقائياً لمنع أي أخطاء
    GoRoute(path: '/room/join-code', redirect: (context, state) => AppRoutes.joinByCode),
    GoRoute(path: AppRoutes.lobby, builder: (context, state) => const LobbyScreen()),
    GoRoute(path: AppRoutes.hostSettingsSpy, builder: (context, state) => const HostSettingsSpyScreen()),
    GoRoute(path: AppRoutes.hostSettingsTrivia, builder: (context, state) => const HostSettingsTriviaScreen()),
    GoRoute(path: AppRoutes.hostSettingsCharades, builder: (context, state) => const HostSettingsCharadesScreen()),
    GoRoute(path: AppRoutes.spyRole, builder: (context, state) => const SpyRoleScreen()),
    GoRoute(path: AppRoutes.spyDiscussion, builder: (context, state) => const SpyDiscussionScreen()),
    GoRoute(path: AppRoutes.spyVoting, builder: (context, state) => const SpyVotingScreen()),
    GoRoute(path: AppRoutes.spyLastChance, builder: (context, state) => const SpyLastChanceScreen()),
    GoRoute(path: AppRoutes.spyResult, builder: (context, state) => const SpyResultScreen()),
    GoRoute(path: AppRoutes.triviaPlay, builder: (context, state) => const TriviaPlayScreen()),
    GoRoute(path: AppRoutes.triviaLeaderboard, builder: (context, state) => const TriviaLeaderboardScreen()),
    GoRoute(path: AppRoutes.charadesHandoff, builder: (context, state) => const CharadesHandoffScreen()),
    GoRoute(path: AppRoutes.charadesInstructions, builder: (context, state) => const CharadesInstructionsScreen()),
    GoRoute(path: AppRoutes.charadesPlay, builder: (context, state) => const CharadesPlayScreen()),
    GoRoute(path: AppRoutes.charadesSpectator, builder: (context, state) => const CharadesSpectatorScreen()),
    GoRoute(path: AppRoutes.charadesSummary, builder: (context, state) => const CharadesRoundSummaryScreen()),
    GoRoute(path: AppRoutes.strikeWarning, builder: (context, state) => const StrikeWarningScreen()),
    GoRoute(path: AppRoutes.kicked, builder: (context, state) => const KickedScreen()),
    GoRoute(path: AppRoutes.hostLeft, builder: (context, state) => const HostLeftScreen()),
    GoRoute(path: AppRoutes.reconnecting, builder: (context, state) => const ReconnectingScreen()),
    GoRoute(path: AppRoutes.wrongCode, builder: (context, state) => const WrongCodeScreen()),
    GoRoute(path: AppRoutes.roomFull, builder: (context, state) => const RoomFullScreen()),
    GoRoute(path: AppRoutes.finalResults, builder: (context, state) => const FinalResultsScreen()),
    GoRoute(path: AppRoutes.settings, builder: (context, state) => const SettingsScreen()),
    GoRoute(path: AppRoutes.about, builder: (context, state) => const AboutScreen()),
    GoRoute(path: AppRoutes.howToMenu, builder: (context, state) => const HowToMenuScreen()),
    // تحويل المسار المختصر للتوافق
    GoRoute(path: '/howto', redirect: (context, state) => AppRoutes.howToMenu),
    GoRoute(path: AppRoutes.howToApp, builder: (context, state) => const AppGuideScreen()),
    GoRoute(path: AppRoutes.howToSpy, builder: (context, state) => const SpyRulesScreen()),
    GoRoute(path: AppRoutes.howToTrivia, builder: (context, state) => const TriviaRulesScreen()),
    GoRoute(path: AppRoutes.howToCharades, builder: (context, state) => const CharadesRulesScreen()),
    GoRoute(path: AppRoutes.howToAntiCheat, builder: (context, state) => const AntiCheatRulesScreen()),
  ],
);
