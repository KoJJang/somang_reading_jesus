import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/schedule_config.dart';

class ScheduleConfigRepository {
  final FirebaseFirestore _firestore;

  ScheduleConfigRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<ScheduleConfigEntry>> fetchScheduleConfigs() async {
    final Map<int, ScheduleConfigEntry> entriesByYear = {};
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _firestore.collection('config/schedule/years').get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final int? year = _parseScheduleYear(doc.id, data);
      final DateTime? startDate = _parseDate(data['startDate']);
      if (year == null || startDate == null) {
        continue;
      }
      final List<DateTime> breakWeeks = _parseHolidaysOrBreakWeeks(data);
      entriesByYear[year] = ScheduleConfigEntry(
        year: year,
        startDate: _normalizeDate(startDate),
        breakWeeks: breakWeeks.map(_normalizeDate).toList(),
      );
    }
    return entriesByYear.values.toList();
  }

  int? _parseScheduleYear(String docId, Map<String, dynamic> data) {
    final int? yearFromId = int.tryParse(docId);
    if (yearFromId != null) {
      return yearFromId;
    }
    final dynamic yearValue = data['scheduleYear'];
    if (yearValue is int) {
      return yearValue;
    }
    if (yearValue is String) {
      return int.tryParse(yearValue);
    }
    return null;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  List<DateTime> _parseBreakWeeks(dynamic value) {
    if (value is! List) {
      return [];
    }
    final List<DateTime> breakWeeks = [];
    for (final dynamic entry in value) {
      final DateTime? date = _parseDate(entry);
      if (date != null) {
        breakWeeks.add(date);
      }
    }
    return breakWeeks;
  }

  List<DateTime> _parseHolidaysOrBreakWeeks(Map<String, dynamic> data) {
    final dynamic holidaysValue = data['holidays'];
    if (holidaysValue is List) {
      return _parseHolidayRanges(holidaysValue);
    }
    return _parseBreakWeeks(data['breakWeeks']);
  }

  List<DateTime> _parseHolidayRanges(List<dynamic> value) {
    final List<DateTime> breakWeeks = [];
    for (final dynamic entry in value) {
      if (entry is! Map) {
        continue;
      }
      final DateTime? startDate = _parseDate(entry['start']);
      final DateTime? endDate = _parseDate(entry['end']);
      if (startDate == null || endDate == null) {
        continue;
      }
      DateTime cursor = _getWeekStart(startDate);
      final DateTime normalizedEnd = _normalizeDate(endDate);
      while (!cursor.isAfter(normalizedEnd)) {
        breakWeeks.add(cursor);
        cursor = cursor.add(const Duration(days: 7));
      }
    }
    return breakWeeks;
  }

  DateTime _getWeekStart(DateTime date) {
    if (date.weekday == DateTime.sunday) {
      return _normalizeDate(date.add(const Duration(days: 1)));
    }
    return _normalizeDate(date.subtract(Duration(days: date.weekday - 1)));
  }


  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}

