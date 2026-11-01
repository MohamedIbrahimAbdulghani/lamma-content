// Lamma - by Mohamed Ibrahim

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

/// خدمة اكتشاف المضيف تلقائياً عبر الشبكة المحلية (Local Wi-Fi / Hotspot)
class RoomDiscoveryService {
  /// البحث عن عنوان IP الخاص بالمضيف صاحب كود الغرفة المكون من 4 أرقام
  static Future<String?> findHostForCode({
    required String roomCode,
    String? preferredHostIp,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final cleanCode = roomCode.trim();

    // 1. لو المستخدم كاتب IP محدد أو عندنا عنوان مفضل، نختبره فوراً
    if (preferredHostIp != null && preferredHostIp.trim().isNotEmpty) {
      final cleanIp = preferredHostIp.trim();
      final isAlive = await _probeHost(cleanIp, cleanCode);
      if (isAlive) {
        return cleanIp;
      }
    }

    // 2. البحث عبر بروتوكول UDP Broadcast (الأسرع والأدق على نفس شبكة الواي فاي)
    final udpFoundIp = await _discoverViaUdp(cleanCode, timeout);
    if (udpFoundIp != null) {
      return udpFoundIp;
    }

    // 3. فحص شبكة الـ Localhost / Loopback / Emulator
    final localCandidates = ['127.0.0.1', '10.0.2.2'];
    for (final ip in localCandidates) {
      if (await _probeHost(ip, cleanCode)) {
        return ip;
      }
    }

    // 4. فحص فرعي سريع للـ Subnet لو لم نجد استجابة عبر UDP
    final subnetIp = await _discoverViaSubnetProbe(cleanCode);
    if (subnetIp != null) {
      return subnetIp;
    }

    return null;
  }

  /// إرسال حزم UDP Broadcast للبحث عن المضيف
  static Future<String?> _discoverViaUdp(String roomCode, Duration timeout) async {
    RawDatagramSocket? socket;
    final completer = Completer<String?>();

    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      socket.broadcastEnabled = true;

      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram == null) return;

          try {
            final text = utf8.decode(datagram.data);
            final json = jsonDecode(text) as Map<String, dynamic>;
            if (json['type'] == 'room_discovered') {
              final returnedCode = json['room_code']?.toString().trim();
              if (returnedCode == roomCode) {
                final hostIp = datagram.address.address;
                if (!completer.isCompleted) {
                  completer.complete(hostIp);
                }
              }
            }
          } catch (_) {}
        }
      });

      final queryBytes = utf8.encode(jsonEncode({
        'type': 'discover_room',
        'room_code': roomCode,
      }));

      // إرسال للـ Global Broadcast
      try {
        socket.send(queryBytes, InternetAddress('255.255.255.255'), 8082);
      } catch (_) {}

      // إرسال للـ Loopback
      try {
        socket.send(queryBytes, InternetAddress('127.0.0.1'), 8082);
      } catch (_) {}

      // إرسال للـ Subnet Broadcast لو عرفنا عنوان الجهاز
      try {
        final info = NetworkInfo();
        final wifiIp = await info.getWifiIP();
        if (wifiIp != null && wifiIp.isNotEmpty) {
          final parts = wifiIp.split('.');
          if (parts.length == 4) {
            final subnetBroadcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
            socket.send(queryBytes, InternetAddress(subnetBroadcast), 8082);
          }
        }
      } catch (_) {}

      // إرسال متكرر بفارق نصف ثانية لتفادي ضياع الحزم (UDP Packet Loss)
      Timer(const Duration(milliseconds: 500), () {
        if (!completer.isCompleted && socket != null) {
          try {
            socket.send(queryBytes, InternetAddress('255.255.255.255'), 8082);
            socket.send(queryBytes, InternetAddress('127.0.0.1'), 8082);
          } catch (_) {}
        }
      });

      return await completer.future.timeout(
        timeout,
        onTimeout: () => null,
      );
    } catch (e) {
      debugPrint('UDP discovery error: $e');
      return null;
    } finally {
      socket?.close();
    }
  }

  /// فحص سريع لعنوان IP محدد عبر HTTP Probe
  static Future<bool> _probeHost(String ip, String roomCode) async {
    final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 600);
    try {
      final uri = Uri.parse('http://$ip:8080/lamma_probe?code=$roomCode');
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(milliseconds: 700));

      if (response.statusCode == HttpStatus.ok) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final returnedCode = json['room_code']?.toString().trim();
        final isClosed = json['is_closed'] == true;
        return returnedCode == roomCode && !isClosed;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  /// فحص العناوين القريبة على الـ Subnet بالتوازي (Fallback)
  static Future<String?> _discoverViaSubnetProbe(String roomCode) async {
    try {
      final info = NetworkInfo();
      final wifiIp = await info.getWifiIP();
      if (wifiIp == null || wifiIp.isEmpty) return null;

      final parts = wifiIp.split('.');
      if (parts.length != 4) return null;

      final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
      final myLastOctet = int.tryParse(parts[3]) ?? 1;

      // فحص العناوين الأكثر احتمالاً أولاً (راوتر .1، والجهاز نفسه، والأجهزة المجاورة)
      final candidates = <String>[
        '$prefix.1',
        for (int offset = 1; offset <= 15; offset++) ...[
          if (myLastOctet - offset > 1) '$prefix.${myLastOctet - offset}',
          if (myLastOctet + offset < 255) '$prefix.${myLastOctet + offset}',
        ]
      ];

      // فحص متزامن بمجموعات صغيرة لتفادي الضغط
      for (int i = 0; i < candidates.length; i += 5) {
        final chunk = candidates.skip(i).take(5);
        final results = await Future.wait(chunk.map((ip) async {
          final ok = await _probeHost(ip, roomCode);
          return ok ? ip : null;
        }));

        for (final match in results) {
          if (match != null) return match;
        }
      }
    } catch (_) {}

    return null;
  }
}

