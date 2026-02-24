import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Returns a LazyDatabase for web
LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final db = await WasmDatabase.open(
      databaseName: 'chatly_db',
      sqlite3Uri: Uri.parse('sqlite3.wasm'), // must be in web/
      driftWorkerUri:
          Uri.parse('drift_worker.js'), // compiled from dart_worker.dart
    );
    return db.resolvedExecutor;
  });
}
