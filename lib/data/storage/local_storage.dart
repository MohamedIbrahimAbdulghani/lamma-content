// Lamma - by Mohamed Ibrahim

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/arabic_text_normalizer.dart';
import '../models/bootstrap_data.dart';

class LocalStorage {
  static const int kMaxHistorySizePerGame = 20000;

  static const String _keyDeviceId = 'lamma_device_id';
  static const String _keyBootstrapData = 'lamma_bootstrap_cache';
  static const String _keySeenQuestions = 'lamma_seen_questions';
  static const String _keySeenTriviaQuestionsText = 'lamma_seen_trivia_text';
  static const String _keySeenTriviaPromptHashes = 'lamma_seen_trivia_prompt_hashes';
  static const String _keySeenTriviaAnswerHashes = 'lamma_seen_trivia_answer_hashes';
  static const String _keySeenSpyWords = 'lamma_seen_spy_words';
  static const String _keySeenSpyHashes = 'lamma_seen_spy_hashes';
  static const String _keySeenCharadesWords = 'lamma_seen_charades_words';
  static const String _keySeenCharadesHashes = 'lamma_seen_charades_hashes';
  static const String _keyPlayerName = 'lamma_player_name';
  static const String _keyPlayerEmoji = 'lamma_player_emoji';
  static const String _keyLastVersion = 'lamma_content_version';
  static const String _keyTriviaQuestionsCount = 'lamma_trivia_questions_count';
  static const String _keyTriviaTimePerQuestion = 'lamma_trivia_time_per_question';
  static const String _keyTriviaDifficulty = 'lamma_trivia_difficulty';
  static const String _keyTriviaCategories = 'lamma_trivia_categories';

  // Spy Settings Keys
  static const String _keySpyRounds = 'lamma_spy_rounds';
  static const String _keySpyDiscussionMinutes = 'lamma_spy_discussion_minutes';
  static const String _keySpyVotingSeconds = 'lamma_spy_voting_seconds';
  static const String _keySpyGuessSeconds = 'lamma_spy_guess_seconds';
  static const String _keySpySpiesCount = 'lamma_spy_spies_count';
  static const String _keySpyWordPack = 'lamma_spy_word_pack';

  // Charades Settings Keys
  static const String _keyCharadesRoundSeconds = 'lamma_charades_round_seconds';
  static const String _keyCharadesRoundsPerPlayer = 'lamma_charades_rounds_per_player';
  static const String _keyCharadesCategory = 'lamma_charades_category';
  static const String _keyCharadesWordsPerTurn = 'lamma_charades_words_per_turn';

  // Sound & Vibration Settings Keys
  static const String _keySoundEnabled = 'lamma_sound_enabled';
  static const String _keyVibrationEnabled = 'lamma_vibration_enabled';

  final SharedPreferences _prefs;

  // In-memory Set caches for O(1) instant history lookups without repeated serialization
  Set<String>? _cachedTriviaPromptHashes;
  Set<String>? _cachedTriviaAnswerHashes;
  Set<String>? _cachedSpyHashes;
  Set<String>? _cachedCharadesHashes;

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

  // 3. Seen Questions by ID (legacy support)
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

  // ==========================================
  // بصمات تحدي الشلة (Trivia Fingerprints)
  // ==========================================

  /// بصمات نصوص الأسئلة المشاهدة مع تخزين مؤقت في الذاكرة لتسريع البحث
  Set<String> getSeenTriviaPromptHashes() {
    if (_cachedTriviaPromptHashes != null) {
      return Set<String>.from(_cachedTriviaPromptHashes!);
    }

    final hashes = (_prefs.getStringList(_keySeenTriviaPromptHashes) ?? []).toSet();

    // ترحيل النصوص القديمة غير المحوسبة لمرة واحدة فقط لتجنب إعادة الحساب
    final legacyTexts = _prefs.getStringList(_keySeenTriviaQuestionsText) ?? [];
    if (legacyTexts.isNotEmpty) {
      for (final text in legacyTexts) {
        final h = ArabicTextNormalizer.triviaQuestionHash(text);
        if (h.isNotEmpty) hashes.add(h);
      }
      // حفظ البصمات المحسوبة ومسح النصوص لتسريع مرات التشغيل اللاحقة
      _prefs.setStringList(_keySeenTriviaPromptHashes, hashes.toList());
      _prefs.remove(_keySeenTriviaQuestionsText);
    }

    _cachedTriviaPromptHashes = Set<String>.from(hashes);
    return hashes;
  }

