import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';

final logbookFarmersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final res = await supabase
      .from('profiles')
      .select('id, full_name, barangay, contact_number, farms(total_area_ha, name), crop_declarations(crop_id, barangay, area_ha, created_at, status, expected_yield_kg, projected_price_per_kg), calamity_reports(type, affected_area_ha, estimated_loss_value, occurred_on)')
      .eq('role', 'farmer');

  return List<Map<String, dynamic>>.from(res as List);
});

class LogbookScreen extends ConsumerStatefulWidget {
  const LogbookScreen({super.key});

  @override
  ConsumerState<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends ConsumerState<LogbookScreen> {
  String? _selectedFarmerId;

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          )
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    if (status == 'approved') return AppColors.primary;
    if (status == 'rejected') return AppColors.danger;
    if (status == 'baw_approved') return AppColors.information;
    return AppColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    final farmersAsync = ref.watch(logbookFarmersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Farmer Logbook', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1)),
            const SizedBox(height: 8),
            const Text('Comprehensive details and history of registered farmers.', style: TextStyle(fontSize: 16, color: AppColors.secondaryText)),
            const SizedBox(height: 48),

            farmersAsync.when(
              data: (farmers) {
                if (farmers.isEmpty) return const Text('No farmers found.');
                
                final selectedFarmer = _selectedFarmerId != null ? farmers.firstWhere((f) => f['id'] == _selectedFarmerId, orElse: () => farmers.first) : farmers.first;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Farmer Search Dropdown
                    DropdownMenu<String>(
                      initialSelection: selectedFarmer['id'] as String?,
                      width: 400,
                      enableFilter: true,
                      enableSearch: true,
                      leadingIcon: const Icon(Icons.search),
                      hintText: 'Search for a farmer...',
                      inputDecorationTheme: InputDecorationTheme(
                        filled: true,
                        fillColor: AppColors.card,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onSelected: (String? val) {
                        if (val != null) {
                          setState(() => _selectedFarmerId = val);
                        }
                      },
                      dropdownMenuEntries: farmers.map<DropdownMenuEntry<String>>((f) {
                        return DropdownMenuEntry<String>(
                          value: f['id'] as String,
                          label: f['full_name'] ?? 'Unknown',
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                    
                    // Main Content Area
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEFT: Personal & Farm Information
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 32,
                                      backgroundColor: AppColors.primary.withOpacity(0.1),
                                      child: Text((selectedFarmer['full_name'] ?? 'U')[0].toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(selectedFarmer['full_name'] ?? 'Unknown', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                          Text(selectedFarmer['barangay'] ?? 'N/A', style: const TextStyle(color: AppColors.secondaryText)),
                                        ],
                                      )
                                    )
                                  ],
                                ),
                                const SizedBox(height: 32),
                                const Text('PERSONAL INFORMATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondaryText, letterSpacing: 1.2)),
                                const SizedBox(height: 16),
                                _buildDetailRow('Contact Number', selectedFarmer['contact_number'] ?? 'N/A', Icons.phone_outlined),
                                _buildDetailRow('Barangay', selectedFarmer['barangay'] ?? 'N/A', Icons.location_on_outlined),
                                
                                const SizedBox(height: 24),
                                const Text('FARM INFORMATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondaryText, letterSpacing: 1.2)),
                                const SizedBox(height: 16),
                                Builder(
                                  builder: (context) {
                                    final farms = selectedFarmer['farms'] as List<dynamic>? ?? [];
                                    double totalArea = 0;
                                    for (var f in farms) {
                                      totalArea += (f['total_area_ha'] as num?)?.toDouble() ?? 0;
                                    }
                                    
                                    double totalRevenue = 0;
                                    final cropsForRev = selectedFarmer['crop_declarations'] as List<dynamic>? ?? [];
                                    for (var c in cropsForRev) {
                                      if (c['status'] == 'harvested') {
                                        final yieldKg = (c['expected_yield_kg'] as num?)?.toDouble() ?? 0;
                                        final price = (c['projected_price_per_kg'] as num?)?.toDouble() ?? 0;
                                        totalRevenue += (yieldKg * price);
                                      }
                                    }
                                    
                                    // simple comma formatting
                                    final parts = totalRevenue.toStringAsFixed(2).split('.');
                                    final regExp = RegExp(r'\B(?=(\d{3})+(?!\d))');
                                    final formattedRev = parts[0].replaceAll(regExp, ',') + '.' + parts[1];
                                    
                                    return Column(
                                      children: [
                                        _buildDetailRow('Total Area', '$totalArea hectares', Icons.landscape_outlined),
                                        _buildDetailRow('Est. Revenue (Harvested)', '₱$formattedRev', Icons.payments_outlined),
                                      ]
                                    );
                                  }
                                ),
                                _buildDetailRow('Registered Farms', '${(selectedFarmer['farms'] as List<dynamic>? ?? []).length}', Icons.agriculture_outlined),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // RIGHT: Planted Crops List & Calamities
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                height: 350,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('All Planted Crops', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: Builder(
                                        builder: (context) {
                                          final cropsList = selectedFarmer['crop_declarations'] as List<dynamic>? ?? [];
                                          final crops = List<dynamic>.from(cropsList);
                                          crops.sort((a, b) {
                                            final dateA = DateTime.tryParse(a['created_at'].toString()) ?? DateTime(2000);
                                            final dateB = DateTime.tryParse(b['created_at'].toString()) ?? DateTime(2000);
                                            return dateB.compareTo(dateA);
                                          });

                                          if (crops.isEmpty) return const Center(child: Text('No plantings recorded.', style: TextStyle(color: AppColors.secondaryText)));
                                          
                                          return ListView.builder(
                                            itemCount: crops.length,
                                            itemBuilder: (context, index) {
                                              final crop = crops[index];
                                              return Card(
                                                elevation: 0,
                                                color: AppColors.background,
                                                margin: const EdgeInsets.only(bottom: 12),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                                                child: ListTile(
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                                  leading: Container(
                                                    padding: const EdgeInsets.all(10),
                                                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                                    child: const Icon(Icons.eco, color: AppColors.primary, size: 20),
                                                  ),
                                                  title: Text((crop['crop_id'] as String? ?? '').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                                  subtitle: Padding(
                                                    padding: const EdgeInsets.only(top: 4.0),
                                                    child: Text('${crop['barangay'] ?? 'N/A'} • ${crop['area_ha'] ?? 0} hectares'),
                                                  ),
                                                  trailing: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    crossAxisAlignment: CrossAxisAlignment.end,
                                                    children: [
                                                      Text((crop['status'] as String? ?? 'pending').toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getStatusColor(crop['status']))),
                                                      const SizedBox(height: 4),
                                                      Text(crop['created_at'] != null ? crop['created_at'].toString().split('T').first : '', style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }
                                          );
                                        }
                                      )
                                    )
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Container(
                                height: 350,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Calamity History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: Builder(
                                        builder: (context) {
                                          final reportsList = selectedFarmer['calamity_reports'] as List<dynamic>? ?? [];
                                          if (reportsList.isEmpty) return const Center(child: Text('No calamity reports filed.', style: TextStyle(color: AppColors.secondaryText)));
                                          
                                          return ListView.builder(
                                            itemCount: reportsList.length,
                                            itemBuilder: (context, index) {
                                              final r = reportsList[index];
                                              return Card(
                                                elevation: 0,
                                                color: AppColors.background,
                                                margin: const EdgeInsets.only(bottom: 12),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                                                child: ListTile(
                                                  leading: const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                                                  title: Text((r['type'] as String? ?? 'Unknown').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger)),
                                                  subtitle: Text('Affected Area: ${r['affected_area_ha'] ?? 0} ha • Loss: ₱${r['estimated_loss_value'] ?? 0}'),
                                                  trailing: Text(r['occurred_on'] != null ? r['occurred_on'].toString() : '', style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                                                ),
                                              );
                                            }
                                          );
                                        }
                                      )
                                    )
                                  ],
                                ),
                              )
                            ],
                          ),
                        )
                      ],
                    )
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error loading logbook: $err'),
            )
          ],
        ),
      ),
    );
  }
}
