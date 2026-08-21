import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../data/sample_lessons.dart';
import '../models/lesson.dart';
import '../services/player_service.dart';
import '../services/progress_service.dart';
import '../theme/neumorphic.dart';

class PlayerScreen extends StatefulWidget {
  final Lesson lesson;
  const PlayerScreen({super.key, required this.lesson});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _audio = PlayerService.instance;
  AudioPlayer get _player => _audio.player;
  final _progressKey = GlobalKey();
  late List<Lesson> _courseLessons;
  late int _currentIndex;
  StreamSubscription<PlayerState>? _completionSub;

  @override
  void initState() {
    super.initState();
    _courseLessons = sampleLessons
        .where((l) => l.course == widget.lesson.course)
        .toList();
    _currentIndex =
        _courseLessons.indexWhere((l) => l.id == widget.lesson.id);
    if (_currentIndex == -1) _currentIndex = 0;
    _load();

    _completionSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _playNext();
      }
    });
  }

  Future<void> _load() async {
    try {
      final lesson = _courseLessons[_currentIndex];
      final saved = ProgressService.instance.lastPosition(lesson.id);
      await _audio.playLesson(lesson, startAt: saved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load audio: $e')),
        );
      }
    }
  }

  void _playLesson(Lesson lesson) {
    _saveCurrentPosition();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PlayerScreen(lesson: lesson)),
    );
  }

  void _playNext() {
    if (_currentIndex < _courseLessons.length - 1) {
      _playLesson(_courseLessons[_currentIndex + 1]);
    }
  }

  void _playPrevious() {
    if (_currentIndex > 0) {
      _playLesson(_courseLessons[_currentIndex - 1]);
    } else {
      _player.seek(Duration.zero);
    }
  }

  void _seekFromPosition(
      Offset globalPosition, double barWidth, int totalMs) {
    final box = _progressKey.currentContext!.findRenderObject() as RenderBox;
    final localX = box.globalToLocal(globalPosition).dx;
    final ratio = (localX / barWidth).clamp(0.0, 1.0);
    _player.seek(Duration(milliseconds: (totalMs * ratio).toInt()));
  }

  void _saveCurrentPosition() {
    if (_player.position > Duration.zero) {
      ProgressService.instance.savePosition(
        _courseLessons[_currentIndex].id,
        _player.position,
      );
    }
  }

  @override
  void dispose() {
    _completionSub?.cancel();
    _saveCurrentPosition();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 700;
            final artworkSize =
                (constraints.maxHeight * 0.28).clamp(150.0, 220.0);
            return SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight - 32),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          NeumorphicCircleButton(
                            icon: Icons.arrow_back,
                            size: 44,
                            iconSize: 22,
                            onTap: () =>
                                Navigator.of(context).maybePop(),
                          ),
                          const Text(
                            'Playing from Album',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          NeumorphicCircleButton(
                            icon: Icons.more_horiz,
                            size: 44,
                            iconSize: 22,
                            onTap: () {},
                          ),
                        ],
                      ),

                      SizedBox(height: compact ? 24 : 40),

                      // Circular artwork
                      Neumorphic(
                        width: artworkSize,
                        height: artworkSize,
                        borderRadius: artworkSize / 2,
                        style: NeuStyle.raised,
                        intensity: 1.3,
                        child: Center(
                          child: lesson.arabicLabel != null
                              ? Text(
                                  lesson.arabicLabel!,
                                  style: TextStyle(
                                    fontSize: artworkSize * 0.25,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accent,
                                  ),
                                )
                              : Icon(Icons.menu_book_outlined,
                                  size: artworkSize * 0.33,
                                  color: AppColors.accent),
                        ),
                      ),

                      SizedBox(height: compact ? 20 : 32),

                      // Scholar photo + Title + Course + Subtitle
                      Column(
                        children: [
                          if (lesson.scholarPhotoPath != null)
                            ClipOval(
                              child: Image.asset(
                                lesson.scholarPhotoPath!,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: AppColors.accent
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.person,
                                        color: AppColors.accent,
                                        size: 32),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            lesson.title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          if (lesson.course.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accent
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                lesson.course,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            'Shaikh: ${lesson.scholarName}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Progress bar
                      StreamBuilder<Duration?>(
                        stream: _player.durationStream,
                        builder: (context, snapshot) {
                          final duration =
                              snapshot.data ?? widget.lesson.duration;
                          return StreamBuilder<Duration>(
                            stream: _player.positionStream,
                            builder: (context, posSnapshot) {
                              final position =
                                  posSnapshot.data ?? Duration.zero;
                              final totalMs = duration.inMilliseconds
                                  .clamp(1, double.infinity)
                                  .toInt();
                              final fraction =
                                  (position.inMilliseconds / totalMs)
                                      .clamp(0.0, 1.0);

                              return Column(
                                children: [
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final barWidth = constraints.maxWidth;
                                      final thumbX =
                                          (barWidth * fraction - 7)
                                              .clamp(0.0, barWidth - 14);
                                      return GestureDetector(
                                        key: _progressKey,
                                        onHorizontalDragStart: (details) {
                                          _seekFromPosition(
                                              details.globalPosition,
                                              barWidth,
                                              totalMs);
                                        },
                                        onHorizontalDragUpdate: (details) {
                                          _seekFromPosition(
                                              details.globalPosition,
                                              barWidth,
                                              totalMs);
                                        },
                                        onTapDown: (details) {
                                          _seekFromPosition(
                                              details.globalPosition,
                                              barWidth,
                                              totalMs);
                                        },
                                        child: SizedBox(
                                          height: 24,
                                          child: Stack(
                                            alignment:
                                                Alignment.centerLeft,
                                            children: [
                                              Positioned(
                                                top: 9,
                                                left: 0,
                                                right: 0,
                                                child: Container(
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    color: AppColors
                                                        .shadowDark
                                                        .withValues(alpha: 0.4),
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(3),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                top: 9,
                                                left: 0,
                                                child: Container(
                                                  height: 6,
                                                  width: thumbX,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        AppColors.accent,
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(3),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                left: thumbX,
                                                child: Container(
                                                  width: 14,
                                                  height: 14,
                                                  decoration:
                                                      BoxDecoration(
                                                    color:
                                                        AppColors.accent,
                                                    shape:
                                                        BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: AppColors
                                                            .accent
                                                            .withValues(alpha: 0.4),
                                                        blurRadius: 6,
                                                        spreadRadius: 1,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_formatDuration(position),
                                          style: const TextStyle(
                                              color: AppColors
                                                  .textSecondary,
                                              fontSize: 12)),
                                      Text(_formatDuration(duration),
                                          style: const TextStyle(
                                              color: AppColors
                                                  .textSecondary,
                                              fontSize: 12)),
                                    ],
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 28),

                      // Transport controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          StreamBuilder<bool>(
                            stream: _player.shuffleModeEnabledStream,
                            builder: (context, snapshot) {
                              final shuffleOn = snapshot.data ?? false;
                              return NeumorphicCircleButton(
                                icon: Icons.shuffle,
                                size: 48,
                                iconSize: 22,
                                iconColor: shuffleOn
                                    ? AppColors.accent
                                    : AppColors.textSecondary,
                                onTap: () => _player
                                    .setShuffleModeEnabled(!shuffleOn),
                              );
                            },
                          ),
                          NeumorphicCircleButton(
                            icon: Icons.skip_previous_rounded,
                            size: 64,
                            iconSize: 28,
                            onTap: _playPrevious,
                          ),
                          StreamBuilder<PlayerState>(
                            stream: _player.playerStateStream,
                            builder: (context, snapshot) {
                              final playing =
                                  snapshot.data?.playing ?? false;
                              return NeumorphicCircleButton(
                                icon: playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 84,
                                iconSize: 40,
                                onTap: () => playing
                                    ? _player.pause()
                                    : _player.play(),
                              );
                            },
                          ),
                          NeumorphicCircleButton(
                            icon: Icons.skip_next_rounded,
                            size: 64,
                            iconSize: 28,
                            onTap: _currentIndex <
                                    _courseLessons.length - 1
                                ? _playNext
                                : null,
                          ),
                          StreamBuilder<LoopMode>(
                            stream: _player.loopModeStream,
                            builder: (context, snapshot) {
                              final loopMode =
                                  snapshot.data ?? LoopMode.off;
                              IconData icon;
                              Color? color;
                              switch (loopMode) {
                                case LoopMode.off:
                                  icon = Icons.repeat;
                                  color = AppColors.textSecondary;
                                  break;
                                case LoopMode.one:
                                  icon = Icons.repeat_one;
                                  color = AppColors.accent;
                                  break;
                                case LoopMode.all:
                                  icon = Icons.repeat;
                                  color = AppColors.accent;
                                  break;
                              }
                              return NeumorphicCircleButton(
                                icon: icon,
                                size: 48,
                                iconSize: 22,
                                iconColor: color,
                                onTap: () {
                                  final modes = [
                                    LoopMode.off,
                                    LoopMode.all,
                                    LoopMode.one,
                                  ];
                                  final nextIndex =
                                      (modes.indexOf(loopMode) + 1) %
                                          modes.length;
                                  _player
                                      .setLoopMode(modes[nextIndex]);
                                },
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Text(
                        '${_currentIndex + 1} / ${_courseLessons.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
