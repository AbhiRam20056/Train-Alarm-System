import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alarm.dart';

class AlarmRepository {
  final FirebaseFirestore _db;

  AlarmRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _alarms(String uid) =>
      _db.collection('users').doc(uid).collection('alarms');

  Stream<List<Alarm>> watchAlarms(String uid) => _alarms(uid)
      .where('isActive', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Alarm.fromFirestore).toList());

  Future<Alarm> createAlarm(String uid, Alarm alarm) async {
    final ref = await _alarms(uid).add(alarm.toMap());
    return Alarm(
      id: ref.id,
      stationCode: alarm.stationCode,
      stationName: alarm.stationName,
      lat: alarm.lat,
      lng: alarm.lng,
      trainNo: alarm.trainNo,
      triggerRadiusM: alarm.triggerRadiusM,
      leadTimeMin: alarm.leadTimeMin,
      isActive: alarm.isActive,
      createdAt: alarm.createdAt,
    );
  }

  Future<void> updateAlarm(String uid, Alarm alarm) =>
      _alarms(uid).doc(alarm.id).update(alarm.toMap());

  Future<void> deleteAlarm(String uid, String alarmId) =>
      _alarms(uid).doc(alarmId).delete();

  Future<void> deactivateAlarm(String uid, String alarmId) =>
      _alarms(uid).doc(alarmId).update({'isActive': false});
}
