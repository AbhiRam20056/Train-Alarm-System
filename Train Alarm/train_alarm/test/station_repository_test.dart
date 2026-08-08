import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:train_alarm/data/repositories/station_repository.dart';
import 'package:train_alarm/services/station_db_service.dart' show StationDbService;

class _FakeDbService extends StationDbService {
  final String dbPath;
  _FakeDbService(this.dbPath);

  @override
  Future<Database> openDb() => databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(readOnly: true),
      );
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  TestWidgetsFlutterBinding.ensureInitialized();

  // Path to the real bundled DB (relative to project root when tests run).
  const dbAssetPath =
      'assets/stations.db';

  late StationRepository repo;

  setUpAll(() async {
    // sqflite_ffi can open the file directly.
    final absPath = File(dbAssetPath).absolute.path;
    repo = StationRepository(service: _FakeDbService(absPath));
  });

  test('search by exact code NDLS returns New Delhi', () async {
    final results = await repo.searchByNameOrCode('NDLS');
    expect(results, isNotEmpty);
    expect(results.first.code, 'NDLS');
  });

  test('search by partial name "New Del" returns New Delhi', () async {
    final results = await repo.searchByNameOrCode('New Del');
    expect(results.any((s) => s.code == 'NDLS'), isTrue);
  });

  test('empty query returns empty list', () async {
    final results = await repo.searchByNameOrCode('');
    expect(results, isEmpty);
  });

  test('whitespace-only query returns empty list', () async {
    final results = await repo.searchByNameOrCode('   ');
    expect(results, isEmpty);
  });

  test('unknown query returns empty list', () async {
    final results = await repo.searchByNameOrCode('ZZZNOTASTATION999');
    expect(results, isEmpty);
  });

  test('findByCode returns correct station', () async {
    final s = await repo.findByCode('NDLS');
    expect(s, isNotNull);
    expect(s!.name, isNotEmpty);
    expect(s.lat, isNonZero);
    expect(s.lng, isNonZero);
  });

  test('findByCode for unknown code returns null', () async {
    final s = await repo.findByCode('ZZZZ999');
    expect(s, isNull);
  });

  test('results are ordered — exact code match comes first', () async {
    final results = await repo.searchByNameOrCode('MAS');
    expect(results.isNotEmpty, isTrue);
    expect(results.first.code, 'MAS');
  });

  test('limit is respected', () async {
    final results = await repo.searchByNameOrCode('a', limit: 5);
    expect(results.length, lessThanOrEqualTo(5));
  });
}
