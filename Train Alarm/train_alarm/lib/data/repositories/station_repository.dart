import '../models/station.dart';
import '../../services/station_db_service.dart';

class StationRepository {
  final StationDbService _svc;

  StationRepository({StationDbService? service})
      : _svc = service ?? StationDbService.instance;

  /// Returns up to [limit] stations whose name or code matches [query].
  /// Query is trimmed; empty query returns an empty list (not all stations).
  Future<List<Station>> searchByNameOrCode(String query,
      {int limit = 30}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final db = await _svc.db;
    final upper = q.toUpperCase();
    final like = '%$upper%';

    final rows = await db.rawQuery(
      '''
      SELECT * FROM stations
      WHERE UPPER(code) LIKE ?
         OR UPPER(name) LIKE ?
      ORDER BY
        CASE WHEN UPPER(code) = ? THEN 0
             WHEN UPPER(code) LIKE ? THEN 1
             WHEN UPPER(name) LIKE ? THEN 2
             ELSE 3 END,
        name
      LIMIT ?
      ''',
      [like, like, upper, '$upper%', '$upper%', limit],
    );

    return rows.map(Station.fromMap).toList();
  }

  /// Fetch a single station by exact code.
  Future<Station?> findByCode(String code) async {
    final db = await _svc.db;
    final rows = await db.query(
      'stations',
      where: 'code = ?',
      whereArgs: [code.toUpperCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Station.fromMap(rows.first);
  }
}
