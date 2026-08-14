import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../data/sample_lessons.dart';
import '../models/lesson.dart';
import '../services/ads_service.dart';
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
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    DurationService.instance.durationsReady.addListener(_rebuild);
    _loadBannerAd();
  }

  @override
  void dispose() {
    DurationService.instance.durationsReady.removeListener(_rebuild);
    _bannerAd?.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _loadBannerAd() {
    _bannerAd = AdsService.instance.createBannerAd(
      onLoaded: () {
        if (mounted) setState(() => _isBannerAdLoaded = true);
      },
    );
  }

  List<String> get _courses {
    final courses = sampleLessons.map((l) => l.course).toSet().toList();
    courses.insert(0, 'All');
    return courses;
  }

  List<Lesson> get _lessons {
    if (_selectedCourse == 'All') return sampleLessons;
    return sampleLessons.where((l) => l.course == _selectedCourse).toList();
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
                      'assets/images/download.jpg',
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
                      onTap: () => setState(() => _selectedCourse = course),
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
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
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

            // Lessons list
            Expanded(
              child: _lessons.isEmpty
                  ? const Center(
                      child: Text('No lessons available.',
                          style: TextStyle(color: AppColors.textSecondary)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 24),
                      itemCount: _lessons.length + 1,
                      itemBuilder: (context, index) {
                        // Show banner ad after every 4 lessons
                        if (index > 0 && index % 5 == 0 && _bannerAd != null && _isBannerAdLoaded) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: SizedBox(
                              height: 50,
                              child: AdWidget(ad: _bannerAd!),
                            ),
                          );
                        }

                        // Adjust index for lessons after ad positions
                        final lessonIndex = index > 0 && index % 5 == 0
                            ? index - 1
                            : index;

                        if (lessonIndex >= _lessons.length) {
                          return const SizedBox.shrink();
                        }

                        final lesson = _lessons[lessonIndex];
                        return LessonCard(
                          lesson: lesson,
                          onTap: () {
                            // Show interstitial ad every 4 lessons
                            final adCounter = lessonIndex + 1;
                            if (adCounter % 4 == 0) {
                              AdsService.instance.showInterstitialAd(
                                onDismissed: () {
                                  if (mounted) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              PlayerScreen(lesson: lesson)),
                                    );
                                  }
                                },
                              );
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        PlayerScreen(lesson: lesson)),
                              );
                            }
                          },
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