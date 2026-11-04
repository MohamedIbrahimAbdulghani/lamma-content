// Lamma - by Mohamed Ibrahim
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/category_localization.dart';
import '../../core/widgets/content_preparation_dialog.dart';
import '../../core/widgets/honest_exhaustion_dialog.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../data/models/player_model.dart';
import '../../data/models/question_model.dart';
import '../../data/providers/game_providers.dart';
import '../../data/services/game_content_service.dart';
import '../charades/controllers/charades_controller.dart';
import '../trivia/presentation/controllers/trivia_controller.dart';

class FinalResultsScreen extends ConsumerWidget {
  const FinalResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomState = ref.watch(gameRoomProvider);
    final triviaState = ref.watch(triviaGameProvider);

    final rawPlayers = (roomState.selectedGame == GameType.trivia && triviaState.players.isNotEmpty)
        ? triviaState.players
        : (roomState.players.isNotEmpty ? roomState.players : const <PlayerModel>[]);

    final players = rawPlayers.isNotEmpty
        ? rawPlayers
        : [
            const PlayerModel(id: '1', name: 'أحمد', avatar: '🦁', score: 1240),
            const PlayerModel(id: '2', name: 'سارة', avatar: '🦊', score: 980),
            const PlayerModel(id: '3', name: 'كريم', avatar: '🐻', score: 720),
            const PlayerModel(id: '4', name: 'نور', avatar: '🐼', score: 540),
            const PlayerModel(id: '5', name: 'عمر', avatar: '🐯', score: 410),
          ];

    final sorted = [...players]..sort((a, b) => b.score.compareTo(a.score));
    final first = sorted.isNotEmpty ? sorted[0] : null;
    final second = sorted.length > 1 ? sorted[1] : null;
    final third = sorted.length > 2 ? sorted[2] : null;
    final rest = sorted.length > 3 ? sorted.sublist(3) : <PlayerModel>[];

