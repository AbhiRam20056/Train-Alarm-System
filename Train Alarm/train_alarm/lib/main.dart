import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/phone_auth_screen.dart';
import 'features/home/home_screen.dart';
import 'services/alarm_orchestrator.dart';
import 'services/notification_service.dart';
import 'services/station_db_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await StationDbService.instance.init();
  await NotificationService.instance.init();
  runApp(const ProviderScope(child: TrainAlarmApp()));
}

class TrainAlarmApp extends ConsumerWidget {
  const TrainAlarmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Activate geofence sync whenever alarms change.
    ref.watch(geofenceSyncProvider);

    final authAsync = ref.watch(authStateProvider);
    return MaterialApp(
      title: 'Train Alarm',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: authAsync.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, st) => const PhoneAuthScreen(),
        data: (user) =>
            user != null ? const HomeScreen() : const PhoneAuthScreen(),
      ),
    );
  }
}
