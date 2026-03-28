import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
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

// ─────────────────────────────────────────────────────────────────────────────
// XLSX cell-value helper — fixes the "TextCellValue(Hello)" bug
// ─────────────────────────────────────────────────────────────────────────────
String _cellToString(Data? cell) {
  if (cell == null) return '';
  final v = cell.value;
  if (v == null) return '';
  if (v is TextCellValue) return v.value.text ?? '';
  if (v is IntCellValue) return v.value.toString();
  if (v is DoubleCellValue) return v.value.toString();
  if (v is BoolCellValue) return v.value.toString();
  if (v is DateCellValue) {
    return '${v.year}-${v.month.toString().padLeft(2, '0')}-'
        '${v.day.toString().padLeft(2, '0')} 00:00';
  }
  if (v is DateTimeCellValue) {
    return '${v.year}-${v.month.toString().padLeft(2, '0')}-'
        '${v.day.toString().padLeft(2, '0')} '
        '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
  }
  return v.toString();
}

// Multi-format date parser
DateTime _parseDate(String s) {
  final clean = s.trim();
  if (clean.isEmpty) return DateTime.now();
  final formats = [
    DateFormat('yyyy-MM-dd HH:mm'),
    DateFormat('yyyy-MM-dd'),
    DateFormat('MM/dd/yyyy'),
    DateFormat('M/d/yyyy'),
    DateFormat('d/M/yyyy'),
    DateFormat('dd-MM-yyyy'),
  ];
  for (final fmt in formats) {
    try {
      return fmt.parse(clean);
    } catch (_) {}
  }
  try {
    return DateTime.parse(clean);
  } catch (_) {}
  return DateTime.now();
}

