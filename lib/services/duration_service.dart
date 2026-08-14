import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/sample_lessons.dart';

/// Holds the real duration of each bundled lesson.
///
/// Durations are baked into [sampleLessons] at build time, so this service
/// only persists them to SharedPreferences and marks the UI as ready.
/// (Previously this probed files with its own [AudioPlayer], which conflicted
/// with just_audio_background's single-player constraint and crashed playback.)
class DurationService {
  DurationService._();
  static final DurationService instance = DurationService._();

  final ValueNotifier<bool> durationsReady = ValueNotifier(false);

  bool get isLoaded => durationsReady.value;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('audio_durations_v2');
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final lesson in sampleLessons) {
          final ms = map[lesson.audioAssetPath];
          if (ms is int && ms > 0) {
            lesson.duration = Duration(milliseconds: ms);
          }
        }
      }
      durationsReady.value = true;
    } catch (_) {
      durationsReady.value = true;
    }
  }
}
