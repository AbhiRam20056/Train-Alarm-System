import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/station.dart';
import '../../data/repositories/station_repository.dart';

final _repoProvider = Provider<StationRepository>((_) => StationRepository());

final _searchProvider =
    FutureProvider.family<List<Station>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  final repo = ref.read(_repoProvider);
  return repo.searchByNameOrCode(query);
});

/// Opens this screen and the caller receives the selected [Station] on pop.
class StationSearchScreen extends ConsumerStatefulWidget {
  const StationSearchScreen({super.key});

  @override
  ConsumerState<StationSearchScreen> createState() =>
      _StationSearchScreenState();
}

class _StationSearchScreenState extends ConsumerState<StationSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = ref.watch(_searchProvider(_query));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Station name or code…',
            border: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          ),
          onChanged: (v) => setState(() => _query = v),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (stations) {
          if (_query.trim().isEmpty) {
            return _emptyPrompt(theme);
          }
          if (stations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off,
                      size: 48,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text('No stations found for "$_query"',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5))),
                ],
              ),
            );
          }
          return ListView.separated(
            itemCount: stations.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 56),
            itemBuilder: (_, i) => _StationTile(
              station: stations[i],
              query: _query,
              onTap: () => Navigator.of(context).pop(stations[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyPrompt(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.train_outlined,
              size: 56,
              color: theme.colorScheme.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('Type a station name or code',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 4),
          Text('e.g. "NDLS" or "New Delhi"',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3))),
        ],
      ),
    );
  }
}

class _StationTile extends StatelessWidget {
  final Station station;
  final String query;
  final VoidCallback onTap;

  const _StationTile(
      {required this.station, required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          station.code.length > 4 ? station.code.substring(0, 4) : station.code,
          style: TextStyle(
            fontSize: station.code.length > 3 ? 10 : 12,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      title: _HighlightText(text: station.name, query: query, theme: theme),
      subtitle: Text(
        [station.code, if (station.state != null) station.state!]
            .join(' · '),
        style: theme.textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final ThemeData theme;

  const _HighlightText(
      {required this.text, required this.query, required this.theme});

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return Text(text);

    final lower = text.toLowerCase();
    final start = lower.indexOf(q);
    if (start == -1) return Text(text);

    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyLarge,
        children: [
          if (start > 0) TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, start + q.length),
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (start + q.length < text.length)
            TextSpan(text: text.substring(start + q.length)),
        ],
      ),
    );
  }
}
