import 'package:geofence_service/geofence_service.dart';

import '../data/models/alarm.dart';
import 'notification_service.dart';

/// Manages OS-level geofences for active alarms.
class GeofenceManager {
  GeofenceManager._();
  static final GeofenceManager instance = GeofenceManager._();

  final _service = GeofenceService.instance.setup(
    interval: 5000,
    accuracy: 100,
    loiteringDelayMs: 60000,
    statusChangeDelayMs: 10000,
    useActivityRecognition: false,
    allowMockLocations: false,
    printDevLog: false,
    geofenceRadiusSortType: GeofenceRadiusSortType.DESC,
  );

  final Map<String, Alarm> _alarmMap = {};
  bool _running = false;
  bool _listenerAdded = false;

  Future<void> startForAlarm(Alarm alarm) async {
    final geofenceId = 'alarm_${alarm.id}';
    _alarmMap[geofenceId] = alarm;

    final geofence = Geofence(
      id: geofenceId,
      latitude: alarm.lat,
      longitude: alarm.lng,
      radius: [
        GeofenceRadius(
          id: 'r_${alarm.triggerRadiusM}',
          length: alarm.triggerRadiusM.toDouble(),
        ),
      ],
    );

    if (!_listenerAdded) {
      _service.addGeofenceStatusChangeListener(_onGeofenceStatus);
      _service.addStreamErrorListener(_onError);
      _listenerAdded = true;
    }

    if (!_running) {
      await _service.start([geofence]);
      _running = true;
    } else {
      _service.addGeofence(geofence);
    }
  }

  Future<void> stopForAlarm(String alarmId) async {
    final geofenceId = 'alarm_$alarmId';
    _alarmMap.remove(geofenceId);
    _service.removeGeofenceById(geofenceId);
    if (_alarmMap.isEmpty && _running) {
      await _service.stop();
      _running = false;
    }
  }

  Future<void> stopAll() async {
    _alarmMap.clear();
    if (_running) {
      await _service.stop();
      _running = false;
    }
  }

  Future<void> _onGeofenceStatus(
    Geofence geofence,
    GeofenceRadius radius,
    GeofenceStatus status,
    Location location,
  ) async {
    if (status != GeofenceStatus.ENTER) return;

    final alarm = _alarmMap[geofence.id];
    if (alarm == null) return;

    await NotificationService.instance.showArrivalAlarm(
      stationName: alarm.stationName,
      stationCode: alarm.stationCode,
      trainNo: alarm.trainNo,
    );

    await stopForAlarm(alarm.id);
  }

  void _onError(dynamic error) {
    // GPS errors fall back to live-status detection in Phase 5.
  }
}
