import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/admin/admin_shell.dart';
import '../../features/admin/dashboard_screen.dart';
import '../../features/admin/validation_queue_screen.dart';
import '../../features/admin/logbook_screen.dart';
import '../../features/admin/supply_chain_screen.dart';
import '../../features/admin/calamities_screen.dart';
import '../../features/admin/reference_data_screen.dart';
import '../../features/admin/reports_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../providers/auth_provider.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final user = ref.watch(currentUserProvider);
  
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthenticated = user != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isAuthenticated && !isLoggingIn) return '/login';
      if (isAuthenticated && isLoggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/validation',
            builder: (context, state) => const ValidationQueueScreen(),
          ),
          GoRoute(
            path: '/logbook',
            builder: (context, state) => const LogbookScreen(),
          ),
          GoRoute(
            path: '/supply-chain',
            builder: (context, state) => const SupplyChainScreen(),
          ),
          GoRoute(
            path: '/calamities',
            builder: (context, state) => const CalamitiesScreen(),
          ),
          GoRoute(
            path: '/reference-data',
            builder: (context, state) => const ReferenceDataScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
        ],
      ),
    ],
  );
});

