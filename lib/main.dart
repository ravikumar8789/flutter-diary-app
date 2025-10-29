import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/privacy_lock_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/pin_lock_screen.dart';
import 'services/connectivity_service.dart';
import 'services/app_lifecycle_service.dart';
import 'services/notification_service.dart';

/// App wrapper that handles privacy lock logic
class AppWrapper extends ConsumerWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privacyLockData = ref.watch(privacyLockProvider);

    // Determine the initial screen based on privacy lock status
    if (privacyLockData.isEnabled && !privacyLockData.isUnlocked) {
      // Privacy lock is enabled and app is locked
      return const PinLockScreen();
    } else {
      // Normal app flow
      return const SplashScreen();
    }
  }
}

// Global navigator key for reliable navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Initialize Android Alarm Manager
  await AndroidAlarmManager.initialize();

  // Ensure background isolate can access notification plugin
  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
  );

  await notifications.initialize(initSettings);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ConnectivityService _connectivityService = ConnectivityService();
  final AppLifecycleService _appLifecycleService = AppLifecycleService();
  final NotificationService _notificationService = NotificationService.instance;
  ProviderContainer? _container;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Initialize notification service
    await _notificationService.initialize();
    

    // Request notification permissions
    await _notificationService.requestPermissions();

    // Check for daily reset and schedule notifications
    await _notificationService.checkAndResetDailyStatus();

    // Start smart monitoring services
    _connectivityService.startMonitoring();
    _appLifecycleService.startObserving(container: _container);
  }

  @override
  void dispose() {
    // Stop monitoring services
    _connectivityService.dispose();
    _appLifecycleService.dispose();
    _notificationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final themeMode = ref.watch(themeProvider);

        // Store the container for app lifecycle service
        _container = ProviderScope.containerOf(context);

        return MaterialApp(
          title: 'Diary App',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          navigatorKey: navigatorKey,
          home: const AppWrapper(),
        );
      },
    );
  }
}