    final rank2 = (second != null && first != null && second.score == first.score) ? 1 : 2;
    final rank3 = (third != null && second != null && third.score == second.score)
        ? rank2
        : ((third != null && first != null && third.score == first.score) ? 1 : 3);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward, color: Colors.white),
          onPressed: () => context.go('/lobby'),
        ),
        title: const Text(
          'الترتيب النهائي 🏆',
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
                    const SizedBox(height: 12),
                    // Podium Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 2nd Place (Right side in RTL)
                        if (second != null)
                          Expanded(
                            child: _buildPodiumStep(
                              player: second,
                              rank: rank2,
                              title: 'فضة 🥈',
                              height: 110,
                              rankColor: AppTheme.textSecondary,
                            ),
                          )
                        else
                          const Spacer(),
                        const SizedBox(width: 8),

                        // 1st Place (Center, tallest)
                        if (first != null)
                          Expanded(
                            child: _buildPodiumStep(
                              player: first,
                              rank: 1,
                              title: 'البطل 🥇',
                              height: 150,
                              rankColor: AppTheme.accentSaffron,
                              isChampion: true,
                            ),
                          )
                        else
                          const Spacer(),
                        const SizedBox(width: 8),

                        // 3rd Place (Left side in RTL)
                        if (third != null)
                          Expanded(
                            child: _buildPodiumStep(
                              player: third,
                              rank: rank3,
                              title: 'برونز 🥉',
                              height: 90,
                              rankColor: const Color(0xFFD3C5AD),
                            ),
                          )
                        else
                          const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Rest of players
                    ...rest.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    p.avatar,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${p.score} نقطة',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // زراير النهاية: العب تاني ورجوع للقائمة
              PrimaryButton(
                title: 'العب تاني 🔄',
                icon: Icons.replay,
                accentColor: AppTheme.accentSaffron,
                onPressed: () => _handlePlayAgain(context, ref),
              ),
              const SizedBox(height: 10),
              SecondaryButton(
                title: 'رجوع للقائمة 🚪',
                icon: Icons.exit_to_app,
                onPressed: () {
                  context.go('/lobby');
                },
              ),
              const SizedBox(height: 8),
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

  Widget _buildPodiumStep({
    required PlayerModel player,
    required int rank,
    required String title,
    required double height,
    required Color rankColor,
    bool isChampion = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isChampion)
          const Text('👑', style: TextStyle(fontSize: 22))
        else
          const SizedBox(height: 22),
        const SizedBox(height: 4),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: isChampion ? 32 : 26,
              backgroundColor: isChampion
                  ? AppTheme.accentSaffron
                  : AppTheme.cardBg,
              child: Text(
                player.avatar,
                style: TextStyle(fontSize: isChampion ? 32 : 26),
              ),
            ),
            Positioned(
              bottom: -8,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: rankColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF101428),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          player.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          '${player.score} نقطة',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: rankColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: isChampion ? const Color(0xFF25293E) : AppTheme.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: rankColor,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handlePlayAgain(BuildContext context, WidgetRef ref) async {
    final navContext = context;
    final roomState = ref.read(gameRoomProvider);
    final contentService = ref.read(gameContentServiceProvider);

    try {
      if (roomState.selectedGame == GameType.trivia) {
        final triviaSettings = ref.read(triviaSettingsProvider);
        final neededCount = triviaSettings.questionsCount;
        final cats = triviaSettings.categories.toList();
        final diff = triviaSettings.difficulty;
        final catLabel = CategoryLocalization.getTriviaCategoriesLabel(cats);

        final available = contentService.getAvailableTriviaCount(
          categories: cats,
          difficulty: diff,
          roomCode: roomState.roomCode,
        );

        if (available < neededCount) {
          final progressNotifier = ValueNotifier<int>(available);
          final statusNotifier = ValueNotifier<String?>('نجهّز أسئلة جديدة لك... $available من $neededCount');
          final cancelToken = CancelToken();
          List<QuestionModel> preparedQuestions = [];

          final result = await ContentPreparationDialog.show(
            navContext,
            gameTitle: 'تحدي الشلة',
            categoryName: catLabel,
            targetCount: neededCount,
            accentColor: AppTheme.accentSaffron,
            progressNotifier: progressNotifier,
            statusNotifier: statusNotifier,
            onStartGeneration: () async {
              try {
                preparedQuestions = await contentService.getTriviaQuestions(
                  count: neededCount,
                  categories: cats,
                  difficulty: diff,
                  roomCode: roomState.roomCode.isNotEmpty ? roomState.roomCode : null,
                  onProgress: (current, target) {
                    progressNotifier.value = current;
                    statusNotifier.value = 'نجهّز أسئلة جديدة لك... $current من $target';
                  },
                  cancelToken: cancelToken,
                );
                return preparedQuestions.length >= neededCount;
              } catch (_) {
                rethrow;
              }
            },
            onCancel: () {
              cancelToken.cancel();
            },
          );

          if (result == null || result.type == PreparationResultType.cancelled) {
            return;
          }

          if (result.type == PreparationResultType.error) {
            if (!navContext.mounted) return;
            await HonestExhaustionDialog.show(
              navContext,
              gameTitle: 'تحدي الشلة',
              reason: result.errorMessage ?? 'تعذر تجهيز أسئلة جديدة في قسم $catLabel',
              onRetry: () {
                Navigator.of(navContext, rootNavigator: true).pop();
                _handlePlayAgain(navContext, ref);
              },
              onReuseSeen: () async {
                Navigator.of(navContext, rootNavigator: true).pop();
                await contentService.resetAllHistory();
                if (!navContext.mounted) return;
                await ref.read(triviaGameProvider.notifier).restartGame(
                  questionCount: neededCount,
                  categories: cats,
                  difficulty: diff,
                );
                if (navContext.mounted) navContext.go('/trivia/question');
              },
              onTryLater: () {
                Navigator.of(navContext, rootNavigator: true).pop();
                if (navContext.mounted) navContext.go('/lobby');
              },
            );
            return;
          }

          final countToUse = (result.type == PreparationResultType.partialStart && result.count > 0)
              ? result.count
              : (preparedQuestions.isNotEmpty ? preparedQuestions.length : neededCount);

          await ref.read(triviaGameProvider.notifier).restartGame(
            newQuestions: preparedQuestions.isNotEmpty ? preparedQuestions : null,
            questionCount: countToUse,
            categories: cats,
            difficulty: diff,
          );
          if (navContext.mounted) {
            navContext.go('/trivia/question');
          }
          return;
        }

        // Available is sufficient
        await ref.read(triviaGameProvider.notifier).restartGame(
          questionCount: neededCount,
          categories: cats,
          difficulty: diff,
        );
        if (navContext.mounted) {
          navContext.go('/trivia/question');
        }
        unawaited(contentService.autoReplenishTriviaIfNeeded(
          requiredCount: neededCount,
          categories: cats,
          difficulty: diff,
          roomCode: roomState.roomCode,
        ));
      } else if (roomState.selectedGame == GameType.charades) {
        final charadesSettings = ref.read(charadesSettingsProvider);
        final playersCount = roomState.players.isNotEmpty ? roomState.players.length : 4;
        final wordsPerTurn = charadesSettings.wordsPerTurn > 0 ? charadesSettings.wordsPerTurn : 10;
        final neededCount = charadesSettings.roundsPerPlayer * playersCount * wordsPerTurn;
        final cat = charadesSettings.category;
        final catLabel = CategoryLocalization.getCharadesCategoryName(cat);

        final available = contentService.getAvailableCharadesCount(category: cat, roomCode: roomState.roomCode);
        if (available < neededCount) {
          final progressNotifier = ValueNotifier<int>(available);
          final statusNotifier = ValueNotifier<String?>('نجهّز كلمات تمثيل جديدة... $available من $neededCount');
          final cancelToken = CancelToken();

          final result = await ContentPreparationDialog.show(
            navContext,
            gameTitle: 'مثّل ومتتكلمش',
            categoryName: catLabel,
            targetCount: neededCount,
            accentColor: AppTheme.accentMint,
            progressNotifier: progressNotifier,
            statusNotifier: statusNotifier,
            onStartGeneration: () async {
              await contentService.autoReplenishCharadesIfNeeded(
                requiredCount: neededCount,
                category: cat,
                roomCode: roomState.roomCode,
                onProgress: (cur, tot) {
                  progressNotifier.value = cur;
                  statusNotifier.value = 'نجهّز كلمات تمثيل جديدة... $cur من $tot';
                },
                cancelToken: cancelToken,
              );
              return true;
            },
            onCancel: () => cancelToken.cancel(),
          );

          if (result == null || result.type == PreparationResultType.cancelled) return;
          if (result.type == PreparationResultType.error) {
            if (!navContext.mounted) return;
            await HonestExhaustionDialog.show(
              navContext,
              gameTitle: 'مثّل ومتتكلمش',
              reason: result.errorMessage ?? 'تعذر تجهيز كلمات جديدة في قسم $catLabel',
              onRetry: () {
                Navigator.of(navContext, rootNavigator: true).pop();
                _handlePlayAgain(navContext, ref);
              },
              onReuseSeen: () async {
                Navigator.of(navContext, rootNavigator: true).pop();
                await contentService.resetAllHistory();
                if (!navContext.mounted) return;
                await ref.read(charadesGameProvider.notifier).restartGame(
                  category: cat,
                  roundSeconds: charadesSettings.roundSeconds,
                  roundsPerPlayer: charadesSettings.roundsPerPlayer,
                  wordsPerTurn: charadesSettings.wordsPerTurn,
                );
                if (navContext.mounted) navContext.go('/charades/handoff');
              },
              onTryLater: () {
                Navigator.of(navContext, rootNavigator: true).pop();
                if (navContext.mounted) navContext.go('/lobby');
              },
            );
            return;
          }
        }

        await ref.read(charadesGameProvider.notifier).restartGame(
          category: cat,
          roundSeconds: charadesSettings.roundSeconds,
          roundsPerPlayer: charadesSettings.roundsPerPlayer,
          wordsPerTurn: charadesSettings.wordsPerTurn,
        );
        if (navContext.mounted) {
          navContext.go('/charades/handoff');
        }
        unawaited(contentService.autoReplenishCharadesIfNeeded(
          requiredCount: neededCount,
          category: cat,
          roomCode: roomState.roomCode,
        ));
      } else {
        final settings = ref.read(spySettingsProvider);
        final bootstrap = ref.read(bootstrapProvider);
        final pack = settings.wordPack;
        final packLabel = CategoryLocalization.getSpyPackName(pack);
        final neededCount = settings.rounds;

        final available = contentService.getAvailableSpyCount(packSlug: pack, roomCode: roomState.roomCode);
        if (available < neededCount) {
          final progressNotifier = ValueNotifier<int>(available);
          final statusNotifier = ValueNotifier<String?>('نجهّز جولات سرية جديدة... $available من $neededCount');
          final cancelToken = CancelToken();

          final result = await ContentPreparationDialog.show(
            navContext,
            gameTitle: 'مين الجاسوس',
            categoryName: packLabel,
            targetCount: neededCount,
            accentColor: AppTheme.accentCoral,
            progressNotifier: progressNotifier,
            statusNotifier: statusNotifier,
            onStartGeneration: () async {
              await contentService.autoReplenishSpyIfNeeded(
                requiredCount: neededCount,
                packSlug: pack,
                roomCode: roomState.roomCode,
                onProgress: (cur, tot) {
                  progressNotifier.value = cur;
                  statusNotifier.value = 'نجهّز جولات سرية جديدة... $cur من $tot';
                },
                cancelToken: cancelToken,
              );
              return true;
            },
            onCancel: () => cancelToken.cancel(),
          );

          if (result == null || result.type == PreparationResultType.cancelled) return;
          if (result.type == PreparationResultType.error) {
            if (!navContext.mounted) return;
            await HonestExhaustionDialog.show(
              navContext,
              gameTitle: 'مين الجاسوس',
              reason: result.errorMessage ?? 'تعذر تجهيز كلمات جديدة لحزمة $packLabel',
              onRetry: () {
                Navigator.of(navContext, rootNavigator: true).pop();
                _handlePlayAgain(navContext, ref);
              },
              onReuseSeen: () async {
                Navigator.of(navContext, rootNavigator: true).pop();
                await contentService.resetAllHistory();
                if (!navContext.mounted) return;
                await ref.read(gameRoomProvider.notifier).startSpyGameRound(
                  packSlug: pack,
                  bootstrapData: bootstrap.data,
                  totalRounds: settings.rounds,
                  isNewGame: true,
                );
                if (navContext.mounted) navContext.go('/spy/role');
              },
              onTryLater: () {
                Navigator.of(navContext, rootNavigator: true).pop();
                if (navContext.mounted) navContext.go('/lobby');
              },
            );
            return;
          }
        }

        await ref.read(gameRoomProvider.notifier).startSpyGameRound(
          packSlug: pack,
          bootstrapData: bootstrap.data,
          totalRounds: settings.rounds,
          isNewGame: true,
        );
        if (navContext.mounted) {
          navContext.go('/spy/role');
        }
        unawaited(contentService.autoReplenishSpyIfNeeded(
          requiredCount: neededCount,
          packSlug: pack,
          roomCode: roomState.roomCode,
        ));
      }
    } on InsufficientTriviaQuestionsException catch (e) {
      if (navContext.mounted) {
        await HonestExhaustionDialog.show(
          navContext,
          gameTitle: 'تحدي الشلة',
          reason: e.toString(),
          onRetry: () {
            Navigator.of(navContext, rootNavigator: true).pop();
            _handlePlayAgain(navContext, ref);
          },
          onReuseSeen: () async {
            Navigator.of(navContext, rootNavigator: true).pop();
            await contentService.resetAllHistory();
            if (!navContext.mounted) return;
            final triviaSettings = ref.read(triviaSettingsProvider);
            await ref.read(triviaGameProvider.notifier).restartGame(
              questionCount: triviaSettings.questionsCount,
              categories: triviaSettings.categories.toList(),
              difficulty: triviaSettings.difficulty,
            );
            if (navContext.mounted) navContext.go('/trivia/question');
          },
          onTryLater: () {
            Navigator.of(navContext, rootNavigator: true).pop();
            if (navContext.mounted) navContext.go('/lobby');
          },
        );
      }
    } on InsufficientCharadesWordsException catch (e) {
      if (navContext.mounted) {
        await HonestExhaustionDialog.show(
          navContext,
          gameTitle: 'مثّل ومتتكلمش',
          reason: e.toString(),
          onRetry: () {
            Navigator.of(navContext, rootNavigator: true).pop();
            _handlePlayAgain(navContext, ref);
          },
          onReuseSeen: () async {
            Navigator.of(navContext, rootNavigator: true).pop();
            await contentService.resetAllHistory();
            if (!navContext.mounted) return;
            final charadesSettings = ref.read(charadesSettingsProvider);
            await ref.read(charadesGameProvider.notifier).restartGame(
              category: charadesSettings.category,
              roundSeconds: charadesSettings.roundSeconds,
              roundsPerPlayer: charadesSettings.roundsPerPlayer,
              wordsPerTurn: charadesSettings.wordsPerTurn,
            );
            if (navContext.mounted) navContext.go('/charades/handoff');
          },
          onTryLater: () {
            Navigator.of(navContext, rootNavigator: true).pop();
            if (navContext.mounted) navContext.go('/lobby');
          },
        );
      }
    } on InsufficientSpyWordsException catch (e) {
      if (navContext.mounted) {
        await HonestExhaustionDialog.show(
          navContext,
          gameTitle: 'مين الجاسوس',
          reason: e.toString(),
          onRetry: () {
            Navigator.of(navContext, rootNavigator: true).pop();
            _handlePlayAgain(navContext, ref);
          },
          onReuseSeen: () async {
            Navigator.of(navContext, rootNavigator: true).pop();
            await contentService.resetAllHistory();
            if (!navContext.mounted) return;
            final settings = ref.read(spySettingsProvider);
            final bootstrap = ref.read(bootstrapProvider);
            await ref.read(gameRoomProvider.notifier).startSpyGameRound(
              packSlug: settings.wordPack,
              bootstrapData: bootstrap.data,
              totalRounds: settings.rounds,
              isNewGame: true,
            );
            if (navContext.mounted) navContext.go('/spy/role');
          },
          onTryLater: () {
            Navigator.of(navContext, rootNavigator: true).pop();
            if (navContext.mounted) navContext.go('/lobby');
          },
        );
      }
    } catch (e) {
      if (navContext.mounted) {
        ScaffoldMessenger.of(navContext).showSnackBar(
          SnackBar(
            content: Text('تعذر بدء لعبة جديدة: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
