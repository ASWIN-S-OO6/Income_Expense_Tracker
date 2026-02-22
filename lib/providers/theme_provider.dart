import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);

class ThemeNotifier extends Notifier<ThemeMode> {
  late final Box _settingsBox;

  @override
  ThemeMode build() {
    _settingsBox = Hive.box('settings');
    final storedTheme = _settingsBox.get('themeMode', defaultValue: ThemeMode.system.index);
    return ThemeMode.values[storedTheme];
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    _settingsBox.put('themeMode', mode.index);
  }
}
