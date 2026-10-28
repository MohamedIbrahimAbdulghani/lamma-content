// Lamma - by Mohamed Ibrahim

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/bootstrap_data.dart';

class LocalStorage {
  static const String _keyDeviceId = 'lamma_device_id';
  static const String _keyBootstrapData = 'lamma_bootstrap_cache';
  static const String _keySeenQuestions = 'lamma_seen_questions';
  static const String _keyPlayerName = 'lamma_player_name';
  static const String _keyPlayerEmoji = 'lamma_player_emoji';
  static const String _keyLastVersion = 'lamma_content_version';

  final SharedPreferences _prefs;

  LocalStorage(this._prefs);

  static Future<LocalStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorage(prefs);
  }

  // 1. Anonymous Device ID (generates once, persists forever)
  String getDeviceId() {
    String? id = _prefs.getString(_keyDeviceId);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      _prefs.setString(_keyDeviceId, id);
    }
    return id;
  }

  // 2. Cached Bootstrap Data (for complete offline gameplay)
  Future<void> saveBootstrapData(BootstrapData data) async {
    final jsonStr = jsonEncode(data.toJson());
    await _prefs.setString(_keyBootstrapData, jsonStr);
    await _prefs.setInt(_keyLastVersion, data.version);
  }

  BootstrapData? getBootstrapData() {
    final jsonStr = _prefs.getString(_keyBootstrapData);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return BootstrapData.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  int getCachedVersion() {
    return _prefs.getInt(_keyLastVersion) ?? 0;
  }

  // 3. Seen Questions (persisted locally for zero repeat)
  Set<int> getSeenQuestions() {
    final list = _prefs.getStringList(_keySeenQuestions) ?? [];
    return list.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toSet();
  }

  Future<void> markQuestionsSeen(List<int> questionIds) async {
    final existing = getSeenQuestions();
    existing.addAll(questionIds);
    await _prefs.setStringList(
      _keySeenQuestions,
      existing.map((e) => e.toString()).toList(),
    );
  }

  // 4. Player Profile (remember chosen name & emoji)
  String getPlayerName() => _prefs.getString(_keyPlayerName) ?? 'لاعب';
  Future<void> setPlayerName(String name) => _prefs.setString(_keyPlayerName, name);

  String getPlayerEmoji() => _prefs.getString(_keyPlayerEmoji) ?? '🦁';
  Future<void> setPlayerEmoji(String emoji) => _prefs.setString(_keyPlayerEmoji, emoji);
}
