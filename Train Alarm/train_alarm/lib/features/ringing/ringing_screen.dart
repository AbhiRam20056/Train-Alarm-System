import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/notification_service.dart';

class RingingScreen extends StatefulWidget {
  final String stationName;
  final String stationCode;
  final String? trainNo;

  const RingingScreen({
    super.key,
    required this.stationName,
    required this.stationCode,
    this.trainNo,
  });

  @override
  State<RingingScreen> createState() => _RingingScreenState();
}

class _RingingScreenState extends State<RingingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  Timer? _snoozeTimer;

  @override
  void initState() {
    super.initState();
    // Keep screen on and show over lock screen.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _snoozeTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _dismiss() {
    NotificationService.instance.cancelAll();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _snooze() {
    NotificationService.instance.cancelAll();
    // Re-fire alarm after 5 minutes via notification.
    _snoozeTimer = Timer(const Duration(minutes: 5), () {
      NotificationService.instance.showArrivalAlarm(
        stationName: widget.stationName,
        stationCode: widget.stationCode,
        trainNo: widget.trainNo,
      );
    });
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.errorContainer,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // Pulsing icon
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Transform.scale(
                scale: _pulse.value,
                child: child,
              ),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.error,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.error.withValues(alpha: 0.4),
                      blurRadius: 32,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Icon(Icons.train,
                    size: 72, color: theme.colorScheme.onError),
              ),
            ),

            const SizedBox(height: 40),

            Text(
              'Arriving at',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer
                    .withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.stationName,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.stationCode,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ),
            if (widget.trainNo != null) ...[
              const SizedBox(height: 8),
              Text(
                'Train ${widget.trainNo}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer
                      .withValues(alpha: 0.7),
                ),
              ),
            ],

            const Spacer(),

            // Action buttons
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _snooze,
                      icon: const Icon(Icons.snooze),
                      label: const Text('Snooze 5 min'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        foregroundColor: theme.colorScheme.onErrorContainer,
                        side: BorderSide(
                            color: theme.colorScheme.onErrorContainer
                                .withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _dismiss,
                      icon: const Icon(Icons.check),
                      label: const Text('Dismiss'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
