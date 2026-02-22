import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';
import '../../../providers/book_provider.dart';
import '../../../providers/entry_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../widgets/sidebar/book_switcher_drawer.dart';
import '../onboarding/welcome_screen.dart';
import '../entry/add_entry_screen.dart';
import '../../widgets/charts/balance_line_chart.dart';
import '../../../data/models/entry.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/formatters.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBook = ref.watch(bookProvider);
    final activeProfile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(activeBook?.name ?? 'Wealthify'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          if (activeBook != null) ...[
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: 'Import CSV',
              onPressed: () => _importEntries(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Export as CSV',
              onPressed: () => _exportEntries(context, ref),
            ),
          ]
        ],
      ),
      drawer: const BookSwitcherDrawer(),
      body: SafeArea(
        child: activeProfile == null
            ? const WelcomeScreen()
            : (activeBook == null
                ? const _EmptyStateWidget()
                : const _DashboardOverview()),
      ),
      floatingActionButton: activeBook == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddEntryScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Entry'),
            ),
    );
  }

  Future<void> _exportEntries(BuildContext context, WidgetRef ref) async {
    try {
      final entries = ref.read(entryProvider);
      final activeBook = ref.read(bookProvider);
      
      if (entries.isEmpty || activeBook == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No entries to export.')));
        return;
      }

      final List<List<dynamic>> rows = [];
      rows.add(["Date", "Type", "Category", "Payee/Payer", "Amount", "Notes"]);

      for (var e in entries) {
        final date = DateFormat('yyyy-MM-dd HH:mm').format(e.timestamp);
        final type = e.type == EntryType.income ? "Income" : "Expense";
        rows.add([
          date,
          type,
          e.category,
          e.payeeOrPayer,
          e.amount,
          e.notes ?? "",
        ]);
      }

      final String csvData = const ListToCsvConverter().convert(rows);

      final directory = await getTemporaryDirectory();
      final String filePath = '${directory.path}/Wealthify_${activeBook.name.replaceAll(' ', '_')}_Export.csv';
      final File file = File(filePath);
      await file.writeAsString(csvData);

      final xFile = XFile(filePath, mimeType: 'text/csv');
      await Share.shareXFiles([xFile], text: 'Exported entries from Expense Tracker');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export: $e')));
      }
    }
  }

  Future<void> _importEntries(BuildContext context, WidgetRef ref) async {
    try {
      final activeBook = ref.read(bookProvider);
      if (activeBook == null) return;

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final extension = result.files.single.extension?.toLowerCase();
      
      List<List<dynamic>> rows = [];

      if (extension == 'csv') {
        final csvString = await file.readAsString();
        rows = const CsvToListConverter().convert(csvString);
      } else if (extension == 'xlsx') {
        final bytes = await file.readAsBytes();
        var excel = Excel.decodeBytes(bytes);
        for (var table in excel.tables.keys) {
          final sheet = excel.tables[table];
          if (sheet != null) {
            for (var row in sheet.rows) {
              rows.add(row.map((e) => e?.value?.toString() ?? '').toList());
            }
          }
        }
      }

      if (rows.length <= 1) { // Only header or empty
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File is empty or invalid.')));
        return;
      }

      int addedCount = 0;
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue; // Skip totally empty rows

        try {
          final dateStr = row.isNotEmpty ? row[0].toString().trim() : '';
          final typeStr = row.length > 1 ? row[1].toString().trim() : '';
          final categoryStr = row.length > 2 ? row[2].toString().trim() : '-';
          final payeeStr = row.length > 3 ? row[3].toString().trim() : 'Unknown';
          final amountStr = row.length > 4 ? row[4].toString().trim() : '0';
          final notesStr = row.length > 5 ? row[5].toString().trim() : '';

          DateTime timestamp;
          try {
            timestamp = DateFormat('yyyy-MM-dd HH:mm').parse(dateStr);
          } catch (_) {
            try {
              timestamp = DateTime.parse(dateStr);
            } catch (_) {
              if (dateStr.isNotEmpty) {
                 // Try M/d/yy format typical of some excels
                 try {
                   timestamp = DateFormat.yMd().parse(dateStr);
                 } catch (_) {
                   timestamp = DateTime.now();
                 }
              } else {
                timestamp = DateTime.now();
              }
            }
          }

          final EntryType type = typeStr.toLowerCase().contains('income') ? EntryType.income : EntryType.expense;
          final amount = double.tryParse(amountStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

          if (amount <= 0) continue;

          final newEntry = Entry(
            id: const Uuid().v4(),
            bookId: activeBook.id,
            type: type,
            amount: amount,
            category: categoryStr,
            payeeOrPayer: payeeStr.isEmpty ? 'Unknown' : payeeStr,
            timestamp: timestamp,
            notes: notesStr,
          );

          ref.read(entryProvider.notifier).addEntry(newEntry);
          addedCount++;
        } catch (e) {
          // Skip invalid rows continuously
          debugPrint('Skipped bad CSV row: $e');
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully imported $addedCount entries.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to import: $e')));
      }
    }
  }
}

