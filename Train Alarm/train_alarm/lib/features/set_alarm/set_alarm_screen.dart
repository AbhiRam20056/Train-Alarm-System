import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/alarm.dart';
import '../../data/models/station.dart';
import '../../services/alarm_orchestrator.dart';
import 'station_search_screen.dart';

class SetAlarmScreen extends ConsumerStatefulWidget {
  const SetAlarmScreen({super.key});

  @override
  ConsumerState<SetAlarmScreen> createState() => _SetAlarmScreenState();
}

class _SetAlarmScreenState extends ConsumerState<SetAlarmScreen> {
  Station? _station;
  final _trainCtrl = TextEditingController();
  int _radiusM = 800;
  int _leadMin = 10;
  bool _saving = false;

  @override
  void dispose() {
    _trainCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStation() async {
    final result = await Navigator.of(context).push<Station>(
      MaterialPageRoute(builder: (_) => const StationSearchScreen()),
    );
    if (result != null) setState(() => _station = result);
  }

  Future<void> _arm() async {
    if (_station == null) return;
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _saving = true);
    final alarm = Alarm(
      id: '',
      stationCode: _station!.code,
      stationName: _station!.name,
      lat: _station!.lat,
      lng: _station!.lng,
      trainNo: _trainCtrl.text.trim().isEmpty ? null : _trainCtrl.text.trim(),
      triggerRadiusM: _radiusM,
      leadTimeMin: _leadMin,
      isActive: true,
      createdAt: DateTime.now(),
    );

    final created =
        await ref.read(alarmRepositoryProvider).createAlarm(user.uid, alarm);
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    await AlarmOrchestrator.instance.armAlarm(context, created);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Set Alarm')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Station picker
          Text('Destination Station', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickStation,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.train_outlined,
                      color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _station == null
                        ? Text('Select station…',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5)))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_station!.name,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600)),
                              Text(_station!.code,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.primary)),
                            ],
                          ),
                  ),
                  Icon(Icons.chevron_right,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Optional train number
          Text('Train Number (optional)', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _trainCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'e.g. 12301',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add for live ETA tracking. Leave blank for GPS-only mode.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          ),

          const SizedBox(height: 24),

          // Trigger radius
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Alert Radius', style: theme.textTheme.labelLarge),
              Text('$_radiusM m',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.primary)),
            ],
          ),
          Slider(
            value: _radiusM.toDouble(),
            min: 300,
            max: 2000,
            divisions: 17,
            label: '$_radiusM m',
            onChanged: (v) => setState(() => _radiusM = v.round()),
          ),

          const SizedBox(height: 8),

          // Lead time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pre-alert Lead Time', style: theme.textTheme.labelLarge),
              Text('$_leadMin min',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.primary)),
            ],
          ),
          Slider(
            value: _leadMin.toDouble(),
            min: 5,
            max: 30,
            divisions: 5,
            label: '$_leadMin min',
            onChanged: (v) => setState(() => _leadMin = v.round()),
          ),

          const SizedBox(height: 32),

          FilledButton.icon(
            onPressed: (_station == null || _saving) ? null : _arm,
            icon: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.alarm_add),
            label: const Text('Arm Alarm'),
          ),
        ],
      ),
    );
  }
}
