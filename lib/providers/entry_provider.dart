import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/entry.dart';
import 'book_provider.dart';
import 'profile_provider.dart';

class EntryNotifier extends Notifier<List<Entry>> {
  @override
  List<Entry> build() {
    final activeBook = ref.watch(bookProvider);
    if (activeBook == null) {
      return [];
    }
    
    final storage = ref.read(localStorageProvider);
    final allEntries = storage.entriesBox.values
        .where((e) => e.bookId == activeBook.id)
        .toList();
    
    // Sort by timestamp descending
    allEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allEntries;
  }

  Future<void> addEntry(Entry entry) async {
    final storage = ref.read(localStorageProvider);
    await storage.entriesBox.put(entry.id, entry);
    ref.invalidateSelf(); // Refresh state
  }

  Future<void> updateEntry(Entry entry) async {
    final storage = ref.read(localStorageProvider);
    await storage.entriesBox.put(entry.id, entry);
    ref.invalidateSelf();
  }

  Future<void> deleteEntry(String id) async {
    final storage = ref.read(localStorageProvider);
    await storage.entriesBox.delete(id);
    ref.invalidateSelf();
  }
}

final entryProvider = NotifierProvider<EntryNotifier, List<Entry>>(() {
  return EntryNotifier();
});
