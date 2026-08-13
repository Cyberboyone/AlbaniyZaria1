import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/player_service.dart';
import '../theme/neumorphic.dart';
import '../screens/player_screen.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  @override
  void initState() {
    super.initState();
    PlayerService.instance.tick.addListener(_rebuild);
    PlayerService.instance.player.playingStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    PlayerService.instance.tick.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final audio = PlayerService.instance;
    final lesson = audio.currentLesson;
    final player = audio.player;

    if (lesson == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PlayerScreen(lesson: lesson)),
        );
      },
      child: Neumorphic(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        borderRadius: 20,
        style: NeuStyle.raised,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Artwork thumbnail
            Neumorphic(
              width: 48,
              height: 48,
              borderRadius: 12,
              style: NeuStyle.raised,
              intensity: 0.6,
              child: Center(
                child: lesson.arabicLabel != null
                    ? Text(
                        lesson.arabicLabel!,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      )
                    : const Icon(Icons.menu_book_outlined,
                        size: 24, color: AppColors.accent),
              ),
            ),
            const SizedBox(width: 12),

            // Title + subtitle
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lesson.scholarName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Play/pause
            StreamBuilder<PlayerState>(
              stream: player.playerStateStream,
              builder: (context, snapshot) {
                final playing = snapshot.data?.playing ?? false;
                return GestureDetector(
                  onTap: () => audio.togglePlay(),
                  child: Neumorphic(
                    width: 44,
                    height: 44,
                    borderRadius: 22,
                    style: NeuStyle.raised,
                    child: Icon(
                      playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 22,
                      color: AppColors.accent,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}