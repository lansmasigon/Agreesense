import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

class AdminShell extends ConsumerWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/validation')) return 1;
    if (location.startsWith('/calamities')) return 2;
    if (location.startsWith('/supply-chain')) return 3;
    if (location.startsWith('/reference-data')) return 4;
    if (location.startsWith('/reports')) return 5;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/validation');
        break;
      case 2:
        context.go('/calamities');
        break;
      case 3:
        context.go('/supply-chain');
        break;
      case 4:
        context.go('/reference-data');
        break;
      case 5:
        context.go('/reports');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _calculateSelectedIndex(context);

    Widget buildNavItem(int index, String title, IconData icon, {bool disabled = false}) {
      final isActive = selectedIndex == index && !disabled;
      return InkWell(
        onTap: disabled ? null : () => _onItemTapped(index, context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFe6f7ea) : Colors.transparent,
            border: isActive ? const Border(left: BorderSide(color: Color(0xFF2da84e), width: 3)) : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: disabled ? Colors.grey : isActive ? const Color(0xFF2da84e) : const Color(0xFF4a6b4a)),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: disabled ? Colors.grey : isActive ? const Color(0xFF1a2e1a) : const Color(0xFF4a6b4a),
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildNavSection(String title) {
      return Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 4),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF8aaa8a),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 228,
            color: Colors.white,
            child: Column(
              children: [
                // Brand
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0x1F22783C))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2da84e), Color(0xFF1a8a6e)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.eco, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AgriSense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('MAO PORTAL', style: TextStyle(fontSize: 10, color: Color(0xFF8aaa8a), letterSpacing: 0.5)),
                        ],
                      ),
                    ],
                  ),
                ),
                // Nav Items
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final user = ref.watch(currentUserProvider);
                      final userRole = user?['role'] as String?;
                      
                      return ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          buildNavSection('Overview'),
                          buildNavItem(0, 'Dashboard', Icons.dashboard_outlined),
                          
                          buildNavSection('Governance'),
                          buildNavItem(1, 'Validation queue', Icons.fact_check_outlined),
                          buildNavItem(2, 'Calamity reports', Icons.warning_amber_outlined, disabled: userRole != 'mao'),
                          
                          buildNavSection('Analytics'),
                          buildNavItem(3, 'Supply chain', Icons.analytics_outlined, disabled: userRole != 'mao'),
                          
                          buildNavSection('Admin'),
                          buildNavItem(4, 'Reference data', Icons.dataset_outlined, disabled: userRole != 'mao'),
                          buildNavItem(5, 'Reports', Icons.insert_chart_outlined, disabled: userRole != 'mao' && userRole != 'technician'),
                        ],
                      );
                    }
                  ),
                ),
                // User Profile Bottom
                Consumer(
                  builder: (context, ref, child) {
                    final user = ref.watch(currentUserProvider);
                    final fullName = user?['full_name'] ?? 'Admin User';
                    final role = user?['role']?.toString().toUpperCase() ?? 'MAO';
                    final initials = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Color(0x1F22783C))),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFFe6f7ea),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0x4D2DA84E)),
                            ),
                            alignment: Alignment.center,
                            child: Text(initials, style: const TextStyle(color: Color(0xFF2da84e), fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(fullName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                Text(role, style: const TextStyle(fontSize: 10, color: Color(0xFF4a6b4a)), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout, size: 16, color: Color(0xFF8aaa8a)),
                            onPressed: () {
                              ref.read(currentUserProvider.notifier).setUser(null);
                            },
                          )
                        ],
                      ),
                    );
                  }
                )
              ],
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: Color(0x1F22783C)),
          // Main content area
          Expanded(
            child: Column(
              children: [
                // Topbar
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0x1F22783C))),
                  ),
                  child: Row(
                    children: [
                      const Text('Municipal Dashboard', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      // Simplified search placeholder
                      Container(
                        width: 220,
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFf4faf4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x1F22783C)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.search, size: 14, color: Color(0xFF8aaa8a)),
                            SizedBox(width: 8),
                            Text('Search...', style: TextStyle(fontSize: 12, color: Color(0xFF8aaa8a))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Page Content
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
