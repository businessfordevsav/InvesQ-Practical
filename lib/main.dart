import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:invesq_practical/core/theme/app_theme.dart';
import 'package:invesq_practical/features/auth/presentation/providers/auth_provider.dart';
import 'package:invesq_practical/features/expense/presentation/providers/expense_provider.dart';
import 'package:invesq_practical/features/leads/presentation/providers/leads_provider.dart';
import 'package:invesq_practical/features/auth/presentation/screens/login_screen.dart';
import 'package:invesq_practical/features/profile/presentation/screens/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => LeadsProvider()),
      ],
      child: MaterialApp(
        title: 'InvesQ Practical',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.checkAuthStatus();

    if (mounted) {
      final isAuthenticated = authProvider.state == AuthState.authenticated;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              isAuthenticated ? const ProfileScreen() : const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_circle,
              size: 100,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            const Text(
              'InvesQ Practical',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
