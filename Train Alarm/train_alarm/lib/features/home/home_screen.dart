import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/alarm.dart';
import '../live_tracking/live_tracking_screen.dart';
import '../set_alarm/set_alarm_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _promptBattery());
    }
  }

  Future<void> _promptBattery() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Improve Alarm Reliability'),
        content: const Text(
            'To ensure alarms fire even when the app is closed:\n\n'
            'Settings → Apps → Train Alarm → Battery → Unrestricted'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alarmsAsync = ref.watch(alarmsProvider);
    final user = ref.watch(authStateProvider).value;


    return Scaffold(
      appBar: AppBar(
        title: const Text('Train Alarm'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: alarmsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (alarms) {
          if (alarms.isEmpty) return _empty(theme);
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: alarms.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _AlarmCard(
              alarm: alarms[i],
              onDelete: () async {
                if (user == null) return;
                await ref
                    .read(alarmRepositoryProvider)
                    .deleteAlarm(user.uid, alarms[i].id);
              },
              onTrack: alarms[i].trainNo != null
                  ? () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          LiveTrackingScreen(alarm: alarms[i])))
                  : null,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SetAlarmScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Alarm'),
      ),
    );
  }

  Widget _empty(ThemeData theme) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.train_outlined,
                size: 72,
                color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No active alarms',
                style: theme.textTheme.titleMedium?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 8),
            Text('Tap + to set a destination alarm',
                style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.4))),
          ],
        ),
      );
}

class _AlarmCard extends StatelessWidget {
  final Alarm alarm;
  final VoidCallback onDelete;
  final VoidCallback? onTrack;

  const _AlarmCard(
      {required this.alarm, required this.onDelete, this.onTrack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.location_on,
              color: theme.colorScheme.onPrimaryContainer, size: 20),
        ),
        title: Text(alarm.stationName,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(alarm.stationCode,
                style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            if (alarm.trainNo != null)
              Text('Train ${alarm.trainNo}',
                  style: theme.textTheme.bodySmall),
            Text('Alert at ${alarm.triggerRadiusM} m',
                style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onTrack != null)
              IconButton(
                icon: const Icon(Icons.radar),
                color: theme.colorScheme.primary,
                tooltip: 'Live tracking',
                onPressed: onTrack,
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: theme.colorScheme.error,
              onPressed: onDelete,
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
