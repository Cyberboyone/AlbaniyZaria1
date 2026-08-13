import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/sample_lessons.dart';
import '../models/lesson.dart';
import '../services/duration_service.dart';
import '../theme/neumorphic.dart';
import '../widgets/lesson_card.dart';
import '../widgets/mini_player.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCourse = 'All';

  @override
  void initState() {
    super.initState();
    DurationService.instance.durationsReady.addListener(_rebuild);
  }

  @override
  void dispose() {
    DurationService.instance.durationsReady.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  List<String> get _courses {
    final courses =
        sampleLessons.map((l) => l.course).toSet().toList();
    courses.insert(0, 'All');
    return courses;
  }

  List<Lesson> get _lessons {
    if (_selectedCourse == 'All') return sampleLessons;
    return sampleLessons
        .where((l) => l.course == _selectedCourse)
        .toList();
  }

  String _chipLabel(String course) => course;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Shaikh Albaniy Zaria',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${sampleLessons.length} lessons - offline audio',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ClipOval(
                    child: Image.asset(
                      'assets/images/scholar_albaniy.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const NeumorphicCircleButton(
                          icon: Icons.person_outline,
                          size: 48,
                          iconSize: 22,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Course filter chips
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _courses.length,
                itemBuilder: (context, index) {
                  final course = _courses[index];
                  final selected = _selectedCourse == course;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedCourse = course),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: AppColors.shadowDark
                                        .withValues(alpha: 0.5),
                                    offset: const Offset(3, 3),
                                    blurRadius: 8,
                                  ),
                                  const BoxShadow(
                                    color: AppColors.shadowLight,
                                    offset: Offset(-3, -3),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          _chipLabel(course),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? AppColors.accent
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Lessons count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '${_lessons.length} Lessons',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Lessons list with banner ads every 4 lessons
            Expanded(
              child: _lessons.isEmpty
                  ? const Center(
                      child: Text('No lessons available.',
                          style:
                              TextStyle(color: AppColors.textSecondary)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 24),
                      itemCount: _lessons.length,
                      itemBuilder: (context, index) {
                        final lesson = _lessons[index];
                        final showBanner =
                            (index + 1) % 4 == 0 && index < _lessons.length - 1;
                        return Column(
                          children: [
                            LessonCard(
                              lesson: lesson,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          PlayerScreen(lesson: lesson)),
                                );
                              },
                            ),
                            if (showBanner && !kIsWeb && Platform.isAndroid)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: SizedBox(
                                  height: 60,
                                  child: AndroidView(
                                    viewType: 'albaniy_banner_ad',
                                    creationParams: {'index': index},
                                    creationParamsCodec:
                                        const StandardMessageCodec(),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
            ),

            // Mini player
            const MiniPlayer(),
          ],
        ),
      ),
    );
  }
}