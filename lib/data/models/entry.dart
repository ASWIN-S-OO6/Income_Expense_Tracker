import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

enum EntryType { income, expense }

class Entry {
  final String id;
  final String bookId;
  final EntryType type;
  final double amount;
  final String payeeOrPayer;
  final String category;
  final DateTime timestamp;
  final String notes;

  Entry({
    String? id,
    required this.bookId,
    required this.type,
    required this.amount,
    required this.payeeOrPayer,
    required this.category,
    required this.timestamp,
    this.notes = '',
  }) : id = id ?? const Uuid().v4();
}

class EntryAdapter extends TypeAdapter<Entry> {
  @override
  final int typeId = 0;

  @override
  Entry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Entry(
      id: fields[0] as String,
      bookId: fields[1] as String,
      type: EntryType.values[fields[2] as int],
      amount: fields[3] as double,
      payeeOrPayer: fields[4] as String,
      category: fields[5] as String,
      timestamp: fields[6] as DateTime,
      notes: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Entry obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bookId)
      ..writeByte(2)
      ..write(obj.type.index)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.payeeOrPayer)
      ..writeByte(5)
      ..write(obj.category)
      ..writeByte(6)
      ..write(obj.timestamp)
      ..writeByte(7)
      ..write(obj.notes);
  }
}
