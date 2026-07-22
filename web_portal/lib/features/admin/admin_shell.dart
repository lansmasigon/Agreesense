import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';

class _GlobalSearchBar extends StatefulWidget {
  const _GlobalSearchBar({Key? key}) : super(key: key);

  @override
  State<_GlobalSearchBar> createState() => _GlobalSearchBarState();
}

class _GlobalSearchBarState extends State<_GlobalSearchBar> {
  Timer? _debounce;
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      // Execute search logic here
      debugPrint('Global search triggered for: $query');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _controller,
        onChanged: _onSearchChanged,
        decoration: const InputDecoration(
          hintText: 'Search anything',
          hintStyle: TextStyle(fontSize: 14, color: AppColors.secondaryText),
          prefixIcon: Icon(Icons.search, size: 18, color: AppColors.secondaryText),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        style: const TextStyle(fontSize: 14, color: AppColors.text),
      ),
    );
  }
}

class AdminShell extends ConsumerWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/logbook')) return 2;
    if (location.startsWith('/calamities')) return 3;
    if (location.startsWith('/supply-chain')) return 4;
    if (location.startsWith('/reference-data')) return 5;
    if (location.startsWith('/reports')) return 6;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 2:
        context.go('/logbook');
        break;
      case 3:
        context.go('/calamities');
        break;
      case 4:
        context.go('/supply-chain');
        break;
      case 5:
        context.go('/reference-data');
        break;
      case 6:
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
        hoverColor: AppColors.background.withOpacity(0.5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutQuart,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppColors.accent.withOpacity(0.1) : Colors.transparent,
            border: isActive ? const Border(left: BorderSide(color: AppColors.primary, width: 3)) : const Border(left: BorderSide(color: Colors.transparent, width: 3)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: disabled ? AppColors.border : isActive ? AppColors.primary : AppColors.secondaryText),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: disabled ? AppColors.border : isActive ? AppColors.text : AppColors.secondaryText,
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildNavSection(String title) {
      return Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1600),
          child: Row(
            children: [
              // Sidebar
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                width: 260,
                decoration: const BoxDecoration(
                  color: AppColors.card,
                  border: Border(right: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  children: [
                    // Brand
                    Container(
                      height: 72,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.centerLeft,
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.border)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.dashboard, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('MAO Analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text)),
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
                              buildNavItem(0, 'Dashboard', Icons.grid_view_rounded),
                              buildNavItem(2, 'Logbook', Icons.menu_book_rounded),
                              
                              buildNavSection('Workspace'),
                              buildNavItem(3, 'Calamities', Icons.warning_amber_rounded, disabled: userRole != 'mao'),
                              buildNavItem(4, 'Supply Chain', Icons.local_shipping_outlined, disabled: userRole != 'mao'),
                              
                              buildNavSection('Data'),
                              buildNavItem(5, 'Reference Data', Icons.table_chart_outlined, disabled: userRole != 'mao'),
                              buildNavItem(6, 'Reports', Icons.bar_chart_rounded, disabled: userRole != 'mao' && userRole != 'technician'),
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
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.accent.withOpacity(0.2),
                                child: Text(initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(fullName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text)),
                                    Text(role, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText), overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.logout, size: 20, color: AppColors.secondaryText),
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
              // Main content area
              Expanded(
                child: Column(
                  children: [
                    // Topbar
                    Container(
                      height: 72,
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: const BoxDecoration(
                        color: AppColors.background,
                        border: Border(bottom: BorderSide(color: AppColors.border)),
                      ),
                      child: Row(
                        children: [
                          const Spacer(),
                          // Simplified search placeholder
                          const _GlobalSearchBar(),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ),
                    // Page Content
                    Expanded(
                      child: ClipRRect(
                        child: child
                      )
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
