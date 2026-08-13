import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/lesson.dart';
import 'progress_service.dart';

/// Singleton that owns the global [AudioPlayer] so the mini-player and
/// the full player screen share the same playback state.
///
/// Sources are loaded with [MediaItem] tags so just_audio_background can
/// show the track in the notification shade / lock screen while playing.
class PlayerService {
  PlayerService._();
  static final instance = PlayerService._();

  final AudioPlayer player = AudioPlayer();

  Lesson? _currentLesson;
  Lesson? get currentLesson => _currentLesson;
  set currentLesson(Lesson? lesson) => _currentLesson = lesson;

  /// True once the current lesson's audio has been loaded into the player.
  /// After a cold start we restore [_currentLesson] from storage without
  /// loading audio, so the first play press needs to load the source.
  bool _sourceLoaded = false;
  bool get hasLoadedSource => _sourceLoaded;

  bool get isPlaying => player.playing;

  /// ValueListenable that fires when [_currentLesson] or playback changes.
  final ValueNotifier<int> _tick = ValueNotifier(0);
  ValueListenable<int> get tick => _tick;

  Timer? _saveTimer;

  Future<void> playLesson(Lesson lesson,
      {Duration startAt = Duration.zero}) async {
    _currentLesson = lesson;
    ProgressService.instance.setLastPlayed(lesson.id);
    try {
      await _loadSource(lesson);
      if (startAt > Duration.zero) await player.seek(startAt);
      await player.play();
      _tick.value++;
      _startAutoSave();
    } catch (_) {}
  }

  /// Plays or pauses the current lesson. If the source is not loaded yet
  /// (e.g. after an app restart), it is loaded and resumes from the saved
  /// position first.
  Future<void> togglePlay() async {
    final lesson = _currentLesson;
    if (lesson == null) return;
    if (player.playing) {
      await player.pause();
      return;
    }
    if (_sourceLoaded) {
      await player.play();
      return;
    }
    final saved = ProgressService.instance.lastPosition(lesson.id);
    await playLesson(lesson, startAt: saved);
  }

  Future<void> _loadSource(Lesson lesson) async {
    await player.setAudioSource(
      AudioSource.uri(
        Uri.parse('asset:///${lesson.audioAssetPath}'),
        tag: MediaItem(
          id: lesson.id,
          title: lesson.title,
          artist: lesson.scholarName,
          album: lesson.course,
        ),
      ),
    );
    _sourceLoaded = true;
  }

  void _startAutoSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (player.playing && _currentLesson != null && player.position > Duration.zero) {
        ProgressService.instance.savePosition(_currentLesson!.id, player.position);
      }
    });
  }

  void dispose() {
    _saveTimer?.cancel();
    player.dispose();
  }
}