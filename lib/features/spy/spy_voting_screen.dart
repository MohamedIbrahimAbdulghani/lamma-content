// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/player_model.dart';
import '../../data/providers/game_providers.dart';

class SpyVotingScreen extends ConsumerStatefulWidget {
  const SpyVotingScreen({super.key});

  @override
  ConsumerState<SpyVotingScreen> createState() => _SpyVotingScreenState();
}

class _SpyVotingScreenState extends ConsumerState<SpyVotingScreen> {
  String? _selectedPlayerId;

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(gameRoomProvider);
    final players = roomState.players.isNotEmpty
        ? roomState.players
        : [
            PlayerModel(id: '1', name: 'أحمد', avatar: '🦁'),
            PlayerModel(id: '2', name: 'سارة', avatar: '🦊'),
            PlayerModel(id: '3', name: 'كريم', avatar: '🐻'),
            PlayerModel(id: '4', name: 'نور', avatar: '🐼'),
          ];

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
          'مين الجاسوس؟',
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
                child: ListView.separated(
                  itemCount: players.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final p = players[index];
                    final isSelected = p.id == _selectedPlayerId;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedPlayerId = p.id;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected
                              ? Border.all(color: AppTheme.accentCoral, width: 2)
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: isSelected
                                      ? AppTheme.accentCoral.withValues(alpha: 0.2)
                                      : const Color(0xFF25293E),
                                  child: Text(
                                    p.avatar,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? AppTheme.accentCoral
                                    : const Color(0xFF25293E),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      size: 18,
                                      color: Color(0xFF101428),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                title: 'تأكيد التصويت',
                icon: Icons.check,
                accentColor: AppTheme.accentCoral,
                onPressed: _selectedPlayerId != null
                    ? () {
                        // If selected player is spy, give last chance to guess
                        // Otherwise go straight to results
                        context.go('/spy/last-chance');
                      }
                    : null,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
