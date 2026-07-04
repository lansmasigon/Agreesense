import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';

class DashboardStats {
  final int pendingValidation;
  final double validatedArea;
  final int totalFarmers;
  final List<String> oversupplyCrops;
  final List<BarangayStats> barangayStats;
  final List<RecentActivity> recentActivities;
  final List<Map<String, dynamic>> pendingValidationList; // Updated to Map for rich cards
  final List<String> farmersList;
  final Map<String, double> validatedAreaByBarangay;

  DashboardStats({
    required this.pendingValidation,
    required this.validatedArea,
    required this.totalFarmers,
    required this.oversupplyCrops,
    required this.barangayStats,
    required this.recentActivities,
    required this.pendingValidationList,
    required this.farmersList,
    required this.validatedAreaByBarangay,
  });
}

class BarangayStats {
  final String name;
  final int farmers;
  final double validatedArea;
  final String topCrop;
  final Color riskColor;

  BarangayStats({
    required this.name,
    required this.farmers,
    required this.validatedArea,
    required this.topCrop,
    required this.riskColor,
  });
}

class RecentActivity {
  final String description;
  final String date;

  RecentActivity({required this.description, required this.date});
}

final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  String formatCropId(String id) {
    if (id.isEmpty) return id;
    return id[0].toUpperCase() + id.substring(1).replaceAll('_', ' ');
  }

  // 1. Pending validation
  final pendingRes = await supabase
      .from('crop_declarations')
      .select('id, crop_id, area_ha, profiles(full_name)')
      .eq('status', 'pending')
      .order('created_at', ascending: false)
      .limit(5);
  final pendingCount = (await supabase.from('crop_declarations').select('id').eq('status', 'pending').count()).count ?? 0;
  
  final List<Map<String, dynamic>> pendingList = (pendingRes as List).map((e) {
    return {
      'farmer': e['profiles']?['full_name'] ?? 'Unknown',
      'crop': formatCropId(e['crop_id'] as String? ?? ''),
      'area': e['area_ha'] ?? 0.0,
      'id': e['id']
    };
  }).toList();

  // 2. Validated area
  final areaRes = await supabase
      .from('crop_declarations')
      .select('area_ha, barangay')
      .eq('status', 'approved');
  double validatedArea = 0;
  final Map<String, double> brgyAreaMap = {};
  for (var row in areaRes as List) {
    final area = (row['area_ha'] as num).toDouble();
    final brgy = row['barangay'] as String? ?? 'Unknown';
    validatedArea += area;
    brgyAreaMap[brgy] = (brgyAreaMap[brgy] ?? 0) + area;
  }

  // 3. Total farmers
  final farmersRes = await supabase.from('profiles').select('id').eq('role', 'farmer').count();
  final totalFarmers = farmersRes.count ?? 0;

  // 4. Oversupply crops
  final oversupplyCrops = ['Tomato', 'Eggplant'];

  // 5. Barangay stats for heatmap
  final brgyRes = await supabase
      .from('crop_declarations')
      .select('barangay, farmer_id, area_ha, crop_id')
      .eq('status', 'approved');

  final Map<String, Set<String>> brgyFarmers = {};
  final Map<String, double> brgyArea = {};
  final Map<String, Map<String, int>> brgyCropsCount = {};

  for (var row in brgyRes as List) {
    final brgy = row['barangay'] as String? ?? 'Unknown';
    final farmerId = row['farmer_id'] as String;
    final area = (row['area_ha'] as num).toDouble();
    final cropId = row['crop_id'] as String? ?? 'unknown';
    final cropName = formatCropId(cropId);

    brgyFarmers.putIfAbsent(brgy, () => {}).add(farmerId);
    brgyArea[brgy] = (brgyArea[brgy] ?? 0) + area;
    brgyCropsCount.putIfAbsent(brgy, () => {});
    brgyCropsCount[brgy]![cropName] = (brgyCropsCount[brgy]![cropName] ?? 0) + 1;
  }

  final List<BarangayStats> barangayStats = [];
  for (final brgy in brgyArea.keys) {
    String topCrop = 'Unknown';
    int maxCount = 0;
    if (brgyCropsCount[brgy] != null) {
      for (final entry in brgyCropsCount[brgy]!.entries) {
        if (entry.value > maxCount) {
          maxCount = entry.value;
          topCrop = entry.key;
        }
      }
    }
    
    // Calculate dummy risk color based on area
    Color rColor = AppColors.accent; // Green
    if (brgyArea[brgy]! > 100) rColor = AppColors.warning; // Yellow
    if (brgyArea[brgy]! > 500) rColor = const Color(0xFFF97316); // Orange
    if (brgyArea[brgy]! > 1000) rColor = AppColors.danger; // Red

    barangayStats.add(BarangayStats(
      name: brgy,
      farmers: brgyFarmers[brgy]?.length ?? 0,
      validatedArea: brgyArea[brgy]!,
      topCrop: topCrop,
      riskColor: rColor
    ));
  }
  barangayStats.sort((a, b) => b.validatedArea.compareTo(a.validatedArea));

  // 6. Recent activities
  final recentRes = await supabase
      .from('crop_declarations')
      .select('status, created_at, profiles(full_name), crop_id')
      .order('created_at', ascending: false)
      .limit(8);
  
  final List<RecentActivity> recentActivities = [];
  for (var row in recentRes as List) {
    final farmerName = row['profiles']?['full_name'] ?? 'Unknown Farmer';
    final cropId = row['crop_id'] as String? ?? 'unknown';
    final cropName = formatCropId(cropId);
    final status = row['status'];
    recentActivities.add(RecentActivity(
      description: '$farmerName submitted $cropName',
      date: 'Just now', // Dummy time formatting for design
    ));
  }

  return DashboardStats(
    pendingValidation: pendingCount,
    validatedArea: validatedArea,
    totalFarmers: totalFarmers,
    oversupplyCrops: oversupplyCrops,
    barangayStats: barangayStats,
    recentActivities: recentActivities,
    pendingValidationList: pendingList,
    farmersList: [],
    validatedAreaByBarangay: brgyAreaMap,
  );
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  BarangayStats? _selectedBarangay;

  void _showDetailsDialog(BuildContext context, String title, List<String> items) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: items.isEmpty 
              ? const Text('No details available.', style: TextStyle(color: AppColors.secondaryText)) 
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(items[index], style: const TextStyle(color: AppColors.text)),
                    );
                  },
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final user = ref.watch(currentUserProvider);
    final firstName = user?['full_name']?.split(' ').first ?? 'Admin';

    return statsAsync.when(
      data: (stats) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HERO SECTION
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Good Morning, $firstName', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.text, letterSpacing: -1)),
                      const SizedBox(height: 8),
                      const Text('Municipal Agriculture Office · Today\'s Summary', style: TextStyle(fontSize: 16, color: AppColors.secondaryText)),
                    ],
                  ),
                  Row(
                    children: [
                      _buildWeatherPill(Icons.wb_sunny_rounded, '32°C', 'Sunny'),
                      const SizedBox(width: 12),
                      _buildWeatherPill(Icons.water_drop_rounded, '12%', 'Rain Prob.'),
                      const SizedBox(width: 12),
                      _buildWeatherPill(Icons.eco_rounded, 'Wet', 'Season'),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 48),

              // EXECUTIVE KPIs
              Row(
                children: [
                  Expanded(child: _buildHoverCard(
                    title: 'Pending Validation',
                    value: '${stats.pendingValidation}',
                    subtitle: '+12 today',
                    valueColor: AppColors.warning,
                    onTap: () {
                      final items = stats.pendingValidationList.map((e) => '${e['farmer']} - ${e['crop']} (${e['area']} ha)').toList();
                      _showDetailsDialog(context, 'Pending Validation', items);
                    }
                  )),
                  const SizedBox(width: 24),
                  Expanded(child: _buildHoverCard(
                    title: 'Farmers Registered',
                    value: '${stats.totalFarmers}',
                    subtitle: '+14 today',
                    valueColor: AppColors.primary,
                    onTap: () {
                      _showDetailsDialog(context, 'Registered Farmers', stats.farmersList);
                    }
                  )),
                  const SizedBox(width: 24),
                  Expanded(child: _buildHoverCard(
                    title: 'Validated Area',
                    value: '${stats.validatedArea.toStringAsFixed(0)} ha',
                    subtitle: 'Current Season',
                    valueColor: AppColors.information,
                    onTap: () {
                      final list = stats.validatedAreaByBarangay.entries.map((e) => '${e.key}: ${e.value.toStringAsFixed(1)} ha').toList();
                      _showDetailsDialog(context, 'Validated Area by Barangay', list);
                    }
                  )),
                  const SizedBox(width: 24),
                  Expanded(child: _buildHoverCard(
                    title: 'Oversupply Risk',
                    value: 'High',
                    subtitle: stats.oversupplyCrops.join(', '),
                    valueColor: AppColors.danger,
                    onTap: () {
                      _showDetailsDialog(context, 'Oversupply Crops', stats.oversupplyCrops);
                    }
                  )),
                ],
              ),
              const SizedBox(height: 32),

              // MAP & QUEUE
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Production Heatmap
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 540,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Production Heatmap', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                          const SizedBox(height: 24),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Simulated Map visualization - wrapped in SingleChildScrollView to prevent overflow
                                Expanded(
                                  flex: 3,
                                  child: SingleChildScrollView(
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: stats.barangayStats.map((brgy) {
                                        final isSelected = _selectedBarangay?.name == brgy.name;
                                        return MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: GestureDetector(
                                            onTap: () => setState(() => _selectedBarangay = brgy),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 200),
                                              width: 100, // Fixed width
                                              height: 100, // Fixed height to prevent overflow issues
                                              decoration: BoxDecoration(
                                                color: brgy.riskColor.withOpacity(isSelected ? 0.3 : 0.1),
                                                border: Border.all(color: brgy.riskColor, width: isSelected ? 3 : 1),
                                                borderRadius: BorderRadius.circular(16),
                                                boxShadow: isSelected ? [BoxShadow(color: brgy.riskColor.withOpacity(0.4), blurRadius: 16)] : [],
                                              ),
                                              child: Center(
                                                child: Text(brgy.name, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isSelected ? 14 : 12, color: AppColors.text)),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 32),
                                // Zoomed Details
                                Expanded(
                                  flex: 2,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: _selectedBarangay == null 
                                      ? const Center(child: Text('Select a barangay\nto view analytics.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.secondaryText)))
                                      : Column(
                                          key: ValueKey(_selectedBarangay!.name),
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(_selectedBarangay!.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -1)),
                                            const SizedBox(height: 24),
                                            _buildBrgyDetail('Farmers', '${_selectedBarangay!.farmers}', Icons.people_outline),
                                            _buildBrgyDetail('Validated Area', '${_selectedBarangay!.validatedArea.toStringAsFixed(1)} ha', Icons.map_outlined),
                                            _buildBrgyDetail('Top Crop', _selectedBarangay!.topCrop, Icons.grass),
                                            const SizedBox(height: 32),
                                            Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(color: _selectedBarangay!.riskColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.analytics, color: _selectedBarangay!.riskColor),
                                                  const SizedBox(width: 12),
                                                  const Expanded(child: Text('Historical yield trending upward this season.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                                ],
                                              ),
                                            )
                                          ],
                                        ),
                                  ),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  
                  // Validation Queue Cards
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Validation Queue', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                            TextButton(onPressed: (){}, child: const Text('View All'))
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (stats.pendingValidationList.isEmpty)
                          const Padding(padding: EdgeInsets.all(32), child: Text('Queue is empty.', style: TextStyle(color: AppColors.secondaryText))),
                        ...stats.pendingValidationList.map((item) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['crop'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(item['farmer'], style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                    child: const Text('Pending', style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 12),
                                  Text('${item['area']} ha', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                ],
                              )
                            ],
                          ),
                        ))
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 32),

              // BOTTOM ROW: Activity Timeline & Bar Chart
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: Container(
                      height: 400,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Activity Timeline', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                          const SizedBox(height: 24),
                          Expanded(
                            child: ListView.builder(
                              itemCount: stats.recentActivities.length,
                              itemBuilder: (context, index) {
                                final act = stats.recentActivities[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8, height: 8,
                                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(act.description, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                            Text(act.date, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                );
                              }
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 400,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Historical Yield vs Target', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                          const SizedBox(height: 32),
                          Expanded(
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                borderData: FlBorderData(show: false),
                                gridData: const FlGridData(show: true, drawVerticalLine: false),
                                barGroups: stats.barangayStats.take(6).toList().asMap().entries.map((entry) {
                                  return BarChartGroupData(
                                    x: entry.key,
                                    barRods: [
                                      BarChartRodData(toY: entry.value.validatedArea, color: AppColors.primary, width: 24, borderRadius: BorderRadius.circular(4)),
                                      BarChartRodData(toY: entry.value.validatedArea * 1.2, color: AppColors.border, width: 24, borderRadius: BorderRadius.circular(4)),
                                    ],
                                  );
                                }).toList(),
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        if (value.toInt() < stats.barangayStats.length) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Text(stats.barangayStats[value.toInt()].name, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                                          );
                                        }
                                        return const Text('');
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                              )
                            )
                          )
                        ],
                      ),
                    ),
                  )
                ],
              )
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.danger))),
    );
  }

  Widget _buildBrgyDetail(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.text)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildWeatherPill(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.secondaryText),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildHoverCard({required String title, required String value, required String subtitle, required Color valueColor, VoidCallback? onTap}) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;
        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutQuart,
              padding: const EdgeInsets.all(32),
              transform: Matrix4.translationValues(0, isHovered ? -4 : 0, 0),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isHovered ? AppColors.accent.withOpacity(0.5) : AppColors.border),
                boxShadow: isHovered ? [
                  BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 32, offset: const Offset(0, 16))
                ] : [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w600, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 16),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: valueColor, letterSpacing: -1.5)),
                  ),
                  const SizedBox(height: 8),
                  Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.secondaryText), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        );
      }
    );
  }
}
