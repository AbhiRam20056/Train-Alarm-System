import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/alarm.dart';
import '../data/models/train_status.dart';
import '../data/repositories/alarm_repository.dart';
import '../data/repositories/station_repository.dart';
import '../services/auth_service.dart';
import '../services/railradar_service.dart';
import '../services/station_db_service.dart';

final authServiceProvider = Provider<AuthService>((_) => AuthService());

final authStateProvider = StreamProvider<User?>(
    (ref) => ref.read(authServiceProvider).userStream);

final alarmRepositoryProvider =
    Provider<AlarmRepository>((_) => AlarmRepository());

final stationRepositoryProvider = Provider<StationRepository>(
    (_) => StationRepository(service: StationDbService.instance));

final alarmsProvider = StreamProvider.autoDispose<List<Alarm>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.read(alarmRepositoryProvider).watchAlarms(user.uid);
});

final railRadarServiceProvider =
    Provider<RailRadarService>((_) => RailRadarService.instance);

// Auto-refreshing live status — pass trainNo as family argument
final liveStatusProvider =
    FutureProvider.autoDispose.family<TrainStatus, String>((ref, trainNo) {
  return ref.read(railRadarServiceProvider).getLiveStatus(trainNo);
});