// ─────────────────────────────────────────────────────────────────────────────
// Home Screen
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBook = ref.watch(bookProvider);
    final activeProfile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(activeBook?.name ?? 'Expense Tracker'),
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
              tooltip: 'Import CSV / XLSX',
              onPressed: () => _importEntries(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Export as CSV',
              onPressed: () => _exportEntries(context, ref),
            ),
          ],
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

  // ── Export ──────────────────────────────────────────────────────────────────
  Future<void> _exportEntries(BuildContext context, WidgetRef ref) async {
    try {
      final entries = ref.read(entryProvider);
      final activeBook = ref.read(bookProvider);

      if (entries.isEmpty || activeBook == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No entries to export.')));
        }
        return;
      }

      final List<List<dynamic>> rows = [
        ['Date', 'Type', 'Category', 'Payee/Payer', 'Amount', 'Notes']
      ];
      for (var e in entries) {
        rows.add([
          DateFormat('yyyy-MM-dd HH:mm').format(e.timestamp),
          e.type == EntryType.income ? 'Income' : 'Expense',
          e.category,
          e.payeeOrPayer,
          e.amount,
          e.notes ?? '',
        ]);
      }

      final csvData = const ListToCsvConverter().convert(rows);
      final directory = await getTemporaryDirectory();
      final safeName = activeBook.name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final filePath = '${directory.path}/ExpenseTracker_${safeName}_Export.csv';
      await File(filePath).writeAsString(csvData);

      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'text/csv')],
        text: 'Expense Tracker export — ${activeBook.name}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  // ── Import ──────────────────────────────────────────────────────────────────
  Future<void> _importEntries(BuildContext context, WidgetRef ref) async {
    try {
      final activeBook = ref.read(bookProvider);
      if (activeBook == null) return;

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
      );
      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final ext = result.files.single.extension?.toLowerCase() ?? '';

      List<List<String>> rows = [];

      if (ext == 'csv') {
        // CSV path
        final rawString = await file.readAsString();
        final parsed = const CsvToListConverter(eol: '\n').convert(rawString);
        rows = parsed
            .map((row) => row.map((cell) => cell.toString().trim()).toList())
            .toList();
      } else {
        // XLSX / XLS path — use typed cell extractor
        final bytes = await file.readAsBytes();
        final excel = Excel.decodeBytes(bytes);
        for (final tableName in excel.tables.keys) {
          final sheet = excel.tables[tableName];
          if (sheet == null) continue;
          for (final row in sheet.rows) {
            final stringRow = row.map(_cellToString).toList();
            if (stringRow.any((c) => c.isNotEmpty)) {
              rows.add(stringRow);
            }
          }
          break; // Only first sheet
        }
      }

      if (rows.length <= 1) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File is empty or unrecognised.')));
        }
        return;
      }

      // Detect if first row is a header (contains "type" or "amount")
      final header = rows[0].map((c) => c.toLowerCase()).toList();
      final startRow =
          (header.contains('type') || header.contains('amount')) ? 1 : 0;

      int added = 0;
      for (int i = startRow; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || row.every((c) => c.isEmpty)) continue;
        try {
          final dateStr = row.isNotEmpty ? row[0] : '';
          final typeStr = row.length > 1 ? row[1] : '';
          final categoryStr = row.length > 2 && row[2].isNotEmpty ? row[2] : '-';
          final payeeStr = row.length > 3 && row[3].isNotEmpty ? row[3] : 'Unknown';
          final amountStr = row.length > 4 ? row[4] : '0';
          final notesStr = row.length > 5 ? row[5] : '';

          final timestamp = _parseDate(dateStr);
          final type = typeStr.toLowerCase().contains('income')
              ? EntryType.income
              : EntryType.expense;
          // Strip all non-numeric except dot
          final amount =
              double.tryParse(amountStr.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                  0.0;
          if (amount <= 0) continue;

          ref.read(entryProvider.notifier).addEntry(Entry(
                id: const Uuid().v4(),
                bookId: activeBook.id,
                type: type,
                amount: amount,
                category: categoryStr,
                payeeOrPayer: payeeStr,
                timestamp: timestamp,
                notes: notesStr,
              ));
          added++;
        } catch (e) {
          debugPrint('Skipped bad row $i: $e');
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported $added entries successfully.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────
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
              child: const Icon(Icons.account_balance_wallet_outlined,
                  size: 80, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 32),
            Text(
              'No Active Workspace',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Text(
              'Start tracking your expenses by creating a book for your personal or company finances.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).hintColor,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                final s = Scaffold.of(context);
                if (s.hasDrawer) s.openDrawer();
              },
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60)),
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Create First Book'),
            )
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard with search, insights, monthly view
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardOverview extends ConsumerStatefulWidget {
  const _DashboardOverview();

  @override
  ConsumerState<_DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends ConsumerState<_DashboardOverview> {
  String _searchQuery = '';
  bool _showSearch = false;
  bool _showFilters = false;
  bool _groupByMonth = false;
  double? _minAmount;
  double? _maxAmount;
  DateTimeRange? _dateRange;
  String? _categoryFilter; // set when user taps a top-spending row
  final _searchController = TextEditingController();
  final _minAmountCtrl = TextEditingController();
  final _maxAmountCtrl = TextEditingController();

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _minAmount = null;
      _maxAmount = null;
      _dateRange = null;
      _categoryFilter = null;
      _searchController.clear();
      _minAmountCtrl.clear();
      _maxAmountCtrl.clear();
    });
  }

  bool get _hasActiveFilter =>
      _searchQuery.isNotEmpty ||
      _minAmount != null ||
      _maxAmount != null ||
      _dateRange != null ||
      _categoryFilter != null;

  @override
  void dispose() {
    _searchController.dispose();
    _minAmountCtrl.dispose();
    _maxAmountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries    = ref.watch(entryProvider);
    final activeBook = ref.watch(bookProvider);
    final profile    = ref.watch(profileProvider);
    final symbol     = profile?.currencySymbol ?? '\$';

    double totalIncome = 0, totalExpense = 0;
    for (var e in entries) {
      if (e.type == EntryType.income) totalIncome += e.amount;
      else totalExpense += e.amount;
    }
    final initialAmount = activeBook?.initialAmount ?? 0.0;
    final remaining     = initialAmount + totalIncome - totalExpense;

    // ── Apply all filters ──
    final filteredEntries = entries.where((e) {
      // Text search: payee, category, notes, AND amount (toString match)
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchText = e.payeeOrPayer.toLowerCase().contains(q) ||
            e.category.toLowerCase().contains(q) ||
            e.notes.toLowerCase().contains(q) ||
            e.amount.toString().contains(q);
        if (!matchText) return false;
      }
      // Category filter from insights tap
      if (_categoryFilter != null && e.category != _categoryFilter) return false;
      // Amount range
      if (_minAmount != null && e.amount < _minAmount!) return false;
      if (_maxAmount != null && e.amount > _maxAmount!) return false;
      // Date range
      if (_dateRange != null) {
        final d = e.timestamp;
        if (d.isBefore(_dateRange!.start) ||
            d.isAfter(_dateRange!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }
      return true;
    }).toList();

    // Build spending insights (top 3 expense categories)
    final Map<String, double> catSpend = {};
    for (var e in entries.where((e) => e.type == EntryType.expense)) {
      catSpend[e.category] = (catSpend[e.category] ?? 0) + e.amount;
    }
    final top3 = (catSpend.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .toList();

    return Column(
      children: [
        // ── Search bar (animated) ──
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: _showSearch ? 56 : 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _showSearch
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search payee, category, amount, notes…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _showSearch = false;
                        _searchQuery = '';
                        _searchController.clear();
                      }),
                    ),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // ── Advanced filter panel ──
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: _showFilters ? 110 : 0,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _minAmountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) =>
                          setState(() => _minAmount = double.tryParse(v)),
                      decoration: InputDecoration(
                        hintText: 'Min amount',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _maxAmountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) =>
                          setState(() => _maxAmount = double.tryParse(v)),
                      decoration: InputDecoration(
                        hintText: 'Max amount',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDateRange: _dateRange,
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() => _dateRange = picked);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10)),
                    icon: const Icon(Icons.date_range, size: 18),
                    label: Text(
                      _dateRange == null
                          ? 'Dates'
                          : '${DateFormat('d MMM').format(_dateRange!.start)}–${DateFormat('d MMM').format(_dateRange!.end)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ]),
                if (_categoryFilter != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Chip(
                      label: Text('Category: $_categoryFilter'),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () =>
                          setState(() => _categoryFilter = null),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ── Filter toolbar ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          child: Row(
            children: [
              if (_hasActiveFilter)
                TextButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.filter_alt_off, size: 16),
                  label: const Text('Clear', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.orange.shade700),
                ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.search,
                    color: _showSearch
                        ? AppColors.primaryLight
                        : Colors.grey.shade500),
                onPressed: () =>
                    setState(() => _showSearch = !_showSearch),
                tooltip: 'Text search',
              ),
              IconButton(
                icon: Icon(Icons.tune,
                    color: _showFilters
                        ? AppColors.primaryLight
                        : Colors.grey.shade500),
                onPressed: () =>
                    setState(() => _showFilters = !_showFilters),
                tooltip: 'Amount & date filters',
              ),
              IconButton(
                icon: Icon(
                  _groupByMonth
                      ? Icons.calendar_view_month
                      : Icons.view_list_rounded,
                  color: _groupByMonth
                      ? AppColors.primaryLight
                      : Colors.grey.shade500,
                ),
                onPressed: () =>
                    setState(() => _groupByMonth = !_groupByMonth),
                tooltip: _groupByMonth ? 'List view' : 'Group by month',
              ),
            ],
          ),
        ),

        Expanded(
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Balance card ──
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
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
                          'REMAINING BALANCE',
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
                            color: remaining >= 0
                                ? Colors.white
                                : AppColors.expenseColor,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: _BalanceStat(
                                    title: 'INITIAL',
                                    amount: initialAmount,
                                    symbol: symbol,
                                    color:
                                        Colors.white.withValues(alpha: 0.9))),
                            Expanded(
                                child: _BalanceStat(
                                    title: 'INCOME',
                                    amount: totalIncome,
                                    symbol: symbol,
                                    color: const Color(0xFF81C784))),
                            Expanded(
                                child: _BalanceStat(
                                    title: 'EXPENSES',
                                    amount: totalExpense,
                                    symbol: symbol,
                                    color: const Color(0xFFE57373))),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),

              // ── Chart ──
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

              // ── Spending Insights card (only when there are expenses) ──
              if (top3.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 4.0),
                    child: _SpendingInsightsCard(
                        top3: top3,
                        totalExpense: totalExpense,
                        symbol: symbol,
                        selectedCategory: _categoryFilter,
                        onCategoryTap: (cat) {
                          setState(() {
                            // Toggle: tap same category again to clear filter
                            _categoryFilter =
                                _categoryFilter == cat ? null : cat;
                            _showFilters = _categoryFilter != null;
                          });
                        }),
                  ),
                ),

              // ── Section header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _categoryFilter != null
                              ? 'Filtered: $_categoryFilter (${filteredEntries.length})'
                              : _hasActiveFilter
                                  ? 'Filtered Results (${filteredEntries.length})'
                                  : 'Recent Activity',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Entry list / grouped ──
              if (filteredEntries.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('No entries found.')),
                )
              else if (_groupByMonth)
                ..._buildMonthlyGrouped(filteredEntries, symbol, context)
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _EntryListTile(
                          entry: filteredEntries[i], symbol: symbol),
                      childCount: filteredEntries.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Monthly grouping helper
  List<Widget> _buildMonthlyGrouped(
      List<Entry> entries, String symbol, BuildContext context) {
    final Map<String, List<Entry>> groups = {};
    for (var e in entries) {
      final key = DateFormat('MMMM yyyy').format(e.timestamp);
      groups.putIfAbsent(key, () => []).add(e);
    }

    final result = <Widget>[];
    for (final month in groups.keys) {
      final monthEntries = groups[month]!;
      final income = monthEntries
          .where((e) => e.type == EntryType.income)
          .fold(0.0, (s, e) => s + e.amount);
      final expense = monthEntries
          .where((e) => e.type == EntryType.expense)
          .fold(0.0, (s, e) => s + e.amount);

      result.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  month,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryLight,
                      ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('+${Formatters.formatCurrency(income, symbol: symbol)}',
                      style: const TextStyle(
                          color: Color(0xFF81C784),
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  Text('-${Formatters.formatCurrency(expense, symbol: symbol)}',
                      style: const TextStyle(
                          color: Color(0xFFE57373),
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
        ),
      ));
      result.add(SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) =>
              _EntryListTile(entry: monthEntries[i], symbol: symbol),
          childCount: monthEntries.length,
        ),
      ));
    }
    result.add(const SliverToBoxAdapter(child: SizedBox(height: 100)));
    return result;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Spending Insights Card
