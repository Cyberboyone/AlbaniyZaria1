import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/sample_lessons.dart';

/// Probes the real duration of each bundled MP3 and caches the results
/// in SharedPreferences so the UI shows accurate times without blocking
/// startup.
class DurationService {
  DurationService._();
  static final DurationService instance = DurationService._();

  Map<String, Duration> _cache = {};
  final ValueNotifier<bool> durationsReady = ValueNotifier(false);

  bool get isLoaded => durationsReady.value;

  Duration? durationFor(String audioAssetPath) => _cache[audioAssetPath];

  Future<void> init() async {
    // 1. Try loading from disk cache first.
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('audio_durations_v2');
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _cache = map.map((k, v) => MapEntry(k, Duration(milliseconds: v as int)));
        _applyCache();
        durationsReady.value = true;
      } catch (_) {}
    }

    // 2. Probe all files in the background (one at a time to avoid issues).
    _probeAll().then((cache) async {
      if (cache.isNotEmpty) {
        _cache = cache;
        _applyCache();
        durationsReady.value = true;
        final prefs = await SharedPreferences.getInstance();
        final encoded = jsonEncode(
          cache.map((k, v) => MapEntry(k, v.inMilliseconds)),
        );
        await prefs.setString('audio_durations_v2', encoded);
      }
    });
  }

  void _applyCache() {
    for (final lesson in sampleLessons) {
      final real = _cache[lesson.audioAssetPath];
      if (real != null && real > Duration.zero) {
        lesson.duration = real;
      }
    }
  }

  Future<Map<String, Duration>> _probeAll() async {
    final results = <String, Duration>{};
    final paths = sampleLessons
        .map((l) => l.audioAssetPath)
        .toSet()
        .toList();

    for (final path in paths) {
      final d = await _probeSingle(path);
      if (d != null) {
        results[path] = d;
      }
    }
    return results;
  }

  Future<Duration?> _probeSingle(String assetPath) async {
    final player = AudioPlayer();
    try {
      await player.setAsset(assetPath).timeout(const Duration(seconds: 10));
      final d = player.duration;
      if (d != null && d > Duration.zero) return d;
      // Wait briefly for the duration stream.
      final completer = Completer<Duration?>();
      final sub = player.durationStream.listen((d) {
        if (!completer.isCompleted && d != null && d > Duration.zero) {
          completer.complete(d);
        }
      });
      final result = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => player.duration,
      );
      await sub.cancel();
      return result;
    } catch (_) {
      return null;
    } finally {
      await player.dispose();
    }
  }
}