// Lamma - by Mohamed Ibrahim

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/providers/game_providers.dart';
import '../../net/client/room_client.dart';

class JoinByCodeScreen extends ConsumerStatefulWidget {
  const JoinByCodeScreen({super.key});

  @override
  ConsumerState<JoinByCodeScreen> createState() => _JoinByCodeScreenState();
}

class _JoinByCodeScreenState extends ConsumerState<JoinByCodeScreen> {
  String _code = '';
  final TextEditingController _ipController = TextEditingController();
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _detectLocalSubnet();
  }

  Future<void> _detectLocalSubnet() async {
    try {
      final info = NetworkInfo();
      final wifiIp = await info.getWifiIP();
      if (wifiIp != null && wifiIp.isNotEmpty) {
        final segments = wifiIp.split('.');
        if (segments.length == 4) {
          _ipController.text = '${segments[0]}.${segments[1]}.${segments[2]}.';
        }
      }
    } catch (_) {}
  }

  void _onDigitPress(String digit) {
    if (_code.length < 4) {
      setState(() {
        _code += digit;
      });
    }
  }

  void _onBackspace() {
    if (_code.isNotEmpty) {
      setState(() {
        _code = _code.substring(0, _code.length - 1);
      });
    }
  }

  Future<void> _submitJoin() async {
    if (_code.length != 4) return;
    final host = _ipController.text.trim();
    if (host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب عنوان IP الخاص بالمضيف')),
      );
      return;
    }

    setState(() => _isConnecting = true);

    final storage = ref.read(localStorageProvider);
    final playerName = storage.getPlayerName();
    final playerEmoji = storage.getPlayerEmoji();
    final deviceId = storage.getDeviceId();

    final roomNotifier = ref.read(roomProvider.notifier);

    final client = RoomClient(
      hostIp: host,
      port: 8080,
      roomCode: _code,
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
    setState(() => _isConnecting = false);

    if (success) {
      roomNotifier.setClient(client, _code, host);
      if (mounted) context.push('/lobby');
    } else {
      if (mounted) {
        context.push('/feedback/wrong-code');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'اكتب كود الغرفة',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              // Optional Host IP input (for Wi-Fi targeting)
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _ipController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'عنوان IP المضيف (مثلاً: 192.168.1.8)',
                    hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // 4 Code Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final hasDigit = index < _code.length;
                  final digit = hasDigit ? _code[index] : '';
                  return Container(
                    width: 64,
                    height: 64,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: hasDigit
                          ? Border.all(color: AppColors.generalAccent, width: 2)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      digit,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppColors.generalAccent,
                      ),
                    ),
                  );
                }),
              ),
              const Spacer(),
              // Custom Numeric Keypad
              _buildKeypad(),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'انضم',
                isLoading: _isConnecting,
                backgroundColor: AppColors.generalAccent,
                onPressed: _code.length == 4 ? _submitJoin : null,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['1', '2', '3'].map((d) => _buildKey(d)).toList(),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['4', '5', '6'].map((d) => _buildKey(d)).toList(),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['7', '8', '9'].map((d) => _buildKey(d)).toList(),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 80, height: 56),
            _buildKey('0'),
            InkWell(
              onTap: _onBackspace,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 80,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.backspace, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(String digit) {
    return InkWell(
      onTap: () => _onDigitPress(digit),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
