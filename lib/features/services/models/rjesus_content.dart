class DailyReading {
  final int volume;
  final int chapter;
  final int day;
  final String title;
  final String url;
  final DateTime date;

  DailyReading({
    required this.volume,
    required this.chapter,
    required this.day,
    required this.title,
    required this.url,
    required this.date,
  });

  factory DailyReading.fromCsv(String csvLine) {
    final parts = csvLine.split(',');
    return DailyReading(
      volume: int.parse(parts[0].trim()),
      chapter: int.parse(parts[1].trim()),
      day: int.parse(parts[2].trim()),
      title: parts[3].trim(),
      url: parts[4].trim(),
      date: DateTime.parse(parts[5].trim()),
    );
  }

  // 유튜브 ID 추출
  String? get youtubeId {
    final regex = RegExp(
      r'(?:youtube\.com/watch\?v=|youtu\.be/)([a-zA-Z0-9_-]+)',
    );
    final match = regex.firstMatch(url);
    return match?.group(1);
  }
}

class WeeklyCommentary {
  final int volume;
  final int chapter;
  final String title;
  final String url;

  WeeklyCommentary({
    required this.volume,
    required this.chapter,
    required this.title,
    required this.url,
  });

  factory WeeklyCommentary.fromCsv(String csvLine) {
    final parts = csvLine.split(',');
    return WeeklyCommentary(
      volume: int.parse(parts[0].trim()),
      chapter: int.parse(parts[1].trim()),
      title: parts[2].trim(),
      url: parts[3].trim(),
    );
  }

  // 유튜브 ID 추출
  String? get youtubeId {
    final regex = RegExp(
      r'(?:youtube\.com/watch\?v=|youtu\.be/)([a-zA-Z0-9_-]+)',
    );
    final match = regex.firstMatch(url);
    return match?.group(1);
  }
}
