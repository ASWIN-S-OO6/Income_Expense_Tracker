import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              "APPEARANCE",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 5))
                ]
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text("Light Mode", style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: themeMode == ThemeMode.light ? const Icon(Icons.check, color: Colors.blue) : null,
                    onTap: () => ref.read(themeProvider.notifier).setThemeMode(ThemeMode.light),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text("Dark Mode", style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: themeMode == ThemeMode.dark ? const Icon(Icons.check, color: Colors.blue) : null,
                    onTap: () => ref.read(themeProvider.notifier).setThemeMode(ThemeMode.dark),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text("System Default", style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: themeMode == ThemeMode.system ? const Icon(Icons.check, color: Colors.blue) : null,
                    onTap: () => ref.read(themeProvider.notifier).setThemeMode(ThemeMode.system),
                  ),
                ],
              ),
            )
          ],
        ),
      )
    );
  }
}
