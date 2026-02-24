import 'package:drift/drift.dart';
// ignore: unused_import
import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional imports: pick web or native implementation
import 'database_native.dart' if (dart.library.html) 'database_web.dart';
import 'tables/messages.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Messages])
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(openConnection());

  static AppDatabase? _instance;

  static AppDatabase get instance {
    _instance ??= AppDatabase._();
    return _instance!;
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Add future schema migrations here
        },
      );

  Future<void> insertMessage(MessagesCompanion message) =>
      into(messages).insertOnConflictUpdate(message);

  Stream<List<Message>> watchChat(String chatId) {
    return (select(messages)
          ..where((tbl) => tbl.chatId.equals(chatId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<void> markSynced(String id) async {
    await (update(messages)..where((m) => m.id.equals(id))).write(
      MessagesCompanion(isSynced: const Value(true)),
    );
  }

  Future<void> deleteMessage(String id) async {
    await (delete(messages)..where((m) => m.id.equals(id))).go();
  }

  Future<void> markMessageDeleted(String id) async {
    await (update(messages)..where((m) => m.id.equals(id))).write(
      MessagesCompanion(isDeleted: const Value(true)),
    );
  }
}
