import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

enum ProfileType { personal, company }

class Profile {
  final String id;
  final String name;
  final ProfileType type;
  final String currencySymbol;
  final String currencyCode;

  Profile({
    String? id,
    required this.name,
    this.type = ProfileType.personal,
    this.currencySymbol = '\$',
    this.currencyCode = 'USD',
  }) : id = id ?? const Uuid().v4();
}

class ProfileAdapter extends TypeAdapter<Profile> {
  @override
  final int typeId = 2;

  @override
  Profile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Profile(
      id: fields[0] as String,
      name: fields[1] as String,
      type: ProfileType.values[fields[2] as int],
      currencySymbol: fields[3] as String? ?? '\$',
      currencyCode: fields[4] as String? ?? 'USD',
    );
  }

  @override
  void write(BinaryWriter writer, Profile obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type.index)
      ..writeByte(3)
      ..write(obj.currencySymbol)
      ..writeByte(4)
      ..write(obj.currencyCode);
  }
}
