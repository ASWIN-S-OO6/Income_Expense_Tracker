import 'package:hive_flutter/hive_flutter.dart';
import '../models/entry.dart';
import '../models/book.dart';
import '../models/profile.dart';

class LocalStorageService {
  static const String profilesBoxName = 'profilesBox';
  static const String booksBoxName = 'booksBox';
  static const String entriesBoxName = 'entriesBox';

  Future<void> init() async {
    await Hive.initFlutter();
    
    // Register Adapters
    Hive.registerAdapter(EntryAdapter());
    Hive.registerAdapter(BookAdapter());
    Hive.registerAdapter(ProfileAdapter());

    // Open Boxes
    await Hive.openBox<Profile>(profilesBoxName);
    await Hive.openBox<Book>(booksBoxName);
    await Hive.openBox<Entry>(entriesBoxName);
    await Hive.openBox('settings');

    // (Intentionally not creating a default profile to force Welcome Screen flow)
  }

  Box<Profile> get profilesBox => Hive.box<Profile>(profilesBoxName);
  Box<Book> get booksBox => Hive.box<Book>(booksBoxName);
  Box<Entry> get entriesBox => Hive.box<Entry>(entriesBoxName);
}
