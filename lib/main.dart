import 'dart:async';
import 'package:flutter/material.dart';
import 'data/sample_lessons.dart';
import 'screens/home_screen.dart';
import 'services/ads_service.dart';
import 'services/duration_service.dart';
import 'services/player_service.dart';
import 'services/progress_service.dart';
import 'theme/neumorphic.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    DurationService.instance.init();
  } catch (_) {}

  try {
    await ProgressService.instance.init();
  } catch (_) {}

  // Restore the last played lesson so the player picks up where it left off.
  final lastPlayedId = ProgressService.instance.lastPlayedLessonId;
  if (lastPlayedId != null) {
    for (final lesson in sampleLessons) {
      if (lesson.id == lastPlayedId) {
        PlayerService.instance.currentLesson = lesson;
        break;
      }
    }
  }

  try {
    await AdsService.instance.init();
  } catch (_) {}

  runApp(const AlbaniyOneAudioApp());
}

class AlbaniyOneAudioApp extends StatelessWidget {
  const AlbaniyOneAudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Albaniy',
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'GB'),
      supportedLocales: const [Locale('en', 'GB')],
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.accent,
        scaffoldBackgroundColor: AppColors.background,
        brightness: Brightness.light,
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}