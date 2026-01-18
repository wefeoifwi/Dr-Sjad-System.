import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:bot_toast/bot_toast.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/notifications/notifications_provider.dart';
import 'features/follow_up/follow_up_provider.dart';
import 'features/admin/admin_provider.dart';
import 'features/schedule/schedule_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  runApp(const CarePointApp());
}

class CarePointApp extends StatelessWidget {
  const CarePointApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core providers - initialized once at app start
        ChangeNotifierProvider(create: (_) => AdminProvider()..loadStaff()..loadServices()..loadDevices()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
        // ScheduleProvider مع ربط NotificationsProvider
        ChangeNotifierProxyProvider<NotificationsProvider, ScheduleProvider>(
          create: (context) => ScheduleProvider()
            ..loadData()
            ..subscribeToRealtimeUpdates(),
          update: (context, notifications, previous) {
            if (previous != null) {
              previous.setNotificationsProvider(notifications);
              return previous;
            }
            return ScheduleProvider()
              ..setNotificationsProvider(notifications)
              ..loadData()
              ..subscribeToRealtimeUpdates();
          },
        ),
        ChangeNotifierProxyProvider<NotificationsProvider, FollowUpProvider>(
          create: (context) => FollowUpProvider(
            notificationsProvider: context.read<NotificationsProvider>(),
          ),
          update: (context, notifications, previous) => FollowUpProvider(
            notificationsProvider: notifications,
          ),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        // Localization for Arabic Support
        builder: BotToastInit(), // 1. Initialize BotToast
        navigatorObservers: [BotToastNavigatorObserver()], // 2. Register Observer
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ar', ''), // Primary: Arabic
          Locale('en', ''),
        ],
        locale: const Locale('ar', ''), // Force Arabic for now
        home: const LoginScreen(),
      ),
    );
  }
}

