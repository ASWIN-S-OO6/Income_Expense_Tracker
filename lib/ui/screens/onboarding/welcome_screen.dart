import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/profile.dart';
import '../../../providers/profile_provider.dart';
import '../../../core/constants/colors.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _nameController = TextEditingController();
  ProfileType _selectedType = ProfileType.personal;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _createProfile() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      ref.read(profileProvider.notifier).createProfile(name, _selectedType);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet, size: 48, color: AppColors.primaryLight),
                ),
                const SizedBox(height: 32),
                const SizedBox(height: 32),
                Text(
                  "Welcome to Expense Tracker",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  "Let's get started by creating your first profile. You can manage personal and business finances easily.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600, height: 1.5),
                ),
                const SizedBox(height: 48),
                
                // Form
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: "Profile Name",
                          hintText: "e.g., Personal, Acme Corp",
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _createProfile(),
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<ProfileType>(
                        initialValue: _selectedType,
                        decoration: InputDecoration(
                          labelText: "Account Type",
                          prefixIcon: const Icon(Icons.category_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryLight),
                        borderRadius: BorderRadius.circular(16),
                        alignment: Alignment.bottomCenter,
                        menuMaxHeight: 200, // Constrain height so it drops downward and doesn't cover input
                        items: const [
                          DropdownMenuItem(value: ProfileType.personal, child: Text('Personal')),
                          DropdownMenuItem(value: ProfileType.company, child: Text('Business / Company')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedType = val);
                        },
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _createProfile,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("Get Started", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
