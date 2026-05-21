import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/bus.dart';
import 'bus_utils.dart';

/// 通知类型
enum NotificationType {
  busReminder, // 班车发车提醒
  canteenAlert, // 食堂拥挤预警
  libraryAlert, // 图书馆座位提醒
}

/// 本地通知服务
///
/// 提供班车发车提醒、食堂拥挤预警等功能
class NotificationService {
  static NotificationService? _instance;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  NotificationService._();

  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }

  /// 初始化通知服务
  Future<void> initialize() async {
    if (_initialized) return;

    // 初始化时区数据
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

    // Android 配置
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 配置
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
  }

  /// 请求通知权限
  Future<bool> requestPermissions() async {
    await initialize();

    // Android 13+ 需要请求权限
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    // iOS 请求权限
    final ios = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  /// 设置班车发车提醒
  ///
  /// [schedule] 班车时刻表
  /// [route] 班车路线
  /// [minutesBefore] 提前多少分钟提醒（默认15分钟）
  Future<void> scheduleBusReminder({
    required BusSchedule schedule,
    required BusRoute route,
    int minutesBefore = 15,
  }) async {
    await initialize();

    // 计算通知时间
    final now = DateTime.now();
    final departureMinutes = schedule.departureMinutes;
    final notificationMinutes = departureMinutes - minutesBefore;

    // 如果已经过了提醒时间，则不设置
    if (notificationMinutes <= now.hour * 60 + now.minute) {
      return;
    }

    final notificationTime = DateTime(
      now.year,
      now.month,
      now.day,
      notificationMinutes ~/ 60,
      notificationMinutes % 60,
    );

    // 如果是明天的班车，加一天
    if (notificationTime.isBefore(now)) {
      notificationTime.add(const Duration(days: 1));
    }

    final notificationId = _generateNotificationId(
      NotificationType.busReminder,
      schedule.id,
    );

    const androidDetails = AndroidNotificationDetails(
      'bus_reminders',
      '班车提醒',
      channelDescription: '班车发车前提醒',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = '${route.name} 即将发车';
    final body = '${schedule.departureLocation} → ${schedule.arrivalLocation}\n'
        '发车时间: ${schedule.departureTime}\n'
        '还有 $minutesBefore 分钟';

    await _notifications.zonedSchedule(
      notificationId,
      title,
      body,
      tz.TZDateTime.from(notificationTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'bus:${schedule.id}',
    );
  }

  /// 批量设置班车提醒
  ///
  /// [results] 搜索结果
  /// [minutesBefore] 提前分钟数
  Future<void> scheduleBusReminders({
    required List<BusSearchResult> results,
    int minutesBefore = 15,
  }) async {
    for (final result in results) {
      await scheduleBusReminder(
        schedule: result.schedule,
        route: result.route,
        minutesBefore: minutesBefore,
      );
    }
  }

  /// 取消班车提醒
  Future<void> cancelBusReminder(String scheduleId) async {
    final notificationId = _generateNotificationId(
      NotificationType.busReminder,
      scheduleId,
    );
    await _notifications.cancel(notificationId);
  }

  /// 显示即时通知（不延时）
  Future<void> showNotification({
    required String title,
    required String body,
    NotificationType type = NotificationType.busReminder,
    String? payload,
  }) async {
    await initialize();

    final channelId = _getChannelId(type);
    final channelName = _getChannelName(type);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// 取消所有通知
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// 获取所有待处理的通知
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// 检查是否有权限
  Future<bool> hasPermission() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.areNotificationsEnabled();
      return granted ?? false;
    }
    return true;
  }

  // ============ 私有方法 ============

  /// 通知点击回调
  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    // 根据 payload 处理跳转
    if (payload.startsWith('bus:')) {
      // 跳转到班车页面
      // 这里需要通过 Navigator 或者 Router 跳转
      // 具体实现需要在 main.dart 中配置
    }
  }

  /// 生成通知 ID
  int _generateNotificationId(NotificationType type, String identifier) {
    final typeCode = type.index * 10000;
    final hash = identifier.hashCode.abs() % 10000;
    return typeCode + hash;
  }

  /// 获取渠道 ID
  String _getChannelId(NotificationType type) {
    switch (type) {
      case NotificationType.busReminder:
        return 'bus_reminders';
      case NotificationType.canteenAlert:
        return 'canteen_alerts';
      case NotificationType.libraryAlert:
        return 'library_alerts';
    }
  }

  /// 获取渠道名称
  String _getChannelName(NotificationType type) {
    switch (type) {
      case NotificationType.busReminder:
        return '班车提醒';
      case NotificationType.canteenAlert:
        return '食堂预警';
      case NotificationType.libraryAlert:
        return '图书馆提醒';
    }
  }
}
