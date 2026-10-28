// Lamma - by Mohamed Ibrahim

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/row_card.dart';
import '../../data/models/player_model.dart';
import '../../data/providers/game_providers.dart';
import '../../net/server/room_server.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  final String initialMode;

  const CreateRoomScreen({
    super.key,
    this.initialMode = 'spy',
  });

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  late String _roomCode;
  String _hostIp = '127.0.0.1';

  @override
  void initState() {
    super.initState();
    _roomCode = (1000 + Random().nextInt(9000)).toString();
    _initHostServer();
  }

  Future<void> _initHostServer() async {
    final storage = ref.read(localStorageProvider);
    final playerName = storage.getPlayerName();
    final playerEmoji = storage.getPlayerEmoji();
    final deviceId = storage.getDeviceId();

    // Get Wi-Fi IP
    try {
      final info = NetworkInfo();
      final wifiIp = await info.getWifiIP();
      if (wifiIp != null && wifiIp.isNotEmpty) {
        _hostIp = wifiIp;
      }
    } catch (_) {}

    final hostPlayer = PlayerModel(
      id: deviceId,
      name: '$playerName (المضيف)',
      emoji: playerEmoji,
      isHost: true,
    );

    final chosenGame = ref.read(selectedGame);
    final roomNotifier = ref.read(roomProvider.notifier);

    final server = RoomServer(
      roomCode: _roomCode,
      hostPlayer: hostPlayer,
      onStateChanged: (state) {
        if (mounted) {
          roomNotifier.updateFromNetwork(state);
        }
      },
      onStrikeToast: (msg) {
        if (mounted) {
          roomNotifier.showStrikeToast(msg);
        }
      },
    );

    await server.start();
    server.updateGameMode(chosenGame.name);
    roomNotifier.setHostServer(server, _roomCode, _hostIp);
    roomNotifier.setSelectedGame(chosenGame);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomProvider);

    // QR Payload: JSON or URI containing ip, port, code
    final qrData = 'lamma://$_hostIp:8080/$_roomCode';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Top Back & Header
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      ref.read(roomProvider.notifier).leaveRoom();
                      context.pop();
                    },
                    icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 24),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'غرفتك جاهزة',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // QR & Code Card
              RowCard(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Column(
                  children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 176,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _roomCode,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: AppColors.generalAccent,
                        letterSpacing: 8,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'خلّي صحابك يمسحوا الكود',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'IP: $_hostIp:8080',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Joined Players List
              const Text(
                'اللاعبين المنضمين',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: roomState.players.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final player = roomState.players[index];
                    return RowCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Text(player.emoji, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              player.name,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (player.isHost)
                            const Icon(Icons.star, color: AppColors.generalAccent, size: 20),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              // Enter Lobby Button
              PrimaryButton(
                label: 'ادخل اللوبي',
                backgroundColor: AppColors.generalAccent,
                onPressed: () => context.push('/lobby'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
