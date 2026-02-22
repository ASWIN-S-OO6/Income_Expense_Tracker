import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

class Book {
  final String id;
  final String profileId;
  final String name; 
  final DateTime createdAt;
  final double initialAmount;
  final bool isPinned;

  Book({
    String? id,
    required this.profileId,
    required this.name,
    required this.createdAt,
    this.initialAmount = 0.0,
    this.isPinned = false,
  }) : id = id ?? const Uuid().v4();
}

class BookAdapter extends TypeAdapter<Book> {
  @override
  final int typeId = 1;

  @override
  Book read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Book(
      id: fields[0] as String,
      profileId: fields[1] as String,
      name: fields[2] as String,
      createdAt: fields[3] as DateTime,
      initialAmount: fields[4] as double? ?? 0.0,
      isPinned: fields[5] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, Book obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.profileId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.initialAmount)
      ..writeByte(5)
      ..write(obj.isPinned);
  }
}
