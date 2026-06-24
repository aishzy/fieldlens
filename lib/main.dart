import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/database/database_helper.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/session_provider.dart';
import 'core/providers/inspection_provider.dart';
import 'ui/screens/auth/login_screen.dart';
import 'ui/screens/dashboard/dashboard_screen.dart';
import 'ui/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.initDatabase();
  runApp(const DilapidationSurveyApp());
}

class DilapidationSurveyApp extends StatelessWidget {
  const DilapidationSurveyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, SessionProvider>(
          create: (_) => SessionProvider(),
          update: (_, authProvider, sessionProvider) {
            sessionProvider?.setCurrentUserId(authProvider.currentUser?.id ?? '');
            return sessionProvider ?? SessionProvider();
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, InspectionProvider>(
          create: (_) => InspectionProvider(),
          update: (_, authProvider, inspectionProvider) {
            inspectionProvider?.setCurrentUserId(authProvider.currentUser?.id ?? '');
            return inspectionProvider ?? InspectionProvider();
          },
        ),
      ],
      child: MaterialApp(
        title: 'Dilapidation Survey',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        themeMode: ThemeMode.light,
        home: const SplashScreen(),
        routes: {
          LoginScreen.routeName: (_) => const LoginScreen(),
          DashboardScreen.routeName: (_) => const DashboardScreen(),
        },
      ),
    );
  }
}
