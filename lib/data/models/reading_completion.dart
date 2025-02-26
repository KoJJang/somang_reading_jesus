class ReadingCompletion {
  final DateTime date;
  final int year;
  final int week;
  final int day;
  final List<Map<String, dynamic>> readings;

  ReadingCompletion({
    required this.date,
    required this.year,
    required this.week,
    required this.day,
    required this.readings,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'year': year,
      'week': week,
      'day': day,
      'readings': readings,
    };
  }

  factory ReadingCompletion.fromMap(Map<String, dynamic> map) {
    return ReadingCompletion(
      date: DateTime.parse(map['date']),
      year: map['year'],
      week: map['week'],
      day: map['day'],
      readings: List<Map<String, dynamic>>.from(map['readings']),
    );
  }
}
