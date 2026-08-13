import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists last playback position per lesson to SharedPreferences so the
/// user can resume each track where they left off.
class ProgressService {
  ProgressService._();
  static final ProgressService instance = ProgressService._();

  /// lessonId → last playback position in milliseconds.
  final Map<String, int> _positions = {};

  /// lessonId of the most recently played track (restored on startup).
  String? _lastPlayedId;

  final ValueNotifier<bool> ready = ValueNotifier(false);

  bool get isLoaded => ready.value;

  // ── Queries ────────────────────────────────────────────────

  int lastPositionMs(String lessonId) => _positions[lessonId] ?? 0;

  Duration lastPosition(String lessonId) =>
      Duration(milliseconds: lastPositionMs(lessonId));

  String? get lastPlayedLessonId => _lastPlayedId;

  // ── Mutations ──────────────────────────────────────────────

  void savePosition(String lessonId, Duration position) {
    final ms = position.inMilliseconds;
    if (ms > 0) {
      _positions[lessonId] = ms;
      _persist();
    }
  }

  void setLastPlayed(String lessonId) {
    if (_lastPlayedId != lessonId) {
      _lastPlayedId = lessonId;
      _persist();
    }
  }

  // ── Persistence ────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final pRaw = prefs.getString('progress_positions');
      if (pRaw != null) {
        final map = jsonDecode(pRaw) as Map<String, dynamic>;
        for (final e in map.entries) {
          _positions[e.key] = e.value as int;
        }
      }
    } catch (_) {}

    _lastPlayedId = prefs.getString('last_played_lesson_id');

    ready.value = true;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('progress_positions', jsonEncode(_positions));
      if (_lastPlayedId != null) {
        await prefs.setString('last_played_lesson_id', _lastPlayedId!);
      }
    } catch (_) {}
  }
}