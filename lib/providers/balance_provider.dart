import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/entry.dart';
import 'entry_provider.dart';
import 'book_provider.dart';

final bookBalanceProvider = Provider<double>((ref) {
  final activeBook = ref.watch(bookProvider);
  if (activeBook == null) return 0.0;

  final entries = ref.watch(entryProvider);
  
  double total = activeBook.initialAmount;
  for (var entry in entries) {
    if (entry.type == EntryType.income) {
      total += entry.amount;
    } else {
      total -= entry.amount;
    }
  }
  
  return total;
});
