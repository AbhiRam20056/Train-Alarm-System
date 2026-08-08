import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifGranted = false;
  bool _locationGranted = false;
  bool _bgLocationGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    bool notif = false;
    if (Platform.isAndroid) {
      final plugin = FlutterLocalNotificationsPlugin();
      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      notif = await android?.areNotificationsEnabled() ?? false;
    }

    final locPerm = await Geolocator.checkPermission();
    setState(() {
      _notifGranted = notif;
      _locationGranted = locPerm == LocationPermission.whileInUse ||
          locPerm == LocationPermission.always;
      _bgLocationGranted = locPerm == LocationPermission.always;
    });
  }

  Future<void> _requestNotifications() async {
    if (Platform.isAndroid) {
      final plugin = FlutterLocalNotificationsPlugin();
      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await _checkPermissions();
    }
  }

  Future<void> _requestLocation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
    }
    await _checkPermissions();
  }

  Future<void> _requestBgLocation() async {
    final perm = await Geolocator.checkPermission();
    if (perm != LocationPermission.always) {
      await Geolocator.requestPermission();
    }
    if (await Geolocator.checkPermission() != LocationPermission.always) {
      await Geolocator.openAppSettings();
    }
    await _checkPermissions();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your active alarms will be disarmed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authServiceProvider).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Account ─────────────────────────────────────────────
          _SectionHeader('Account'),
          if (user != null)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  (user.phoneNumber ?? '?')[0 + (user.phoneNumber?.length ?? 1) - 1],
                  style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(user.phoneNumber ?? 'Unknown'),
              subtitle: const Text('Signed in with phone'),
            ),
          ListTile(
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text('Sign out',
                style: TextStyle(color: theme.colorScheme.error)),
            onTap: _confirmLogout,
          ),

          const Divider(),

          // ── Notifications ────────────────────────────────────────
          _SectionHeader('Notifications'),
          _PermissionTile(
            icon: Icons.notifications_outlined,
            title: 'Arrival alarm notifications',
            subtitle: _notifGranted ? 'Enabled' : 'Tap to enable',
            granted: _notifGranted,
            onTap: _notifGranted ? null : _requestNotifications,
          ),

          const Divider(),

          // ── Location ─────────────────────────────────────────────
          _SectionHeader('Location'),
          _PermissionTile(
            icon: Icons.location_on_outlined,
            title: 'Location access',
            subtitle: _locationGranted ? 'Allowed while using app' : 'Tap to enable',
            granted: _locationGranted,
            onTap: _locationGranted ? null : _requestLocation,
          ),
          _PermissionTile(
            icon: Icons.location_searching,
            title: 'Background location',
            subtitle: _bgLocationGranted
                ? 'Always allowed — alarm works when app is closed'
                : 'Tap to enable — required for alarm when app is killed',
            granted: _bgLocationGranted,
            onTap: _bgLocationGranted ? null : _requestBgLocation,
          ),

          const Divider(),

          // ── Battery ──────────────────────────────────────────────
          _SectionHeader('Battery'),
          ListTile(
            leading: const Icon(Icons.battery_saver_outlined),
            title: const Text('Disable battery optimisation'),
            subtitle: const Text(
                'Settings → Apps → Train Alarm → Battery → Unrestricted'),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () => Geolocator.openAppSettings(),
          ),

          const Divider(),

          // ── About ────────────────────────────────────────────────
          _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            trailing: const Text('1.0.0', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final VoidCallback? onTap;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon,
          color: granted ? theme.colorScheme.primary : theme.colorScheme.outline),
      title: Text(title),
      subtitle: Text(subtitle,
          style: TextStyle(
              color: granted ? theme.colorScheme.primary : theme.colorScheme.error,
              fontSize: 12)),
      trailing: granted
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20)
          : Icon(Icons.arrow_forward_ios, size: 14, color: theme.colorScheme.outline),
      onTap: onTap,
    );
  }
}
