import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/alarm.dart';
import '../../data/models/train_status.dart';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  final Alarm alarm;
  const LiveTrackingScreen({super.key, required this.alarm});

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  Timer? _refreshTimer;
  int _refreshCountdown = 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _refreshCountdown = 60;
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _refreshCountdown--);
      if (_refreshCountdown <= 0) {
        _refresh();
      }
    });
  }

  void _refresh() {
    ref.invalidate(liveStatusProvider(widget.alarm.trainNo!));
    _startTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trainNo = widget.alarm.trainNo!;
    final statusAsync = ref.watch(liveStatusProvider(trainNo));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Train $trainNo', style: const TextStyle(fontSize: 16)),
            Text('→ ${widget.alarm.stationName}',
                style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(error: e.toString(), onRetry: _refresh),
        data: (status) => _StatusBody(
          status: status,
          alarm: widget.alarm,
          refreshCountdown: _refreshCountdown,
          onRefresh: _refresh,
        ),
      ),
    );
  }
}

class _StatusBody extends StatelessWidget {
  final TrainStatus status;
  final Alarm alarm;
  final int refreshCountdown;
  final VoidCallback onRefresh;

  const _StatusBody({
    required this.status,
    required this.alarm,
    required this.refreshCountdown,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Exceptions / alerts ─────────────────────────────────
          if (status.exceptions.isNotEmpty)
            for (final ex in status.exceptions)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded,
                      color: theme.colorScheme.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(ex,
                        style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontSize: 13)),
                  ),
                ]),
              ),

          // ── Status card ─────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(status.trainName.isNotEmpty ? status.trainName : 'Train ${status.trainNo}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.location_on,
                    label: 'Current',
                    value: status.currentStation.isNotEmpty
                        ? status.currentStation
                        : 'En route',
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.arrow_forward,
                    label: 'Next halt',
                    value: status.nextHalt.isNotEmpty ? status.nextHalt : '—',
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.schedule,
                    label: 'Delay',
                    value: status.delayMinutes == 0
                        ? 'On time'
                        : '${status.delayMinutes} min late',
                    color: status.delayMinutes == 0
                        ? Colors.green
                        : theme.colorScheme.error,
                  ),
                  if (status.segmentProgress > 0) ...[
                    const SizedBox(height: 14),
                    Text('Segment progress',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.55))),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: status.segmentProgress.clamp(0.0, 1.0),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Destination info ────────────────────────────────────
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(Icons.flag_rounded,
                    color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your destination',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.7))),
                      Text(alarm.stationName,
                          style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold)),
                      Text(alarm.stationCode,
                          style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.7),
                              fontSize: 12)),
                    ],
                  ),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 12),

          // ── Halt list ───────────────────────────────────────────
          if (status.halts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Upcoming stops',
                  style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8)),
            ),
            Card(
              child: Column(
                children: [
                  for (int i = 0; i < status.halts.length; i++)
                    _HaltTile(
                      halt: status.halts[i],
                      isDestination:
                          status.halts[i].stationCode == alarm.stationCode,
                      isLast: i == status.halts.length - 1,
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ── Refresh countdown ────────────────────────────────────
          Center(
            child: Text(
              'Refreshes in ${refreshCountdown}s',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      Icon(icon,
          size: 18,
          color: color ?? theme.colorScheme.onSurface.withValues(alpha: 0.55)),
      const SizedBox(width: 10),
      Text('$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
      Expanded(
        child: Text(value,
            style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600, color: color)),
      ),
    ]);
  }
}

class _HaltTile extends StatelessWidget {
  final HaltInfo halt;
  final bool isDestination;
  final bool isLast;

  const _HaltTile(
      {required this.halt,
      required this.isDestination,
      required this.isLast});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: isDestination
                ? theme.colorScheme.primary
                : halt.departed
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.primaryContainer,
            child: Icon(
              isDestination ? Icons.flag : Icons.train,
              size: 14,
              color: isDestination
                  ? theme.colorScheme.onPrimary
                  : halt.departed
                      ? theme.colorScheme.outline
                      : theme.colorScheme.onPrimaryContainer,
            ),
          ),
          title: Text(halt.stationName,
              style: TextStyle(
                  fontWeight:
                      isDestination ? FontWeight.bold : FontWeight.normal,
                  color: isDestination ? theme.colorScheme.primary : null,
                  fontSize: 13)),
          subtitle: Text(halt.stationCode,
              style: const TextStyle(fontSize: 11)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(halt.scheduledArrival,
                  style: const TextStyle(fontSize: 12)),
              if (halt.delayMinutes != 0)
                Text('+${halt.delayMinutes}m',
                    style: TextStyle(
                        fontSize: 11, color: theme.colorScheme.error)),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 56, color: theme.dividerColor),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isQuota = error.contains('429');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            isQuota ? Icons.hourglass_empty : Icons.wifi_off_rounded,
            size: 56,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            isQuota
                ? 'API limit reached — GPS alarm still active'
                : 'Could not fetch live status',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ]),
      ),
    );
  }
}
