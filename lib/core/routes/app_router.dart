// Lamma - by Mohamed Ibrahim
import 'package:go_router/go_router.dart';
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
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/room/create',
      builder: (context, state) {
        final mode = state.uri.queryParameters['mode'] ?? 'spy';
        return CreateRoomScreen(initialMode: mode);
      },
    ),
    GoRoute(path: '/room/join', builder: (context, state) => const JoinRoomScreen()),
    GoRoute(path: '/room/join-code', builder: (context, state) => const JoinByCodeScreen()),
    GoRoute(path: '/lobby', builder: (context, state) => const LobbyScreen()),
    GoRoute(path: '/host-settings/spy', builder: (context, state) => const HostSettingsSpyScreen()),
    GoRoute(path: '/host-settings/trivia', builder: (context, state) => const HostSettingsTriviaScreen()),
    GoRoute(path: '/host-settings/charades', builder: (context, state) => const HostSettingsCharadesScreen()),
    GoRoute(path: '/spy/role', builder: (context, state) => const SpyRoleScreen()),
    GoRoute(path: '/spy/discussion', builder: (context, state) => const SpyDiscussionScreen()),
    GoRoute(path: '/spy/voting', builder: (context, state) => const SpyVotingScreen()),
    GoRoute(path: '/spy/last-chance', builder: (context, state) => const SpyLastChanceScreen()),
    GoRoute(path: '/spy/result', builder: (context, state) => const SpyResultScreen()),
    GoRoute(path: '/trivia/question', builder: (context, state) => const TriviaPlayScreen()),
    GoRoute(path: '/trivia/leaderboard', builder: (context, state) => const TriviaLeaderboardScreen()),
    GoRoute(path: '/charades/handoff', builder: (context, state) => const CharadesHandoffScreen()),
    GoRoute(path: '/charades/instructions', builder: (context, state) => const CharadesInstructionsScreen()),
    GoRoute(path: '/charades/play', builder: (context, state) => const CharadesPlayScreen()),
    GoRoute(path: '/charades/spectator', builder: (context, state) => const CharadesSpectatorScreen()),
    GoRoute(path: '/charades/summary', builder: (context, state) => const CharadesRoundSummaryScreen()),
    GoRoute(path: '/feedback/strike-warning', builder: (context, state) => const StrikeWarningScreen()),
    GoRoute(path: '/feedback/kicked', builder: (context, state) => const KickedScreen()),
    GoRoute(path: '/feedback/host-left', builder: (context, state) => const HostLeftScreen()),
    GoRoute(path: '/feedback/reconnecting', builder: (context, state) => const ReconnectingScreen()),
    GoRoute(path: '/feedback/wrong-code', builder: (context, state) => const WrongCodeScreen()),
    GoRoute(path: '/feedback/room-full', builder: (context, state) => const RoomFullScreen()),
    GoRoute(path: '/feedback/final-results', builder: (context, state) => const FinalResultsScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
    GoRoute(path: '/how-to', builder: (context, state) => const HowToMenuScreen()),
    GoRoute(path: '/how-to/app', builder: (context, state) => const AppGuideScreen()),
    GoRoute(path: '/how-to/spy', builder: (context, state) => const SpyRulesScreen()),
    GoRoute(path: '/how-to/trivia', builder: (context, state) => const TriviaRulesScreen()),
    GoRoute(path: '/how-to/charades', builder: (context, state) => const CharadesRulesScreen()),
    GoRoute(path: '/how-to/anti-cheat', builder: (context, state) => const AntiCheatRulesScreen()),
  ],
);
