import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'train_alarm_channel';
  static const _alarmChannelId = 'train_alarm_fullscreen';
  static const _arrivalNotifId = 1;
  static const _preArrivalNotifId = 2;

  Future<void> init() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestSoundPermission: true,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onTap,
    );

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        'Train Alarm',
        description: 'Journey status notifications',
        importance: Importance.high,
      ));

      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _alarmChannelId,
        'Arrival Alarm',
        description: 'Full-screen alarm on arrival',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      ));

      await android?.requestNotificationsPermission();
    }
  }

  void _onTap(NotificationResponse response) {}

  Future<void> showArrivalAlarm({
    required String stationName,
    required String stationCode,
    String? trainNo,
  }) async {
    final body = trainNo != null
        ? 'Train $trainNo is arriving at $stationName'
        : 'You are arriving at $stationName';

    await _plugin.show(
      id: _arrivalNotifId,
      title: '🔔 Arriving at $stationCode',
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _alarmChannelId,
          'Arrival Alarm',
          channelDescription: 'Full-screen arrival alarm',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          playSound: true,
          enableVibration: true,
          ongoing: true,
          autoCancel: false,
          actions: [
            AndroidNotificationAction('dismiss', 'Dismiss',
                cancelNotification: true),
            AndroidNotificationAction('snooze', 'Snooze 5 min',
                cancelNotification: true),
          ],
        ),
      ),
    );
  }

  Future<void> showPreArrival({
    required String stationName,
    required int etaMin,
  }) async {
    await _plugin.show(
      id: _preArrivalNotifId,
      title: 'Approaching $stationName',
      body: 'Arriving in ~$etaMin minutes',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Train Alarm',
          importance: Importance.high,
          priority: Priority.high,
          autoCancel: true,
        ),
      ),
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id: id);
  Future<void> cancelAll() => _plugin.cancelAll();
}
