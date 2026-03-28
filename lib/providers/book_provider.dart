import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/book.dart';
import 'profile_provider.dart';

class BookNotifier extends Notifier<Book?> {
  static const String _lastBookKeyPrefix = 'lastBookId_';

  @override
  Book? build() {
    final currentProfile = ref.watch(profileProvider);
    if (currentProfile == null) return null;

    final storage = ref.read(localStorageProvider);
    final allBooks = storage.booksBox.values
        .where((b) => b.profileId == currentProfile.id)
        .toList();

    if (allBooks.isEmpty) return null;

    // Try to restore the last-opened book for this profile
    final lastBookId = storage.settingsBox.get(
      '$_lastBookKeyPrefix${currentProfile.id}',
    );
    if (lastBookId != null) {
      try {
        return allBooks.firstWhere((b) => b.id == lastBookId);
      } catch (_) {
        // Book was deleted — fall through to default
      }
    }

    // Default: newest created book
    allBooks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return allBooks.first;
  }

  Future<void> _persistLastBook(Book book) async {
    final currentProfile = ref.read(profileProvider);
    if (currentProfile == null) return;
    await ref.read(localStorageProvider).settingsBox.put(
      '$_lastBookKeyPrefix${currentProfile.id}',
      book.id,
    );
  }

  void setActiveBook(Book book) {
    state = book;
    _persistLastBook(book);
  }

  List<Book> getBooksForCurrentProfile() {
    final currentProfile = ref.read(profileProvider);
    if (currentProfile == null) return [];
    return ref
        .read(localStorageProvider)
        .booksBox
        .values
        .where((b) => b.profileId == currentProfile.id)
        .toList();
  }

  Future<void> createBook(String name, {double initialAmount = 0.0}) async {
    final currentProfile = ref.read(profileProvider);
    if (currentProfile == null) return;

    final newBook = Book(
      profileId: currentProfile.id,
      name: name,
      createdAt: DateTime.now(),
      initialAmount: initialAmount,
    );
    await ref.read(localStorageProvider).booksBox.put(newBook.id, newBook);

    ref.invalidateSelf();
    state = newBook;
    await _persistLastBook(newBook);
  }

  Future<void> editBookName(String bookId, String newName) async {
    final box = ref.read(localStorageProvider).booksBox;
    final book = box.get(bookId);
    if (book != null) {
      final updatedBook = Book(
        id: book.id,
        profileId: book.profileId,
        name: newName,
        createdAt: book.createdAt,
        initialAmount: book.initialAmount,
        isPinned: book.isPinned,
      );
      await box.put(bookId, updatedBook);
      if (state?.id == bookId) {
        state = updatedBook;
      }
      ref.invalidateSelf();
    }
  }

  Future<void> togglePin(String bookId) async {
    final box = ref.read(localStorageProvider).booksBox;
    final book = box.get(bookId);
    if (book != null) {
      final updatedBook = Book(
        id: book.id,
        profileId: book.profileId,
        name: book.name,
        createdAt: book.createdAt,
        initialAmount: book.initialAmount,
        isPinned: !book.isPinned,
      );
      await box.put(bookId, updatedBook);
      if (state?.id == bookId) {
        state = updatedBook;
      }
      ref.invalidateSelf();
    }
  }

  Future<void> deleteBook(String bookId) async {
    final box = ref.read(localStorageProvider).booksBox;
    await box.delete(bookId);
    if (state?.id == bookId) {
      state = null;
    }
    ref.invalidateSelf();
  }
}

final bookProvider = NotifierProvider<BookNotifier, Book?>(() {
  return BookNotifier();
});

// Provider to watch all books for the current profile
final allBooksProvider = Provider<List<Book>>((ref) {
  ref.watch(bookProvider); // Watch active book just to trigger rebuilds on change
  final notifier = ref.read(bookProvider.notifier);
  final books = notifier.getBooksForCurrentProfile();

  // Sort: Pinned first, then by Creation Date (Newest first)
  books.sort((a, b) {
    if (a.isPinned && !b.isPinned) return -1;
    if (!a.isPinned && b.isPinned) return 1;
    return b.createdAt.compareTo(a.createdAt);
  });

  return books;
});
