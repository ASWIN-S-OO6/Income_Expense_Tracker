import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:currency_picker/currency_picker.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/book_provider.dart';
import '../../../data/models/profile.dart';
import '../../../data/models/book.dart';
import '../../../core/constants/colors.dart';
import '../../screens/settings/settings_screen.dart';

class BookSwitcherDrawer extends ConsumerWidget {
  const BookSwitcherDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProfile = ref.watch(profileProvider);
    final allBooks = ref.watch(allBooksProvider);
    final activeBook = ref.watch(bookProvider);

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // Top Section: Profile Switcher (InkWell to open bottom sheet)
            InkWell(
              onTap: () => _showProfileSelector(context, ref),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "CURRENT PROFILE",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primaryLight.withValues(alpha: 0.1),
                          child: Text(
                            activeProfile?.name[0].toUpperCase() ?? '?', 
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryLight)
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            activeProfile?.name ?? 'No Profile',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                        const Icon(Icons.unfold_more, color: AppColors.primaryLight),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Middle Section: List of Books
            Padding(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 32.0, bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "YOUR WORKSPACE",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w800, color: Colors.grey.shade500),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, size: 20),
                    color: Colors.grey.shade500,
                    onPressed: () {
                      Navigator.pop(context); // Close Drawer
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                  )
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: allBooks.length,
                itemBuilder: (context, index) {
                  final book = allBooks[index];
                  final isActive = activeBook?.id == book.id;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primaryLight.withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      leading: Icon(
                        book.isPinned ? Icons.push_pin : (isActive ? Icons.folder_open : Icons.folder),
                        color: isActive || book.isPinned ? AppColors.primaryLight : Colors.grey.shade400,
                      ),
                      title: Text(
                        book.name,
                        style: TextStyle(
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                          color: isActive ? AppColors.primaryLight : null,
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) => _handleBookAction(context, ref, value, book),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'pin',
                            child: Row(children: [
                              Icon(book.isPinned ? Icons.push_pin_outlined : Icons.push_pin, size: 20), 
                              const SizedBox(width: 8), 
                              Text(book.isPinned ? 'Unpin' : 'Pin to top')
                            ]),
                          ),
                          const PopupMenuItem(
                            value: 'rename',
                            child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Rename')]),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))]),
                          ),
                        ],
                      ),
                      onTap: () {
                        ref.read(bookProvider.notifier).setActiveBook(book);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
            
            const Divider(height: 1),
            
            // Bottom Section: Create New Book & Profile Settings
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      _showCreateBookDialog(context, ref);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text("Create New Workspace"),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      showCurrencyPicker(
                        context: context,
                        showFlag: true,
                        showCurrencyName: true,
                        showCurrencyCode: true,
                        onSelect: (Currency currency) {
                          ref.read(profileProvider.notifier).updateCurrency(
                            currency.symbol, 
                            currency.code
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Currency updated to ${currency.name} (${currency.symbol})')),
                          );
                        },
                      );
                    },
                    icon: Icon(Icons.language, color: Colors.grey.shade600),
                    label: Text("Change Currency", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleBookAction(BuildContext context, WidgetRef ref, String action, Book book) {
    if (action == 'pin') {
      ref.read(bookProvider.notifier).togglePin(book.id);
    } else if (action == 'rename') {
      _showRenameBookDialog(context, ref, book);
    } else if (action == 'delete') {
      _showDeleteBookDialog(context, ref, book);
    }
  }

  void _showDeleteBookDialog(BuildContext context, WidgetRef ref, Book book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workspace?'),
        content: Text('Are you sure you want to delete "${book.name}"? All entries inside will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(bookProvider.notifier).deleteBook(book.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          )
        ],
      )
    );
  }

  void _showRenameBookDialog(BuildContext context, WidgetRef ref, Book book) {
    final nameController = TextEditingController(text: book.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Workspace'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'New Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                ref.read(bookProvider.notifier).editBookName(book.id, nameController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          )
        ],
      )
    );
  }

  void _showProfileSelector(BuildContext context, WidgetRef ref) {
    final profiles = ref.read(profileProvider.notifier).getAllProfiles();
    final activeProfile = ref.read(profileProvider);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(32),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                    ),
                    const SizedBox(height: 24),
                    const Text("Switch Profile", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ...profiles.map((p) {
                      final isActive = p.id == activeProfile?.id;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isActive ? AppColors.primaryLight : Colors.grey.shade200,
                          child: Text(p.name[0].toUpperCase(), style: TextStyle(color: isActive ? Colors.white : Colors.black)),
                        ),
                        title: Text(p.name, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                        trailing: isActive ? const Icon(Icons.check, color: AppColors.primaryLight) : null,
                        onTap: () {
                          ref.read(profileProvider.notifier).setActiveProfile(p);
                          Navigator.pop(context);
                        },
                      );
                    }),
                    const Divider(),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.transparent,
                        child: Icon(Icons.add),
                      ),
                      title: const Text("Create Business / New Profile", style: TextStyle(fontWeight: FontWeight.bold)),
                      onTap: () {
                        Navigator.pop(context);
                        _showCreateProfileDialog(context, ref);
                      },
                    ),
                    const SizedBox(height: 16),
                  ]
                ),
              )
            )
          )
        );
      }
    );
  }

  void _showCreateProfileDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    ProfileType selectedType = ProfileType.personal;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text("Create Profile", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: "Profile Name", 
                      hintText: "e.g., Acme Corp",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<ProfileType>(
                    initialValue: selectedType,
                    decoration: InputDecoration(
                      labelText: "Account Type",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryLight),
                    items: const [
                      DropdownMenuItem(value: ProfileType.personal, child: Text('Personal')),
                      DropdownMenuItem(value: ProfileType.company, child: Text('Business / Company')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => selectedType = v);
                    },
                    borderRadius: BorderRadius.circular(16),
                  )
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isNotEmpty) {
                      await ref.read(profileProvider.notifier).createProfile(nameController.text.trim(), selectedType);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text("Create"),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showCreateBookDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("New Workspace", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Workspace Name",
                  hintText: "e.g., Q1 Expenses",
                  prefixIcon: const Icon(Icons.book_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: "Initial Balance",
                  hintText: "0.00",
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final balance = double.tryParse(amountController.text) ?? 0.0;
                
                if (name.isNotEmpty) {
                  ref.read(bookProvider.notifier).createBook(name, initialAmount: balance);
                  Navigator.pop(context); // close dialog
                  Navigator.pop(context); // close drawer
                }
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Create Workspace"),
            ),
          ],
        );
      },
    );
  }
}
