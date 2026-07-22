import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:syncfusion_flutter_maps/maps.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';

class DashboardStats {
  final int pendingDeclarations;
  final double totalArea;
  final int totalFarmers;
  final List<String> oversupplyCrops;
  final String oversupplyRiskLevel;
  final Color oversupplyRiskColor;
  final List<BarangayStats> barangayStats;
  final List<RecentActivity> recentActivities;
  final List<Map<String, dynamic>> pendingDeclarationsList; // Updated to Map for rich cards
  final List<String> farmersList;
  final Map<String, double> totalAreaByBarangay;

  DashboardStats({
    required this.pendingDeclarations,
    required this.totalArea,
    required this.totalFarmers,
    required this.oversupplyCrops,
    required this.oversupplyRiskLevel,
    required this.oversupplyRiskColor,
    required this.barangayStats,
    required this.recentActivities,
    required this.pendingDeclarationsList,
    required this.farmersList,
    required this.totalAreaByBarangay,
  });
}

class BarangayStats {
  final String name;
  final int farmers;
  final double totalArea;
  final String topCrop;
  final Color riskColor;
  final List<String> allCropsPlanted;

  BarangayStats({
    required this.name,
    required this.farmers,
    required this.totalArea,
    required this.topCrop,
    required this.riskColor,
    required this.allCropsPlanted,
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

  // 1. Available Harvest
  final harvestRes = await supabase
      .from('crop_declarations')
      .select('id, crop_id, area_ha, barangay, expected_harvest_date, profiles(full_name)')
      .eq('status', 'approved')
      .order('expected_harvest_date', ascending: true)
      .limit(4);
  final pendingCount = (await supabase.from('crop_declarations').select('id').eq('status', 'approved').count()).count ?? 0;
  
  final List<Map<String, dynamic>> pendingList = (harvestRes as List).map((e) {
    return {
      'farmer': e['profiles']?['full_name'] ?? 'Unknown',
      'crop': formatCropId(e['crop_id'] as String? ?? ''),
      'area': e['area_ha'] ?? 0.0,
      'barangay': e['barangay'] ?? 'Unknown',
      'id': e['id']
    };
  }).toList();

  // 2. Total area
  final areaRes = await supabase
      .from('crop_declarations')
      .select('area_ha, barangay')
      .eq('status', 'approved');
  double totalArea = 0;
  final Map<String, double> brgyAreaMap = {};
  for (var row in areaRes as List) {
    final area = (row['area_ha'] as num).toDouble();
    final brgy = row['barangay'] as String? ?? 'Unknown';
    totalArea += area;
    brgyAreaMap[brgy] = (brgyAreaMap[brgy] ?? 0) + area;
  }

  // 3. Total farmers
  final farmersRes = await supabase.from('profiles').select('full_name').eq('role', 'farmer');
  final totalFarmers = (farmersRes as List).length;
  final List<String> farmersList = farmersRes.map((e) => e['full_name']?.toString() ?? 'Unknown').toList();

  // 5. Barangay stats for heatmap
  final brgyRes = await supabase
      .from('crop_declarations')
      .select('barangay, farmer_id, area_ha, crop_id')
      .eq('status', 'approved');

  final Map<String, Set<String>> brgyFarmers = {};
  final Map<String, double> brgyArea = {};
  final Map<String, Map<String, int>> brgyCropsCount = {};
  final Map<String, Set<String>> cropToBarangays = {};

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
    cropToBarangays.putIfAbsent(cropName, () => {}).add(brgy);
  }

  // 4. Oversupply crops logic
  String oversupplyRiskLevel = 'Low';
  Color oversupplyRiskColor = AppColors.information;
  List<String> oversupplyCrops = [];
  int maxBarangaysForCrop = 0;

  for (var entry in cropToBarangays.entries) {
    int count = entry.value.length;
    if (count > maxBarangaysForCrop) {
      maxBarangaysForCrop = count;
    }
  }

  if (maxBarangaysForCrop >= 7) {
    oversupplyRiskLevel = 'High';
    oversupplyRiskColor = AppColors.danger;
    oversupplyCrops = cropToBarangays.entries.where((e) => e.value.length >= 7).map((e) => e.key).toList();
  } else if (maxBarangaysForCrop >= 5) {
    oversupplyRiskLevel = 'Medium';
    oversupplyRiskColor = AppColors.warning;
    oversupplyCrops = cropToBarangays.entries.where((e) => e.value.length >= 5).map((e) => e.key).toList();
  } else {
    oversupplyRiskLevel = 'Low';
    oversupplyRiskColor = AppColors.primary;
    oversupplyCrops = ['None'];
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
      totalArea: brgyArea[brgy]!,
      topCrop: topCrop,
      riskColor: rColor,
      allCropsPlanted: brgyCropsCount[brgy]?.keys.toList() ?? [],
    ));
  }
  barangayStats.sort((a, b) => b.totalArea.compareTo(a.totalArea));

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
    pendingDeclarations: pendingCount,
    totalArea: totalArea,
    totalFarmers: totalFarmers,
    oversupplyCrops: oversupplyCrops,
    oversupplyRiskLevel: oversupplyRiskLevel,
    oversupplyRiskColor: oversupplyRiskColor,
    barangayStats: barangayStats,
    recentActivities: recentActivities,
    pendingDeclarationsList: pendingList,
    farmersList: farmersList,
    totalAreaByBarangay: brgyAreaMap,
  );
});

final farmersTableProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final res = await supabase
      .from('profiles')
      .select('id, full_name, barangay, contact_number, farms(total_area_ha), crop_declarations(crop_id, barangay, area_ha, created_at, status)')
      .eq('role', 'farmer');

  return List<Map<String, dynamic>>.from(res as List);
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  BarangayStats? _selectedBarangay;
  String? _selectedFarmerId;

  late MapZoomPanBehavior _zoomPanBehavior;

  @override
  void initState() {
    super.initState();
    _zoomPanBehavior = MapZoomPanBehavior(
      zoomLevel: 12,
      focalLatLng: const MapLatLng(10.826, 122.285), // Approximate center of Tubungan
      enableDoubleTapZooming: true,
      enableMouseWheelZooming: true,
      enablePinching: true,
    );
  }

  void _showDetailsDialog(BuildContext context, String title, List<String> items) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: AppColors.card,
          child: Container(
            width: 400,
            constraints: const BoxConstraints(maxHeight: 600),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: AppColors.text))),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.secondaryText),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.border),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: Center(child: Text('No details available.', style: TextStyle(color: AppColors.secondaryText))),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1),
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(items[index], style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w500)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.background,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.border)
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Close Details', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
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
                    title: 'Pending Declarations',
                    value: '${stats.pendingDeclarations}',
                    subtitle: '+12 today',
                    valueColor: AppColors.warning,
                    onTap: () {
                      final items = stats.pendingDeclarationsList.map((e) => '${e['farmer']} - ${e['crop']} (${e['area']} ha)').toList();
                      _showDetailsDialog(context, 'Pending Declarations', items);
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
                    title: 'Total Area',
                    value: '${stats.totalArea.toStringAsFixed(0)} ha',
                    subtitle: 'Current Season',
                    valueColor: AppColors.information,
                    onTap: () {
                      final list = stats.totalAreaByBarangay.entries.map((e) => '${e.key}: ${e.value.toStringAsFixed(1)} ha').toList();
                      _showDetailsDialog(context, 'Total Area by Barangay', list);
                    }
                  )),
                  const SizedBox(width: 24),
                  Expanded(child: _buildHoverCard(
                    title: 'Oversupply Risk',
                    value: stats.oversupplyRiskLevel,
                    subtitle: stats.oversupplyCrops.join(', '),
                    valueColor: stats.oversupplyRiskColor,
                    onTap: () {
                      _showDetailsDialog(context, 'Oversupply Crops', stats.oversupplyCrops);
                    }
                  )),
                ],
              ),
              const SizedBox(height: 32),

              // HEATMAP SECTION
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 500,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Barangay Heatmap', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                          const Text('Total declared area distribution across barangays', style: TextStyle(color: AppColors.secondaryText, fontSize: 14)),
                          const SizedBox(height: 24),
                          Expanded(
                            child: SfMaps(
                              layers: [
                                MapShapeLayer(
                                  source: const MapShapeSource.asset(
                                    'assets/Tubungan.geojson',
                                    shapeDataField: 'ADM3_EN', 
                                  ),
                                  color: AppColors.background, 
                                  strokeColor: AppColors.border, 
                                  strokeWidth: 2.0,
                                  zoomPanBehavior: _zoomPanBehavior,
                                  sublayers: [
                                    MapShapeSublayer(
                                      source: MapShapeSource.asset(
                                        'assets/TubunganBarangaysFiltered.geojson',
                                        shapeDataField: 'adm4_en', // Changed from Brgy_Name to adm4_en
                                        dataCount: stats.barangayStats.length,
                                        primaryValueMapper: (int index) => stats.barangayStats[index].name,
                                        shapeColorValueMapper: (int index) => stats.barangayStats[index].totalArea,
                                        shapeColorMappers: [
                                          const MapColorMapper(from: 0, to: 50, color: Color(0xFFC8E6C9)), // Light green
                                          const MapColorMapper(from: 51, to: 200, color: Color(0xFF81C784)),
                                          const MapColorMapper(from: 201, to: 500, color: Color(0xFF4CAF50)),
                                          const MapColorMapper(from: 501, to: 1000, color: Color(0xFF388E3C)),
                                          const MapColorMapper(from: 1001, to: 10000, color: Color(0xFF1B5E20)), // Dark green
                                        ],
                                      ),
                                      color: AppColors.background.withValues(alpha: 0.5), // Transparent for no-data
                                      strokeColor: Colors.grey.withValues(alpha: 0.5), // Inner barangay borders
                                      strokeWidth: 1.0,
                                      showDataLabels: true,
                                      dataLabelSettings: const MapDataLabelSettings(
                                        textStyle: TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                      shapeTooltipBuilder: (BuildContext context, int index) {
                                        final brgy = stats.barangayStats[index];
                                        return Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(brgy.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.text, fontSize: 14)),
                                              const SizedBox(height: 4),
                                              Text('Total Area: ${brgy.totalArea.toStringAsFixed(1)} ha', style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                                              Text('Farmers: ${brgy.farmers}', style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                  legend: const MapLegend(MapElement.shape),
                                  tooltipSettings: const MapTooltipSettings(
                                    color: AppColors.card,
                                    strokeColor: AppColors.border,
                                    strokeWidth: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // MAP & QUEUE
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Baranggay Information
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Baranggay Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                          const SizedBox(height: 24),
                          Builder(
                            builder: (context) {
                              final currentBarangay = _selectedBarangay ?? (stats.barangayStats.isNotEmpty ? stats.barangayStats.first : null);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonFormField<BarangayStats>(
                                    decoration: InputDecoration(
                                      labelText: 'Select Barangay',
                                      labelStyle: const TextStyle(color: AppColors.secondaryText),
                                      prefixIcon: const Icon(Icons.location_city_outlined, color: AppColors.primary),
                                      filled: true,
                                      fillColor: AppColors.background,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(color: AppColors.border),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(color: AppColors.border),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    ),
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                                    style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600),
                                    dropdownColor: AppColors.card,
                                    borderRadius: BorderRadius.circular(16),
                                    value: currentBarangay,
                                    items: stats.barangayStats.map((brgy) {
                                      return DropdownMenuItem(
                                        value: brgy,
                                        child: Text(brgy.name),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedBarangay = val;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  const Divider(),
                                  const SizedBox(height: 24),
                                  if (currentBarangay == null)
                                    const Center(child: Padding(
                                      padding: EdgeInsets.all(32.0),
                                      child: Text('No barangay data available.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.secondaryText)),
                                    ))
                                  else
                                    Row(
                                      key: ValueKey(currentBarangay.name),
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildBrgyDetail('Farmers', '${currentBarangay.farmers}', Icons.people_outline),
                                              _buildBrgyDetail('Total Area', '${currentBarangay.totalArea.toStringAsFixed(1)} ha', Icons.location_on_outlined),
                                              _buildBrgyDetail('Yield Trend', 'Increasing', Icons.trending_up),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildBrgyDetail('Top Crop', currentBarangay.topCrop, Icons.eco_outlined),
                                              _buildBrgyDetail('All Crops Planted', currentBarangay.allCropsPlanted.isEmpty ? 'None' : currentBarangay.allCropsPlanted.join(', '), Icons.list_alt_outlined),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              );
                            }
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  
                  // Validation Queue Cards
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Available Harvest', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                            TextButton(onPressed: (){}, child: const Text('View All'))
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (stats.pendingDeclarationsList.isEmpty)
                          const Padding(padding: EdgeInsets.all(32), child: Text('No available harvest.', style: TextStyle(color: AppColors.secondaryText))),
                        ...stats.pendingDeclarationsList.map((item) => Container(
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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['crop'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text('${item['farmer']} - ${item['barangay']}', style: const TextStyle(fontSize: 13, color: AppColors.secondaryText), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                    child: const Text('Harvested', style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
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
                                      BarChartRodData(toY: entry.value.totalArea, color: AppColors.primary, width: 24, borderRadius: BorderRadius.circular(4)),
                                      BarChartRodData(toY: entry.value.totalArea * 1.2, color: AppColors.border, width: 24, borderRadius: BorderRadius.circular(4)),
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
              ),
              const SizedBox(height: 32),
              
              // Bottom charts (omitted farmers table)
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.danger))),
    );
  }

  Widget _buildFarmersTable() {
    final farmersAsync = ref.watch(farmersTableProvider);
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Registered Farmers Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          const SizedBox(height: 24),
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
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
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
                  const SizedBox(height: 24),
                  
                  // Main Content Area
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LEFT: Farmer Information
                      Expanded(
                        flex: 1,
                        child: Container(
                          height: 450,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                child: Text((selectedFarmer['full_name'] ?? 'U')[0].toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              ),
                              const SizedBox(height: 16),
                              Text(selectedFarmer['full_name'] ?? 'Unknown', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 24),
                              _buildBrgyDetail('Barangay', selectedFarmer['barangay'] ?? 'N/A', Icons.location_on_outlined),
                              _buildBrgyDetail('Contact', selectedFarmer['contact_number'] ?? 'N/A', Icons.phone_outlined),
                              Builder(
                                builder: (context) {
                                  final farms = selectedFarmer['farms'] as List<dynamic>? ?? [];
                                  double totalArea = 0;
                                  for (var f in farms) {
                                    totalArea += (f['total_area_ha'] as num?)?.toDouble() ?? 0;
                                  }
                                  return _buildBrgyDetail('Total Farm Area', '$totalArea ha', Icons.landscape_outlined);
                                }
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // RIGHT: Planted Crops List
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 450,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
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
                                      return dateB.compareTo(dateA); // Latest first
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
                      )
                    ],
                  )
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Error loading farmers: $err'),
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

  Widget _buildBrgyDetail(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.text), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
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
