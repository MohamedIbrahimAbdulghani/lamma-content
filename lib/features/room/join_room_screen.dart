// Lamma - by Mohamed Ibrahim

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/row_card.dart';
import '../../data/providers/game_providers.dart';
import '../../net/client/room_client.dart';

class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  bool _isScanning = false;

  void _onQrDetected(BarcodeCapture capture) {
    if (!_isScanning) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final raw = barcode!.rawValue!;
    // Format: lamma://<host-ip>:8080/<code>
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.scheme == 'lamma') {
      setState(() => _isScanning = false);
      final host = uri.host;
      final port = uri.port != 0 ? uri.port : 8080;
      final code = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      _connectToRoom(host, port, code);
    }
  }

  Future<void> _connectToRoom(String host, int port, String code) async {
    final storage = ref.read(localStorageProvider);
    final playerName = storage.getPlayerName();
    final playerEmoji = storage.getPlayerEmoji();
    final deviceId = storage.getDeviceId();

    final roomNotifier = ref.read(roomProvider.notifier);

    final client = RoomClient(
      hostIp: host,
      port: port,
      roomCode: code,
      playerName: playerName,
      playerEmoji: playerEmoji,
      deviceId: deviceId,
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: AppColors.spyAccent),
          );
        }
      },
    );

    final success = await client.connect();
    if (success) {
      roomNotifier.setClient(client, code, host);
      if (mounted) context.push('/lobby');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isScanning) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            MobileScanner(
              onDetect: _onQrDetected,
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: IconButton(
                  onPressed: () => setState(() => _isScanning = false),
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ادخل غرفة',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Camera Scan Button
              RowCard(
                onTap: () => setState(() => _isScanning = true),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF252C54),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.photo_camera, size: 32, color: AppColors.generalAccent),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'امسح الكود',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textSecondary),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.rowGap),
              // Dialpad Code Button
              RowCard(
                onTap: () => context.push('/room/join/code'),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF252C54),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.dialpad, size: 32, color: AppColors.charadesAccent),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'اكتب الكود',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
