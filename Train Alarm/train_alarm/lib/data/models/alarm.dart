import 'package:cloud_firestore/cloud_firestore.dart';

class Alarm {
  final String id;
  final String stationCode;
  final String stationName;
  final double lat;
  final double lng;
  final String? trainNo;
  final int triggerRadiusM;
  final int leadTimeMin;
  final bool isActive;
  final DateTime createdAt;

  const Alarm({
    required this.id,
    required this.stationCode,
    required this.stationName,
    required this.lat,
    required this.lng,
    this.trainNo,
    this.triggerRadiusM = 800,
    this.leadTimeMin = 10,
    this.isActive = true,
    required this.createdAt,
  });

  factory Alarm.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Alarm(
      id: doc.id,
      stationCode: d['stationCode'] as String,
      stationName: d['stationName'] as String,
      lat: (d['lat'] as num).toDouble(),
      lng: (d['lng'] as num).toDouble(),
      trainNo: d['trainNo'] as String?,
      triggerRadiusM: (d['triggerRadiusM'] as num?)?.toInt() ?? 800,
      leadTimeMin: (d['leadTimeMin'] as num?)?.toInt() ?? 10,
      isActive: d['isActive'] as bool? ?? true,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'stationCode': stationCode,
        'stationName': stationName,
        'lat': lat,
        'lng': lng,
        'trainNo': trainNo,
        'triggerRadiusM': triggerRadiusM,
        'leadTimeMin': leadTimeMin,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  Alarm copyWith({
    String? stationCode,
    String? stationName,
    double? lat,
    double? lng,
    String? trainNo,
    int? triggerRadiusM,
    int? leadTimeMin,
    bool? isActive,
  }) =>
      Alarm(
        id: id,
        stationCode: stationCode ?? this.stationCode,
        stationName: stationName ?? this.stationName,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        trainNo: trainNo ?? this.trainNo,
        triggerRadiusM: triggerRadiusM ?? this.triggerRadiusM,
        leadTimeMin: leadTimeMin ?? this.leadTimeMin,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );
}
