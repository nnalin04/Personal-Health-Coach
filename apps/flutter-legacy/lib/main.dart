import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/cache/local_cache.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/dashboard/dashboard_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalCache.init();
  runApp(const ProviderScope(child: HealthCoachApp()));
}

class HealthCoachApp extends ConsumerWidget {
  const HealthCoachApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'Personal Health Coach',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: _home(authState),
    );
  }

  Widget _home(AuthState authState) {
    if (!authState.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authState.isAuthenticated) {
      return const DashboardShell();
    }

    return const LoginScreen();
  }
}
