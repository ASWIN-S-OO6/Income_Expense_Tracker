import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/entry.dart';
import '../../../providers/entry_provider.dart';
import '../../../providers/book_provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/formatters.dart';

class AddEntryScreen extends ConsumerStatefulWidget {
  final Entry? existingEntry;
  final EntryType? initialType;

  const AddEntryScreen({super.key, this.existingEntry, this.initialType});

  @override
  ConsumerState<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends ConsumerState<AddEntryScreen> {
  EntryType _selectedType = EntryType.expense;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _payeeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _customCategoryController = TextEditingController();
  
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  final List<String> _expenseCategories = ['Food', 'Transport', 'Rent', 'Utilities', 'Shopping', 'Health', 'Other'];
  final List<String> _incomeCategories = ['Salary', 'Freelance', 'Investments', 'Gifts', 'Other'];

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _selectedType = widget.initialType!;
    }
    
    if (widget.existingEntry != null) {
      final e = widget.existingEntry!;
      _selectedType = e.type;
      _amountController.text = e.amount.toString();
      _payeeController.text = e.payeeOrPayer;
      _notesController.text = e.notes;
      _selectedDate = e.timestamp;
      _selectedTime = TimeOfDay.fromDateTime(e.timestamp);

      final isKnownCategory = _expenseCategories.contains(e.category) || _incomeCategories.contains(e.category);
      if (e.category == '-') {
        _selectedCategory = null;
      } else if (isKnownCategory) {
        _selectedCategory = e.category;
      } else {
        _selectedCategory = 'Other';
        _customCategoryController.text = e.category;
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _payeeController.dispose();
    _notesController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  void _saveEntry() {
    final amountParsed = double.tryParse(_amountController.text);
    if (amountParsed == null || amountParsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final activeBook = ref.read(bookProvider);
    if (activeBook == null) return;

    final timestamp = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    String finalCategory = '-';
    if (_selectedCategory == 'Other') {
      final custom = _customCategoryController.text.trim();
      if (custom.isNotEmpty) {
        finalCategory = custom;
      }
    } else if (_selectedCategory != null) {
      finalCategory = _selectedCategory!;
    }

    final newEntry = Entry(
      id: widget.existingEntry?.id,
      bookId: activeBook.id,
      type: _selectedType,
      amount: amountParsed,
      payeeOrPayer: _payeeController.text.isEmpty ? 'Unknown' : _payeeController.text,
      category: finalCategory,
      timestamp: timestamp,
      notes: _notesController.text,
    );

    if (widget.existingEntry != null) {
      ref.read(entryProvider.notifier).updateEntry(newEntry);
    } else {
      ref.read(entryProvider.notifier).addEntry(newEntry);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categories = _selectedType == EntryType.expense ? _expenseCategories : _incomeCategories;
    if (_selectedCategory != null && !categories.contains(_selectedCategory)) {
      _selectedCategory = null;
    }

    final isExpense = _selectedType == EntryType.expense;
    final activeColor = isExpense ? AppColors.expenseColor : AppColors.incomeColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingEntry != null ? 'Edit Entry' : 'Add New Entry'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Toggle
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedType = EntryType.expense),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: isExpense ? AppColors.expenseColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "Expense",
                            style: TextStyle(
                              color: isExpense ? Colors.white : Colors.grey.shade600,
                              fontWeight: isExpense ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedType = EntryType.income),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: !isExpense ? AppColors.incomeColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "Income",
                            style: TextStyle(
                              color: !isExpense ? Colors.white : Colors.grey.shade600,
                              fontWeight: !isExpense ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              
              // Amount
              Center(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: widget.existingEntry == null,
                  style: TextStyle(
                    fontSize: 56, 
                    fontWeight: FontWeight.w900,
                    color: activeColor,
                    letterSpacing: -1,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(color: activeColor.withValues(alpha: 0.3)),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // Horizontal Scrolling Chips for Category
              Text("Category (Optional)", style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
              const SizedBox(height: 12),
              SizedBox(
                height: 45,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = _selectedCategory == cat;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_selectedCategory == cat) {
                            _selectedCategory = null; // Unselectable toggle
                          } else {
                            _selectedCategory = cat;
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? activeColor.withValues(alpha: 0.1) : Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected ? activeColor : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? activeColor : Colors.grey.shade700,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_selectedCategory == 'Other') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _customCategoryController,
                  decoration: InputDecoration(
                    labelText: 'Custom Category Name',
                    prefixIcon: Icon(Icons.category_outlined, color: activeColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: activeColor, width: 2),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // Payee/Payer
              TextField(
                controller: _payeeController,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: isExpense ? 'Who is this for?' : 'Who is this from?',
                  prefixIcon: Icon(Icons.person_outline, color: activeColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: activeColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Notes Space
              TextField(
                controller: _notesController,
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  prefixIcon: Icon(Icons.notes_outlined, color: activeColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: activeColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Date & Time
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(primary: activeColor),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (date != null) {
                          setState(() => _selectedDate = date);
                        }
                      },
                      child: IgnorePointer(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Date',
                            prefixIcon: Icon(Icons.calendar_today_outlined, color: activeColor, size: 20),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          controller: TextEditingController(text: Formatters.formatDate(_selectedDate)),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(primary: activeColor),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (time != null) {
                          setState(() => _selectedTime = time);
                        }
                      },
                      child: IgnorePointer(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Time',
                            prefixIcon: Icon(Icons.access_time_outlined, color: activeColor, size: 20),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          controller: TextEditingController(text: _selectedTime.format(context)),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // Save Button
              ElevatedButton(
                onPressed: _saveEntry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeColor,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 8,
                  shadowColor: activeColor.withValues(alpha: 0.4),
                ),
                child: const Text('Save Entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
