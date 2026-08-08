class TrainStatus {
  final String trainNo;
  final String trainName;
  final String currentStation;
  final String nextHalt;
  final int delayMinutes;
  final double? lat;
  final double? lng;
  final double segmentProgress;
  final List<HaltInfo> halts;
  final List<String> exceptions;

  const TrainStatus({
    required this.trainNo,
    required this.trainName,
    required this.currentStation,
    required this.nextHalt,
    required this.delayMinutes,
    this.lat,
    this.lng,
    required this.segmentProgress,
    required this.halts,
    required this.exceptions,
  });

  factory TrainStatus.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final loc = data['currentLocation'] as Map<String, dynamic>?;

    // nextHalt can be a String or an object {stationCode, stationName, ...}
    final nextHaltRaw = data['nextHalt'];
    String nextHalt = '';
    if (nextHaltRaw is String) {
      nextHalt = nextHaltRaw;
    } else if (nextHaltRaw is Map) {
      final name = nextHaltRaw['stationName']?.toString() ?? '';
      final code = nextHaltRaw['stationCode']?.toString() ?? '';
      nextHalt = name.isNotEmpty ? '$name ($code)' : code;
    }

    // currentStation can also be an object
    final curRaw = data['currentStation'];
    String currentStation = '';
    if (curRaw is String) {
      currentStation = curRaw;
    } else if (curRaw is Map) {
      final name = curRaw['stationName']?.toString() ?? '';
      final code = curRaw['stationCode']?.toString() ?? '';
      currentStation = name.isNotEmpty ? '$name ($code)' : code;
    }

    // halts may be under 'halts', 'stops', or 'schedule'
    final rawHalts = (data['halts'] ?? data['stops'] ?? data['schedule']) as List<dynamic>?;
    final haltList = (rawHalts ?? [])
        .map((h) => HaltInfo.fromJson(h as Map<String, dynamic>))
        .toList();

    final exList = (data['exceptions'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    return TrainStatus(
      trainNo: data['trainNumber']?.toString() ?? '',
      trainName: data['trainName']?.toString() ?? '',
      currentStation: currentStation,
      nextHalt: nextHalt,
      delayMinutes: (data['delayMinutes'] as num?)?.toInt() ?? 0,
      lat: (loc?['lat'] as num?)?.toDouble(),
      lng: (loc?['lng'] as num?)?.toDouble(),
      segmentProgress: (loc?['segmentProgress'] as num?)?.toDouble() ?? 0.0,
      halts: haltList,
      exceptions: exList,
    );
  }
}

class HaltInfo {
  final String stationCode;
  final String stationName;
  final String scheduledArrival;
  final String? actualArrival;
  final int delayMinutes;
  final bool departed;

  const HaltInfo({
    required this.stationCode,
    required this.stationName,
    required this.scheduledArrival,
    this.actualArrival,
    required this.delayMinutes,
    required this.departed,
  });

  factory HaltInfo.fromJson(Map<String, dynamic> json) {
    // arrival time may be under different keys
    final arrival = (json['scheduledArrival'] ??
            json['arrival'] ??
            json['scheduledTime'] ??
            '')
        .toString();
    final actual =
        (json['actualArrival'] ?? json['actualTime'])?.toString();

    return HaltInfo(
      stationCode: json['stationCode']?.toString() ?? '',
      stationName: json['stationName']?.toString() ?? '',
      scheduledArrival: arrival,
      actualArrival: actual,
      delayMinutes: (json['delayMinutes'] as num?)?.toInt() ?? 0,
      departed: json['departed'] as bool? ?? false,
    );
  }
}