class _EmptyStateWidget extends ConsumerWidget {
  const _EmptyStateWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_outlined, size: 80, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 32),
            Text(
              "No Active Workspace",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Text(
              "Start tracking your expenses by creating a book for your personal or company finances.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).hintColor,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                final scaffoldState = Scaffold.of(context);
                if (scaffoldState.hasDrawer) {
                  scaffoldState.openDrawer();
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
              ),
              icon: const Icon(Icons.add_box_outlined),
              label: const Text("Create First Book"),
            )
          ],
        ),
      ),
    );
  }
}

class _DashboardOverview extends ConsumerWidget {
  const _DashboardOverview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entryProvider);
    final activeBook = ref.watch(bookProvider);
    final profile = ref.watch(profileProvider);
    final symbol = profile?.currencySymbol ?? '\$';

    double totalIncome = 0;
    double totalExpense = 0;
    for (var e in entries) {
      if (e.type == EntryType.income) {
        totalIncome += e.amount;
      } else {
        totalExpense += e.amount;
      }
    }
    
    final initialAmount = activeBook?.initialAmount ?? 0.0;
    final remaining = initialAmount + totalIncome - totalExpense;

    return CustomScrollView(
      physics: entries.isEmpty ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryLight,
                    AppColors.primaryLight.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryLight.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "REMAINING BALANCE",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    Formatters.formatCurrency(remaining, symbol: symbol),
                    style: TextStyle(
                      color: remaining >= 0 ? Colors.white : AppColors.expenseColor,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: _BalanceStat(title: "INITIAL", amount: initialAmount, symbol: symbol, color: Colors.white.withValues(alpha: 0.9))),
                      Expanded(child: _BalanceStat(title: "INCOME", amount: totalIncome, symbol: symbol, color: const Color(0xFF81C784))),
                      Expanded(child: _BalanceStat(title: "EXPENSES", amount: totalExpense, symbol: symbol, color: const Color(0xFFE57373))),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: BalanceLineChart(
              entries: entries, 
              currencySymbol: symbol,
              initialAmount: initialAmount,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Text(
              "Recent Activity",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        if (entries.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: Text("No entries yet. Tap + to add one!"),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 80), // Padding for FAB
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entry = entries[index];
                  return _EntryListTile(entry: entry, symbol: symbol);
                },
                childCount: entries.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _EntryListTile extends ConsumerWidget {
  final Entry entry;
  final String symbol;

  const _EntryListTile({required this.entry, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = entry.type == EntryType.income;
    final color = isIncome ? AppColors.incomeColor : AppColors.expenseColor;
    final bgColor = isIncome ? AppColors.incomeColor.withValues(alpha: 0.1) : AppColors.expenseColor.withValues(alpha: 0.1);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onLongPress: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   const SizedBox(height: 12),
                   Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                   const SizedBox(height: 24),
                   ListTile(
                     leading: const Icon(Icons.edit_outlined),
                     title: const Text('Edit Entry'),
                     onTap: () {
                       Navigator.pop(ctx);
                       Navigator.push(context, MaterialPageRoute(builder: (_) => AddEntryScreen(existingEntry: entry)));
                     },
                   ),
                   ListTile(
                     leading: const Icon(Icons.delete_outline, color: Colors.red),
                     title: const Text('Delete Entry', style: TextStyle(color: Colors.red)),
                     onTap: () {
                       ref.read(entryProvider.notifier).deleteEntry(entry.id);
                       Navigator.pop(ctx);
                     },
                   ),
                   const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            isIncome ? Icons.transit_enterexit : Icons.call_made,
            color: color,
          ),
        ),
        title: Text(
          entry.payeeOrPayer,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            "${entry.category} • ${Formatters.formatDate(entry.timestamp)}",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
        trailing: Text(
          "${isIncome ? '+' : '-'}${Formatters.formatCurrency(entry.amount, symbol: symbol)}",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final String title;
  final double amount;
  final String symbol;
  final Color color;

  const _BalanceStat({required this.title, required this.amount, required this.symbol, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        Text(
          Formatters.formatCurrency(amount, symbol: symbol),
          style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
