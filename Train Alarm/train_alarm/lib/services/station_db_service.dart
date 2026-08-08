import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Abstract base — both the real service and test fakes extend this.
abstract class StationDbService {
  StationDbService();

  Database? _db;

  Future<Database> get db async {
    _db ??= await openDb();
    return _db!;
  }

  /// Override in tests to supply a different database.
  Future<Database> openDb();

  Future<void> init() async => await db;

  static final StationDbService instance = _ProductionDbService();
}

class _ProductionDbService extends StationDbService {
  @override
  Future<Database> openDb() async {
    final docsDir = await getDatabasesPath();
    final dbPath = p.join(docsDir, 'stations.db');

    final file = File(dbPath);
    if (!file.existsSync() || file.lengthSync() < 1024) {
      final data = await rootBundle.load('assets/stations.db');
      final bytes = data.buffer.asUint8List();
      await file.writeAsBytes(bytes, flush: true);
    }

    return openDatabase(dbPath, readOnly: true);
  }
}
