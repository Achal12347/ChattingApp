import 'package:drift/drift.dart';

class Messages extends Table {
  TextColumn get id => text()(); // local message ID (uuid)
  TextColumn get chatId => text()(); // userId or groupId
  TextColumn get senderId => text()();
  TextColumn get receiverId => text()();
  TextColumn get content => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isUrgent => boolean().withDefault(const Constant(false))();
  TextColumn get status => text().withDefault(const Constant('sent'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
