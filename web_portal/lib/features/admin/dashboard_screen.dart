import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_portal/providers/auth_provider.dart';

class DashboardStats {
  final int pendingValidation;
  final double validatedArea;
  final int totalFarmers;
  final List<String> oversupplyCrops;
  final List<BarangayStats> barangayStats;
  final List<RecentActivity> recentActivities;
  final List<String> pendingValidationList;
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

  BarangayStats({
    required this.name,
    required this.farmers,
    required this.validatedArea,
    required this.topCrop,
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
      .select('id, crop_id, profiles(full_name)')
      .eq('status', 'pending');
  final pendingCount = (pendingRes as List).length;
  final List<String> pendingList = (pendingRes).map((e) {
    final farmerName = e['profiles']?['full_name'] ?? 'Unknown';
    final crop = formatCropId(e['crop_id'] as String? ?? '');
    return '$farmerName - $crop';
  }).toList();

  // 2. Validated area (e.g. 'approved')
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
  final farmersRes = await supabase
      .from('profiles')
      .select('full_name, barangay')
      .eq('role', 'farmer');
  final totalFarmers = (farmersRes as List).length;
  final List<String> farmersList = (farmersRes).map((e) {
    final name = e['full_name'] ?? 'Unknown';
    final brgy = e['barangay'] ?? 'Unknown';
    return '$name ($brgy)';
  }).toList();

  // 4. Oversupply crops (dummy for now)
  final oversupplyCrops = ['Bitter Gourd', 'Tomato', 'Eggplant'];

  // 5. Barangay stats
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

    barangayStats.add(BarangayStats(
      name: brgy,
      farmers: brgyFarmers[brgy]?.length ?? 0,
      validatedArea: brgyArea[brgy]!,
      topCrop: topCrop,
    ));
  }

  // Sort by validated area descending
  barangayStats.sort((a, b) => b.validatedArea.compareTo(a.validatedArea));

  // 6. Recent activities
  final recentRes = await supabase
      .from('crop_declarations')
      .select('status, created_at, profiles(full_name), crop_id')
      .order('created_at', ascending: false)
      .limit(5);
  
  final List<RecentActivity> recentActivities = [];
  for (var row in recentRes as List) {
    final farmerName = row['profiles']?['full_name'] ?? 'Unknown Farmer';
    final cropId = row['crop_id'] as String? ?? 'unknown';
    final cropName = formatCropId(cropId);
    final status = row['status'];
    final date = row['created_at'] != null ? DateTime.parse(row['created_at']).toLocal().toString().split('.')[0] : 'Unknown date';
    recentActivities.add(RecentActivity(
      description: '$farmerName\'s $cropName declaration is $status',
      date: date,
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
    farmersList: farmersList,
    validatedAreaByBarangay: brgyAreaMap,
  );
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentPage = 0;
  final int _itemsPerPage = 5;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return statsAsync.when(
      data: (stats) {
        final totalPages = (stats.barangayStats.length / _itemsPerPage).ceil();
        final startIndex = _currentPage * _itemsPerPage;
        final endIndex = (startIndex + _itemsPerPage < stats.barangayStats.length) 
            ? startIndex + _itemsPerPage 
            : stats.barangayStats.length;
        
        final paginatedBarangayStats = stats.barangayStats.isEmpty 
            ? <BarangayStats>[] 
            : stats.barangayStats.sublist(startIndex, endIndex);

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // KPI Grid
            Row(
              children: [
                Expanded(child: _buildKpiCard('Pending validation', '${stats.pendingValidation}', const Color(0xFFF59E0B), 'Current queue', onTap: () {
                  _showDetailsDialog('Pending Validations', stats.pendingValidationList);
                })),
                const SizedBox(width: 16),
                Expanded(child: _buildKpiCard('Validated area', '${stats.validatedArea.toStringAsFixed(1)} ha', const Color(0xFF3B82F6), 'Total approved', onTap: () {
                  final list = stats.validatedAreaByBarangay.entries.map((e) => '${e.key}: ${e.value.toStringAsFixed(1)} ha').toList();
                  _showDetailsDialog('Validated Area by Barangay', list);
                })),
                const SizedBox(width: 16),
                Expanded(child: _buildKpiCard('Total farmers', '${stats.totalFarmers}', const Color(0xFF1E293B), 'Registered users', onTap: () {
                  _showDetailsDialog('Registered Farmers', stats.farmersList);
                })),
                const SizedBox(width: 16),
                Expanded(child: _buildKpiCard('Oversupply crops', '${stats.oversupplyCrops.length}', const Color(0xFFEF4444), 'Bitter gourd, etc.', onTap: () {
                  _showDetailsDialog('Oversupply Crops', stats.oversupplyCrops);
                })),
              ],
            ),
            const SizedBox(height: 24),
            
            // Chart Section
            Container(
              height: 350,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 4))],
                border: Border.all(color: Colors.grey.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Validated Area by Barangay (ha)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                  const SizedBox(height: 24),
                  Expanded(
                    child: stats.barangayStats.isEmpty 
                      ? const Center(child: Text('No data available'))
                      : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            barGroups: stats.barangayStats.asMap().entries.map((entry) {
                              return BarChartGroupData(
                                x: entry.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: entry.value.validatedArea,
                                    color: Colors.blue,
                                    width: 16,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                              );
                            }).toList(),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() >= 0 && value.toInt() < stats.barangayStats.length) {
                                      final name = stats.barangayStats[value.toInt()].name;
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          name.length > 6 ? '${name.substring(0, 6)}...' : name,
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                  reservedSize: 28,
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toStringAsFixed(0),
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  },
                                ),
                              ),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(show: true, drawVerticalLine: false),
                          ),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Bottom section
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                
                final barangayTable = Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 4))],
                    border: Border.all(color: Colors.grey.withOpacity(0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Barangay production overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                            SizedBox(height: 4),
                            Text('Validated declarations · current season', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          dataTextStyle: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
                          columns: const [
                            DataColumn(label: Text('BARANGAY')),
                            DataColumn(label: Text('FARMERS')),
                            DataColumn(label: Text('VALIDATED AREA')),
                            DataColumn(label: Text('TOP CROP')),
                          ],
                          rows: paginatedBarangayStats.map((brgy) {
                            return DataRow(cells: [
                              DataCell(Text(brgy.name, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                              DataCell(Text('${brgy.farmers}')),
                              DataCell(Text('${brgy.validatedArea.toStringAsFixed(1)} ha')),
                              DataCell(Text(brgy.topCrop)),
                            ]);
                          }).toList(),
                        ),
                      ),
                      if (totalPages > 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Page ${_currentPage + 1} of $totalPages', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left, color: Color(0xFF64748B)),
                                    onPressed: _currentPage > 0 
                                        ? () => setState(() => _currentPage--)
                                        : null,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
                                    onPressed: _currentPage < totalPages - 1 
                                        ? () => setState(() => _currentPage++)
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
                
                final recentActivityBox = Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 4))],
                    border: Border.all(color: Colors.grey.withOpacity(0.08)),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recent Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                      const SizedBox(height: 24),
                      if (stats.recentActivities.isEmpty)
                        const Text('No recent activity.', style: TextStyle(color: Color(0xFF64748B))),
                      ...stats.recentActivities.map((activity) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 8, 
                                height: 8, 
                                decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle)
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(activity.description, style: const TextStyle(fontSize: 14, color: Color(0xFF334155))),
                                    const SizedBox(height: 4),
                                    Text(activity.date, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                );
                
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: barangayTable),
                      const SizedBox(width: 24),
                      Expanded(flex: 1, child: recentActivityBox),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      barangayTable,
                      const SizedBox(height: 24),
                      recentActivityBox,
                    ],
                  );
                }
              }
            )
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  void _showDetailsDialog(String title, List<String> items) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: items.isEmpty 
              ? const Text('No details available.') 
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(items[index]),
                    );
                  },
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(String label, String value, Color valueColor, String sub, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 4))],
            border: Border.all(color: Colors.grey.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: valueColor), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
