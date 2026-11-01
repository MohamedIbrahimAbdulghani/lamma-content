// Lamma - by Mohamed Ibrahim
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../data/models/player_model.dart';
import '../../data/providers/game_providers.dart';
import '../../data/services/game_content_service.dart';
import '../charades/controllers/charades_controller.dart';
import '../trivia/presentation/controllers/trivia_controller.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  bool _isStarting = false;

  Future<void> _handleStartGame(GameType currentGame) async {
    if (_isStarting) return;
    setState(() => _isStarting = true);

    final roomNotifier = ref.read(gameRoomProvider.notifier);
    final roomServer = roomNotifier.server;
    final contentService = ref.read(gameContentServiceProvider);

    try {
      // 1. مهلة لانتظار بصمات اللاعبين المنضمين (حوالي 2 ثانية كحد أقصى)
      if (roomServer != null) {
        await Future.any([
          Future.delayed(const Duration(milliseconds: 300)),
          Future.delayed(const Duration(seconds: 2)),
        ]);
      }

      // 2. تحديث حالة الغرفة لبدء اللعبة
      roomNotifier.startGame();

      // 3. تحضير المحتوى وبدء اللعبة مع مهلة قصوى 6 ثوانٍ
      switch (currentGame) {
        case GameType.spy:
          final spySettings = ref.read(spySettingsProvider);
          final bootstrap = ref.read(bootstrapProvider);

          await roomNotifier.startSpyGameRound(
            packSlug: spySettings.wordPack,
            bootstrapData: bootstrap.data,
            totalRounds: spySettings.rounds,
            isNewGame: true,
          ).timeout(
            const Duration(seconds: 6),
            onTimeout: () {
              debugPrint('Spy game round start timed out after 6s. Proceeding with fallback.');
            },
          );

          if (contentService.hasRecycledSpy && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم استهلاك بنك الكلمات المتاح. اتصل بالإنترنت لمحتوى جديد 🌐'),
                duration: Duration(seconds: 3),
              ),
            );
            contentService.hasRecycledSpy = false;
          }

          if (mounted) {
            context.go(AppRoutes.spyRole);
          }
          break;

        case GameType.trivia:
          final triviaSettings = ref.read(triviaSettingsProvider);
          final bootstrap = ref.read(bootstrapProvider);

          final questions = await contentService.getTriviaQuestions(
            count: triviaSettings.questionsCount,
            categories: triviaSettings.categories,
            difficulty: triviaSettings.difficulty,
            bootstrapData: bootstrap.data,
            externalSeenPromptHashes: roomServer?.getAllSeenTriviaPromptHashes(),
            externalSeenAnswerHashes: roomServer?.getAllSeenTriviaAnswerHashes(),
          ).timeout(
            const Duration(seconds: 6),
            onTimeout: () {
              debugPrint('Trivia content preparation timed out after 6s. Using local fallback.');
              return contentService.getFallbackTriviaQuestions(
                count: triviaSettings.questionsCount,
                categories: triviaSettings.categories,
                difficulty: triviaSettings.difficulty,
              );
            },
          );

          if (contentService.hasRecycledTrivia && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم استهلاك بنك الأسئلة المتاح. اتصل بالإنترنت لمحتوى جديد 🌐'),
                duration: Duration(seconds: 3),
              ),
            );
            contentService.hasRecycledTrivia = false;
          }

          await ref.read(triviaGameProvider.notifier).restartGame(
                newQuestions: questions,
                questionCount: triviaSettings.questionsCount,
                totalSeconds: triviaSettings.timePerQuestion,
                categories: triviaSettings.categories,
                difficulty: triviaSettings.difficulty,
              );

          roomNotifier.startTriviaGameRound(
            questions: questions,
            timePerQuestion: triviaSettings.timePerQuestion,
          );

          if (mounted) {
            context.go(AppRoutes.triviaPlay);
          }
          break;

        case GameType.charades:
          final charadesSettings = ref.read(charadesSettingsProvider);

          await ref.read(charadesGameProvider.notifier).initGame().timeout(
            const Duration(seconds: 6),
            onTimeout: () {
              debugPrint('Charades content preparation timed out after 6s. Proceeding with available stock.');
            },
          );

          if (contentService.hasRecycledCharades && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم استهلاك بنك الكلمات المتاح. اتصل بالإنترنت لمحتوى جديد 🌐'),
                duration: Duration(seconds: 3),
              ),
            );
            contentService.hasRecycledCharades = false;
          }

          roomNotifier.startCharadesGameRound(
            roundSeconds: charadesSettings.roundSeconds,
          );

          if (mounted) {
            context.go(AppRoutes.charadesHandoff);
          }
          break;
      }
    } catch (e, stack) {
      debugPrint('Error starting game: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر بدء اللعبة: $e'),
            backgroundColor: AppTheme.accentCoral,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
      roomNotifier.resetStartingGuard();
    }
  }

  void _showChangeGameSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: Text(
                    'اختر نوع اللعبة',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...GameType.values.map((game) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        ref.read(selectedGame.notifier).state = game;
                        ref.read(gameRoomProvider.notifier).setSelectedGame(game);
                        Navigator.of(ctx).pop();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.bg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: game.accentColor.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(game.emoji, style: const TextStyle(fontSize: 26)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    game.title,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    game.shortDescription,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(gameRoomProvider);
    final isHost = roomState.isHost;
    final players = roomState.players.isNotEmpty
        ? roomState.players
        : [
            const PlayerModel(id: '1', name: 'أحمد', avatar: '🦁', isHost: true),
            const PlayerModel(id: '2', name: 'سارة', avatar: '🦊'),
            const PlayerModel(id: '3', name: 'كريم', avatar: '🐻'),
            const PlayerModel(id: '4', name: 'نور', avatar: '🐼'),
            const PlayerModel(id: '5', name: 'عمر', avatar: '🐯'),
            const PlayerModel(id: '6', name: 'ياسمين', avatar: '🐨'),
          ];

    final currentGame = roomState.selectedGame;

    // استماع لانتقال اللعبة للعميل المنضم عند بدء أي لعبة من المضيف
    ref.listen<ActiveRoomState>(gameRoomProvider, (previous, next) {
      if (!isHost && next.hostLeft) {
        if (context.mounted) {
          context.go(AppRoutes.hostLeft);
        }
        return;
      }
      if (!isHost && next.isKicked) {
        if (context.mounted) {
          context.go(AppRoutes.kicked);
        }
        return;
      }
      if (!isHost &&
          next.currentPhase == 'role_hidden' &&
          next.gameMode == 'spy') {
        if (context.mounted) {
          context.go(AppRoutes.spyRole);
        }
      }
      if (!isHost &&
          next.currentPhase == 'trivia_question' &&
          next.triviaQuestions.isNotEmpty) {
        ref.read(triviaGameProvider.notifier).restartGame(
              newQuestions: next.triviaQuestions,
              questionCount: next.totalQuestions,
              totalSeconds: next.timerSeconds > 0 ? next.timerSeconds : 15,
            );
        if (context.mounted) {
          context.go(AppRoutes.triviaPlay);
        }
      }
      if (!isHost &&
          (next.currentPhase == 'charades_play' ||
              (next.gameMode == 'charades' && next.currentPhase == 'charades_play'))) {
        if (context.mounted) {
          context.go(AppRoutes.charadesSpectator);
        }
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg.withValues(alpha: 0.8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward, color: Colors.white),
          onPressed: () {
            ref.read(gameRoomProvider.notifier).leaveRoom();
            context.go(AppRoutes.home);
          },
        ),
        title: const Text(
          'اللوبي',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    // Top Bar: Room Code & Copy
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.tag, color: AppTheme.accentSaffron, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                'كود الغرفة: ${roomState.roomCode}',
                                style: const TextStyle(
                                  color: AppTheme.accentSaffron,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: roomState.roomCode));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم نسخ الكود!'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                child: const Icon(Icons.content_copy, color: AppTheme.textSecondary, size: 18),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${players.length} لاعبين',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Players Section
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'الصحبة في اللوبي',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Grid of 2 columns
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.25,
                      ),
                      itemCount: players.length,
                      itemBuilder: (context, index) {
                        final p = players[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: const Color(0xFF25293E),
                                    child: Text(
                                      p.avatar,
                                      style: const TextStyle(fontSize: 26),
                                    ),
                                  ),
                                  if (p.isHost)
                                    Positioned(
                                      top: -6,
                                      left: -6,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: AppTheme.accentSaffron,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Text('👑', style: TextStyle(fontSize: 12)),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Selected Game Section
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'اللعبة المختارة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildSelectedGameCard(
                      game: currentGame,
                      isHost: isHost,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Bottom Actions
              const SizedBox(height: 12),
              if (isHost) ...[
                SecondaryButton(
                  title: 'إعدادات اللعبة',
                  icon: Icons.tune,
                  onPressed: () {
                    switch (currentGame) {
                      case GameType.spy:
                        context.push(AppRoutes.hostSettingsSpy);
                        break;
                      case GameType.trivia:
                        context.push(AppRoutes.hostSettingsTrivia);
                        break;
                      case GameType.charades:
                        context.push(AppRoutes.hostSettingsCharades);
                        break;
                    }
                  },
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  title: 'ابدأ اللعبة',
                  icon: Icons.play_arrow,
                  accentColor: currentGame.accentColor,
                  isLoading: _isStarting,
                  onPressed: _isStarting ? null : () => _handleStartGame(currentGame),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text(
                      'في انتظار صاحب الغرفة يبدأ اللعبة...',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Mohamed Ibrahim',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // كارت اللعبة المختارة مع زر "تغيير" للمضيف
  Widget _buildSelectedGameCard({
    required GameType game,
    required bool isHost,
  }) {
    final accent = game.accentColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              game.emoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  game.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  game.shortDescription,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
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