// ─────────────────────────────────────────────────────────────────────────────
class _SpendingInsightsCard extends StatelessWidget {
  final List<MapEntry<String, double>> top3;
  final double totalExpense;
  final String symbol;
  final String? selectedCategory;
  final void Function(String category) onCategoryTap;

  const _SpendingInsightsCard({
    required this.top3,
    required this.totalExpense,
    required this.symbol,
    required this.onCategoryTap,
    this.selectedCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded,
                  color: AppColors.primaryLight, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Top Spending',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              Text('Tap to filter',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                      fontStyle: FontStyle.italic)),
            ],
          ),
          const SizedBox(height: 16),
          for (final entry in top3) ...[
            InkWell(
              onTap: () => onCategoryTap(entry.key),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                decoration: BoxDecoration(
                  color: selectedCategory == entry.key
                      ? AppColors.expenseColor.withValues(alpha: 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        entry.key,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: selectedCategory == entry.key
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: selectedCategory == entry.key
                                ? AppColors.expenseColor
                                : null),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: totalExpense > 0
                              ? entry.value / totalExpense
                              : 0,
                          minHeight: 8,
                          backgroundColor:
                              AppColors.expenseColor.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            selectedCategory == entry.key
                                ? AppColors.expenseColor
                                : AppColors.expenseColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Formatters.formatCurrency(entry.value, symbol: symbol),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: selectedCategory == entry.key
                              ? AppColors.expenseColor
                              : Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Entry List Tile
// ─────────────────────────────────────────────────────────────────────────────
class _EntryListTile extends ConsumerWidget {
  final Entry entry;
  final String symbol;

  const _EntryListTile({required this.entry, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = entry.type == EntryType.income;
    final color = isIncome ? AppColors.incomeColor : AppColors.expenseColor;
    final bgColor = isIncome
        ? AppColors.incomeColor.withValues(alpha: 0.1)
        : AppColors.expenseColor.withValues(alpha: 0.1);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: ListTile(
        onLongPress: () => _showActions(context, ref),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: bgColor, borderRadius: BorderRadius.circular(14)),
          child: Icon(
            isIncome ? Icons.south_west : Icons.north_east,
            color: color,
          ),
        ),
        title: Text(entry.payeeOrPayer,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Text(
            '${entry.category} • ${Formatters.formatDate(entry.timestamp)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'}${Formatters.formatCurrency(entry.amount, symbol: symbol)}',
          style: TextStyle(
              color: color, fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Entry'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            AddEntryScreen(existingEntry: entry)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Entry',
                  style: TextStyle(color: Colors.red)),
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Balance stat widget (inside the balance card)
// ─────────────────────────────────────────────────────────────────────────────
class _BalanceStat extends StatelessWidget {
  final String title;
  final double amount;
  final String symbol;
  final Color color;

  const _BalanceStat(
      {required this.title,
      required this.amount,
      required this.symbol,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(
          Formatters.formatCurrency(amount, symbol: symbol),
          style: TextStyle(
              color: color, fontSize: 14, fontWeight: FontWeight.w800),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
