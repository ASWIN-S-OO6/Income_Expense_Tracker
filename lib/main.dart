import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'core/theme/app_theme.dart';
import 'data/services/local_storage.dart';
import 'providers/profile_provider.dart';
import 'ui/screens/home/home_screen.dart';
import 'ui/screens/entry/add_entry_screen.dart';
import 'providers/theme_provider.dart';
import 'data/models/entry.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Make status and navigation bars transparent
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Initialize Hive and DB
  final localStorage = LocalStorageService();
  await localStorage.init();

  // Initialize HomeWidget
  await HomeWidget.setAppGroupId('expense_tracker_group');
  
  runApp(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(localStorage),
      ],
      child: const ExpenseTrackerApp(),
    ),
  );
}

class ExpenseTrackerApp extends ConsumerStatefulWidget {
  const ExpenseTrackerApp({super.key});

  @override
  ConsumerState<ExpenseTrackerApp> createState() => _ExpenseTrackerAppState();
}

class _ExpenseTrackerAppState extends ConsumerState<ExpenseTrackerApp> {
  @override
  void initState() {
    super.initState();
    HomeWidget.widgetClicked.listen((Uri? uri) => _handleWidgetRoute(uri));
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetRoute);
  }

  void _handleWidgetRoute(Uri? uri) {
    if (uri != null && uri.host == 'add') {
      final typeStr = uri.queryParameters['type'];
      final type = typeStr == 'income' ? EntryType.income : EntryType.expense;
      
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => AddEntryScreen(initialType: type),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      navigatorKey: navigatorKey,
      home: const HomeScreen(),
    );
  }
}
