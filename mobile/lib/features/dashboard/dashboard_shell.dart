import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import '../chat/chat_screen.dart';
import '../logging/logging_screen.dart';
import '../medical/medical_hub_screen.dart';
import '../medical/upload_medical_report_screen.dart';
import '../profile/profile_settings_screen.dart';
import '../trends/view_trends_screen.dart';
import 'dashboard_screen.dart';

class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key});

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  int _index = 0;

  final _screens = const [
    DashboardScreen(),
    LoggingScreen(),
    MedicalHubScreen(),
    ChatScreen(),
  ];


  static const _titles = [
    'Dashboard',
    'Trends',
    'AI Health Chat',
    'Insights',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        top: false,
        child: IndexedStack(index: _index, children: _screens),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_rounded),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'Logs',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_rounded),
            selectedIcon: Icon(Icons.monitor_heart_rounded),
            label: 'Medical',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}

