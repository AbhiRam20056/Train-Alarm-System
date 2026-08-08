import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../data/models/alarm.dart';
import 'geofence_manager.dart';
import 'location_service.dart';

/// Coordinates alarm arming: permissions → geofence registration.
class AlarmOrchestrator {
  AlarmOrchestrator._();
  static final AlarmOrchestrator instance = AlarmOrchestrator._();

  /// Call once at app startup to re-arm any active alarms from Firestore.
  Future<void> rearmAll(List<Alarm> alarms) async {
    for (final alarm in alarms) {
      await GeofenceManager.instance.startForAlarm(alarm);
    }
  }

  /// Arm a single newly-created alarm.
  Future<bool> armAlarm(BuildContext context, Alarm alarm) async {
    final locGranted = await LocationService.instance.requestPermission();
    if (!locGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location permission required for GPS alarm'),
        ));
      }
      return false;
    }

    // Request background location for when app is killed.
    await LocationService.instance.requestBackgroundPermission();

    await GeofenceManager.instance.startForAlarm(alarm);
    return true;
  }

  Future<void> disarmAlarm(String alarmId) async {
    await GeofenceManager.instance.stopForAlarm(alarmId);
  }
}

/// Provider that syncs live Firestore alarms → geofence manager.
final alarmOrchestratorProvider = Provider<AlarmOrchestrator>(
    (_) => AlarmOrchestrator.instance);

/// Auto-arms geofences whenever the alarms list changes.
final geofenceSyncProvider = Provider.autoDispose((ref) {
  ref.listen<AsyncValue<List<Alarm>>>(alarmsProvider, (prev, next) {
    next.whenData((alarms) {
      AlarmOrchestrator.instance.rearmAll(alarms);
    });
  });
});