  /// بصمات الإجابات الصحيحة مع الأقسام
  Set<String> getSeenTriviaAnswerHashes() {
    if (_cachedTriviaAnswerHashes != null) {
      return Set<String>.from(_cachedTriviaAnswerHashes!);
    }
    final hashes = (_prefs.getStringList(_keySeenTriviaAnswerHashes) ?? []).toSet();
    _cachedTriviaAnswerHashes = Set<String>.from(hashes);
    return hashes;
  }

  /// تسجيل بصمات أسئلة جديدة مع تقليم السجل إذا تجاوز الحد الأقصى (FIFO) بسرعة O(1)
  Future<void> markTriviaHashesSeen({
    List<String> promptHashes = const [],
    List<String> answerHashes = const [],
  }) async {
    if (promptHashes.isNotEmpty) {
      final existingPrompts = (_prefs.getStringList(_keySeenTriviaPromptHashes) ?? []);
      final existingSet = existingPrompts.toSet();

      for (final h in promptHashes) {
        if (h.isNotEmpty && existingSet.add(h)) {
          existingPrompts.add(h);
        }
      }
      final trimmedPrompts = _trimList(existingPrompts, kMaxHistorySizePerGame);
      _cachedTriviaPromptHashes = trimmedPrompts.toSet();
      await _prefs.setStringList(_keySeenTriviaPromptHashes, trimmedPrompts);
    }

    if (answerHashes.isNotEmpty) {
      final existingAnswers = (_prefs.getStringList(_keySeenTriviaAnswerHashes) ?? []);
      final existingSet = existingAnswers.toSet();

      for (final h in answerHashes) {
        if (h.isNotEmpty && existingSet.add(h)) {
          existingAnswers.add(h);
        }
      }
      final trimmedAnswers = _trimList(existingAnswers, kMaxHistorySizePerGame);
      _cachedTriviaAnswerHashes = trimmedAnswers.toSet();
      await _prefs.setStringList(_keySeenTriviaAnswerHashes, trimmedAnswers);
    }
  }

  // ==========================================
  // بصمات مين الجاسوس (Spy Fingerprints)
  // ==========================================

  Set<String> getSeenSpyHashes() {
    if (_cachedSpyHashes != null) {
      return Set<String>.from(_cachedSpyHashes!);
    }

    final hashes = (_prefs.getStringList(_keySeenSpyHashes) ?? []).toSet();
    final legacyWords = _prefs.getStringList(_keySeenSpyWords) ?? [];
    if (legacyWords.isNotEmpty) {
      for (final word in legacyWords) {
        final h = ArabicTextNormalizer.wordHash(word);
        if (h.isNotEmpty) hashes.add(h);
      }
      _prefs.setStringList(_keySeenSpyHashes, hashes.toList());
      _prefs.remove(_keySeenSpyWords);
    }

    _cachedSpyHashes = Set<String>.from(hashes);
    return hashes;
  }

  Future<void> markSpyHashesSeen(List<String> hashes) async {
    final existing = (_prefs.getStringList(_keySeenSpyHashes) ?? []);
    final existingSet = existing.toSet();

    for (final h in hashes) {
      if (h.isNotEmpty && existingSet.add(h)) {
        existing.add(h);
      }
    }
    final trimmed = _trimList(existing, kMaxHistorySizePerGame);
    _cachedSpyHashes = trimmed.toSet();
    await _prefs.setStringList(_keySeenSpyHashes, trimmed);
  }

  // ==========================================
  // بصمات مثّل ومتتكلمش (Charades Fingerprints)
  // ==========================================

  Set<String> getSeenCharadesHashes() {
    if (_cachedCharadesHashes != null) {
      return Set<String>.from(_cachedCharadesHashes!);
    }

    final hashes = (_prefs.getStringList(_keySeenCharadesHashes) ?? []).toSet();
    final legacyWords = _prefs.getStringList(_keySeenCharadesWords) ?? [];
    if (legacyWords.isNotEmpty) {
      for (final word in legacyWords) {
        final h = ArabicTextNormalizer.wordHash(word);
        if (h.isNotEmpty) hashes.add(h);
      }
      _prefs.setStringList(_keySeenCharadesHashes, hashes.toList());
      _prefs.remove(_keySeenCharadesWords);
    }

    _cachedCharadesHashes = Set<String>.from(hashes);
    return hashes;
  }

