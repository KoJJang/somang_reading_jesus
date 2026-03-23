import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../config/schedule_config.dart';

/// 로컬 푸시 알림 서비스
///
/// FCM 확장 시: 수신한 FCM 메시지에서 show()를 호출하면 됨.
/// 이 서비스의 구조를 변경할 필요 없음.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String _enabledKey = 'notification_enabled';
  static const String _hourKey = 'notification_hour';
  static const String _minuteKey = 'notification_minute';
  static const int _dailyNotificationId = 1;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
  }

  /// iOS 알림 권한 요청. 반환값: 권한 허용 여부
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    return false;
  }

  /// 저장된 알림 설정 로드
  Future<({bool enabled, int hour, int minute})> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      enabled: prefs.getBool(_enabledKey) ?? false,
      hour: prefs.getInt(_hourKey) ?? 8,
      minute: prefs.getInt(_minuteKey) ?? 0,
    );
  }

  /// 알림 설정 저장 + 스케줄 재등록
  Future<void> saveSettings({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    await prefs.setInt(_hourKey, hour);
    await prefs.setInt(_minuteKey, minute);

    if (enabled) {
      await _scheduleDailyReminder(hour, minute);
    } else {
      await _cancelDailyReminder();
    }
  }

  /// 단일 알림 표시 (FCM 수신 시에도 이 메서드 호출)
  Future<void> show(String title, String body) async {
    if (kIsWeb) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_reading',
        '통독 알림',
        channelDescription: '매일 말씀 읽기 리마인더',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(0, title, body, details);
  }

  Future<void> _scheduleDailyReminder(int hour, int minute) async {
    if (kIsWeb) return;
    await _cancelDailyReminder();

    // 다음 유효 알림 시각 계산 (오늘 or 내일)
    final now = tz.TZDateTime.now(tz.local);
    var scheduledTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }
    scheduledTime = _nextValidDay(scheduledTime);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_reading',
        '통독 알림',
        channelDescription: '매일 말씀 읽기 리마인더',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    // 매일 같은 시각에 반복 예약 (휴식주/일요일은 수신 측에서 무시)
    await _plugin.zonedSchedule(
      _dailyNotificationId,
      '오늘의 말씀',
      '말씀 읽을 시간입니다 📖',
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _cancelDailyReminder() async {
    await _plugin.cancel(_dailyNotificationId);
  }

  /// 알림을 받을 수 없는 날(일요일·휴식주)이면 다음 유효일로 이동
  tz.TZDateTime _nextValidDay(tz.TZDateTime dt) {
    while (_shouldSkip(dt)) {
      dt = dt.add(const Duration(days: 1));
    }
    return dt;
  }

  bool _shouldSkip(DateTime dt) {
    if (dt.weekday == DateTime.sunday) return true;
    if (ScheduleConfig.isBreakWeek(dt)) return true;
    return false;
  }
}
