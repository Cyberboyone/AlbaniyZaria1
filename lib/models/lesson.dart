/// The time of day a lesson is intended for.
enum LessonTime { morning, night, any }

/// A single audio lesson/khutbah excerpt bundled with the app.
class Lesson {
  final String id;
  final String title;
  final String scholarName;
  final String description;
  final String audioAssetPath; // e.g. assets/audio/morning_gratitude.mp3
  Duration duration;
  final LessonTime timeOfDay;
  final String course; // e.g. "Daurar Baiquniyya", "Dalabul Ilmi"
  final List<String> tags; // e.g. ["gratitude", "dua"]
  final String? arabicLabel; // e.g. "الكهف" - shown in the circular artwork
  final String? scholarPhotoPath; // e.g. assets/images/scholar_albaniy.png

  Lesson({
    required this.id,
    required this.title,
    required this.scholarName,
    required this.description,
    required this.audioAssetPath,
    required this.duration,
    required this.timeOfDay,
    this.course = '',
    this.tags = const [],
    this.arabicLabel,
    this.scholarPhotoPath,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      title: json['title'] as String,
      scholarName: json['scholarName'] as String,
      description: json['description'] as String,
      audioAssetPath: json['audioAssetPath'] as String,
      duration: Duration(seconds: json['durationSeconds'] as int),
      timeOfDay: LessonTime.values.firstWhere(
        (e) => e.name == json['timeOfDay'],
        orElse: () => LessonTime.any,
      ),
      course: json['course'] as String? ?? '',
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      arabicLabel: json['arabicLabel'] as String?,
      scholarPhotoPath: json['scholarPhotoPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'scholarName': scholarName,
        'description': description,
        'audioAssetPath': audioAssetPath,
        'durationSeconds': duration.inSeconds,
        'timeOfDay': timeOfDay.name,
        'course': course,
        'tags': tags,
        'arabicLabel': arabicLabel,
        'scholarPhotoPath': scholarPhotoPath,
      };
}