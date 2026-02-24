import 'package:drift/drift.dart';

class Messages extends Table {
  TextColumn get id => text()(); // local message ID (uuid)
  TextColumn get chatId => text()(); // userId or groupId
  TextColumn get senderId => text()();
  TextColumn get receiverId => text()();
  TextColumn get content => text()();
  TextColumn get mediaUrl => text().nullable()();
  TextColumn get mediaType => text().nullable()();
  TextColumn get replyToMessageId => text().nullable()();
  TextColumn get reactionsJson => text().withDefault(const Constant('[]'))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedForEveryone =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isUrgent => boolean().withDefault(const Constant(false))();
  TextColumn get status => text().withDefault(const Constant('sent'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