  Future<void> markCharadesHashesSeen(List<String> hashes) async {
    final existing = (_prefs.getStringList(_keySeenCharadesHashes) ?? []);
    final existingSet = existing.toSet();

    for (final h in hashes) {
      if (h.isNotEmpty && existingSet.add(h)) {
        existing.add(h);
      }
    }
    final trimmed = _trimList(existing, kMaxHistorySizePerGame);
    _cachedCharadesHashes = trimmed.toSet();
    await _prefs.setStringList(_keySeenCharadesHashes, trimmed);
  }

  // تقليم القائمة بحذف الأقدم (FIFO) عند تجاوز الحد الأقصى
  List<String> _trimList(List<String> list, int maxSize) {
    if (list.length <= maxSize) return list;
    return list.sublist(list.length - maxSize);
  }

  // ==========================================
  // Legacy text helpers for backward compatibility
  // ==========================================

  Set<String> getSeenSpyWords() {
    return (_prefs.getStringList(_keySeenSpyWords) ?? []).toSet();
  }

  Future<void> markSpyWordsSeen(List<String> words) async {
    final existing = getSeenSpyWords();
    existing.addAll(words);
    await _prefs.setStringList(_keySeenSpyWords, existing.toList());

    final hashes = words.map((w) => ArabicTextNormalizer.wordHash(w)).toList();
    await markSpyHashesSeen(hashes);
  }

  Set<String> getSeenTriviaQuestionTexts() {
    return (_prefs.getStringList(_keySeenTriviaQuestionsText) ?? []).toSet();
  }

  Future<void> markTriviaQuestionTextsSeen(List<String> prompts) async {
    final existing = getSeenTriviaQuestionTexts();
    existing.addAll(prompts);
    final trimmed = _trimList(existing.toList(), kMaxHistorySizePerGame);
    await _prefs.setStringList(_keySeenTriviaQuestionsText, trimmed);

    final hashes = prompts.map((p) => ArabicTextNormalizer.triviaQuestionHash(p)).toList();
    await markTriviaHashesSeen(promptHashes: hashes);
  }

  Set<String> getSeenCharadesWords() {
    return (_prefs.getStringList(_keySeenCharadesWords) ?? []).toSet();
  }

  Future<void> markCharadesWordsSeen(List<String> words) async {
    final existing = getSeenCharadesWords();
    existing.addAll(words);
    await _prefs.setStringList(_keySeenCharadesWords, existing.toList());

    final hashes = words.map((w) => ArabicTextNormalizer.wordHash(w)).toList();
    await markCharadesHashesSeen(hashes);
  }

  // ==========================================
  // إعادة ضبط السجل بالكامل (Reset All History)
  // ==========================================

  Future<void> clearAllSeenHistory() async {
    _cachedTriviaPromptHashes = null;
    _cachedTriviaAnswerHashes = null;
    _cachedSpyHashes = null;
    _cachedCharadesHashes = null;
    await _prefs.remove(_keySeenQuestions);
    await _prefs.remove(_keySeenTriviaQuestionsText);
    await _prefs.remove(_keySeenTriviaPromptHashes);
    await _prefs.remove(_keySeenTriviaAnswerHashes);
    await _prefs.remove(_keySeenSpyWords);
    await _prefs.remove(_keySeenSpyHashes);
    await _prefs.remove(_keySeenCharadesWords);
    await _prefs.remove(_keySeenCharadesHashes);
  }

  // Player Profile (remember chosen name & emoji)
  String getPlayerName() => _prefs.getString(_keyPlayerName) ?? 'لاعب';
  Future<void> setPlayerName(String name) => _prefs.setString(_keyPlayerName, name);

  String getPlayerEmoji() => _prefs.getString(_keyPlayerEmoji) ?? '🦁';
  Future<void> setPlayerEmoji(String emoji) => _prefs.setString(_keyPlayerEmoji, emoji);

  // Trivia Settings
  bool hasTriviaSettings() {
    return _prefs.containsKey(_keyTriviaQuestionsCount);
  }

  Map<String, dynamic>? getSavedTriviaSettings() {
    if (!hasTriviaSettings()) return null;
    return {
      'questionsCount': _prefs.getInt(_keyTriviaQuestionsCount) ?? 10,
      'timePerQuestion': _prefs.getInt(_keyTriviaTimePerQuestion) ?? 15,
      'difficulty': _prefs.getString(_keyTriviaDifficulty) ?? 'all',
      'categories': _prefs.getStringList(_keyTriviaCategories) ?? [
        'movies',
        'sports',
        'afeehat',
        'history',
        'general',
      ],
    };
  }

