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

  // 개별 날짜 알림 슬롯: ID 1~45
  static const int _scheduleCount = 45;
  static const int _notificationIdBase = 1; // 1..45 사용, 0은 show()용

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
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
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

  /// 앱 재실행/포그라운드 복귀 시 소진된 알림 보충
  Future<void> rescheduleIfEnabled() async {
    if (kIsWeb) return;
    final settings = await loadSettings();
    if (settings.enabled) {
      await _scheduleDailyReminder(settings.hour, settings.minute);
    }
  }

  /// 단일 알림 표시 (FCM 수신 시에도 이 메서드 호출)
  Future<void> show(String title, String body) async {
    if (kIsWeb) return;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reading',
          '통독 알림',
          channelDescription: '매일 말씀 읽기 리마인더',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      await _plugin.show(0, title, body, details);
      debugPrint('[NotificationService] show() 완료: $title');
    } catch (e) {
      debugPrint('[NotificationService] show() 오류: $e');
    }
  }

  Future<void> _scheduleDailyReminder(int hour, int minute) async {
    if (kIsWeb) return;
    await _cancelDailyReminder();

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

    // 오늘 지정 시각이 아직 안 지났으면 오늘부터, 지났으면 내일부터 시작
    final now = tz.TZDateTime.now(tz.local);
    var candidate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }

    // 유효한 날짜(월~토, 휴식주 제외)를 찾아 45개 개별 등록
    int registered = 0;
    while (registered < _scheduleCount) {
      if (!_shouldSkip(candidate)) {
        await _plugin.zonedSchedule(
          _notificationIdBase + registered,
          '오늘의 말씀',
          '말씀 읽을 시간입니다 📖',
          candidate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        registered++;
      }
      candidate = candidate.add(const Duration(days: 1));
    }
  }

  Future<void> _cancelDailyReminder() async {
    for (int i = 0; i < _scheduleCount; i++) {
      await _plugin.cancel(_notificationIdBase + i);
    }
  }

  bool _shouldSkip(DateTime dt) {
    if (dt.weekday == DateTime.sunday) return true;
    if (ScheduleConfig.isBreakWeek(dt)) return true;
    return false;
  }
}
