import 'package:drift/drift.dart';

class Chats extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get chatId => text().withLength(min: 1, max: 50)();
  TextColumn get name => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get lastMessage => text().nullable()();
  TextColumn get participants =>
      text()(); // JSON encoded list of participant IDs
  BoolColumn get isGroup => boolean().withDefault(const Constant(false))();
  TextColumn get groupAvatarUrl => text().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
}