  Future<void> saveTriviaSettingsData({
    required int questionsCount,
    required int timePerQuestion,
    required String difficulty,
    required List<String> categories,
  }) async {
    await _prefs.setInt(_keyTriviaQuestionsCount, questionsCount);
    await _prefs.setInt(_keyTriviaTimePerQuestion, timePerQuestion);
    await _prefs.setString(_keyTriviaDifficulty, difficulty);
    await _prefs.setStringList(_keyTriviaCategories, categories);
  }

  Future<void> clearTriviaSettings() async {
    await _prefs.remove(_keyTriviaQuestionsCount);
    await _prefs.remove(_keyTriviaTimePerQuestion);
    await _prefs.remove(_keyTriviaDifficulty);
    await _prefs.remove(_keyTriviaCategories);
  }

  // Spy Settings
  bool hasSpySettings() {
    return _prefs.containsKey(_keySpyRounds);
  }

  Map<String, dynamic>? getSavedSpySettings() {
    if (!hasSpySettings()) return null;
    return {
      'rounds': _prefs.getInt(_keySpyRounds) ?? 3,
      'discussionMinutes': _prefs.getInt(_keySpyDiscussionMinutes) ?? 5,
      'votingSeconds': _prefs.getInt(_keySpyVotingSeconds) ?? 30,
      'guessSeconds': _prefs.getInt(_keySpyGuessSeconds) ?? 15,
      'spiesCount': _prefs.getInt(_keySpySpiesCount) ?? 0,
      'wordPack': _prefs.getString(_keySpyWordPack) ?? 'places',
    };
  }

  Future<void> saveSpySettingsData({
    required int rounds,
    required int discussionMinutes,
    required int votingSeconds,
    required int guessSeconds,
    required int spiesCount,
    required String wordPack,
  }) async {
    await _prefs.setInt(_keySpyRounds, rounds);
    await _prefs.setInt(_keySpyDiscussionMinutes, discussionMinutes);
    await _prefs.setInt(_keySpyVotingSeconds, votingSeconds);
    await _prefs.setInt(_keySpyGuessSeconds, guessSeconds);
    await _prefs.setInt(_keySpySpiesCount, spiesCount);
    await _prefs.setString(_keySpyWordPack, wordPack);
  }

  Future<void> clearSpySettings() async {
    await _prefs.remove(_keySpyRounds);
    await _prefs.remove(_keySpyDiscussionMinutes);
    await _prefs.remove(_keySpyVotingSeconds);
    await _prefs.remove(_keySpyGuessSeconds);
    await _prefs.remove(_keySpySpiesCount);
    await _prefs.remove(_keySpyWordPack);
  }

  // Charades Settings
  bool hasCharadesSettings() {
    return _prefs.containsKey(_keyCharadesRoundSeconds);
  }

  Map<String, dynamic>? getSavedCharadesSettings() {
    if (!hasCharadesSettings()) return null;
    return {
      'roundSeconds': _prefs.getInt(_keyCharadesRoundSeconds) ?? 60,
      'roundsPerPlayer': _prefs.getInt(_keyCharadesRoundsPerPlayer) ?? 2,
      'category': _prefs.getString(_keyCharadesCategory) ?? 'movies',
      'wordsPerTurn': _prefs.getInt(_keyCharadesWordsPerTurn) ?? 10,
    };
  }

  Future<void> saveCharadesSettingsData({
    required int roundSeconds,
    required int roundsPerPlayer,
    required String category,
    int wordsPerTurn = 10,
  }) async {
    await _prefs.setInt(_keyCharadesRoundSeconds, roundSeconds);
    await _prefs.setInt(_keyCharadesRoundsPerPlayer, roundsPerPlayer);
    await _prefs.setString(_keyCharadesCategory, category);
    await _prefs.setInt(_keyCharadesWordsPerTurn, wordsPerTurn);
  }

  Future<void> clearCharadesSettings() async {
    await _prefs.remove(_keyCharadesRoundSeconds);
    await _prefs.remove(_keyCharadesRoundsPerPlayer);
    await _prefs.remove(_keyCharadesCategory);
    await _prefs.remove(_keyCharadesWordsPerTurn);
  }

  // Sound & Vibration Preferences
  bool getSoundEnabled() {
    return _prefs.getBool(_keySoundEnabled) ?? true;
  }

  Future<void> setSoundEnabled(bool enabled) async {
    await _prefs.setBool(_keySoundEnabled, enabled);
  }

  bool getVibrationEnabled() {
    return _prefs.getBool(_keyVibrationEnabled) ?? true;
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    await _prefs.setBool(_keyVibrationEnabled, enabled);
  }
}
