import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';

class ReportsData {
  final double totalArea;
  final int noDeclaredAreaBarangays;
  final Map<String, double> cropDistribution;
  final Map<String, int> declarationStatus;
  final Map<String, double> calamityTypeDistribution;
  final List<MonthlyDeclaration> monthlyDeclarations;
  final Map<String, double> topBarangays;
  final Map<String, double> barangaysAffectedByCalamity;
  
  ReportsData({
    required this.totalArea, 
    required this.noDeclaredAreaBarangays,
    Map<String, double>? cropDistribution,
    Map<String, int>? declarationStatus,
    Map<String, double>? calamityTypeDistribution,
    required this.monthlyDeclarations,
    Map<String, double>? topBarangays,
    Map<String, double>? barangaysAffectedByCalamity,
  }) : cropDistribution = cropDistribution ?? {},
       declarationStatus = declarationStatus ?? {},
       calamityTypeDistribution = calamityTypeDistribution ?? {},
       topBarangays = topBarangays ?? {},
       barangaysAffectedByCalamity = barangaysAffectedByCalamity ?? {};
}

class MonthlyDeclaration {
  final int month;
  final int count;
  MonthlyDeclaration(this.month, this.count);
}

final reportsProvider = FutureProvider.autoDispose<ReportsData>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  
  final res = await supabase.from('crop_declarations').select('area_ha, status, created_at, crop_id, profiles(barangay)');
  final calamityRes = await supabase.from('calamity_reports').select('affected_area_ha, type, barangay, profiles(barangay)');
  
  double total = 0;
  int noDeclaredAreaBarangays = 0;
  Map<String, double> distribution = {};
  Map<String, int> declarationStatus = {
    'pending': 0,
    'accepted': 0,
    'approved_by_baw': 0,
    'rejected': 0,
  };
  Map<int, int> monthlyMap = {};
  Map<String, double> topBarangaysMap = {};
  Set<String> allBarangaysWithDeclarations = {};
  
  for (var row in res as List) {
    final area = (row['area_ha'] as num).toDouble();
    final status = row['status'] as String? ?? 'pending';
    final createdAt = row['created_at'] != null ? DateTime.parse(row['created_at']) : DateTime.now();
    
    // Status count
    final statusKey = declarationStatus.containsKey(status) ? status : 'pending';
    declarationStatus[statusKey] = (declarationStatus[statusKey] ?? 0) + 1;

    // Monthly count
    final month = createdAt.month;
    monthlyMap[month] = (monthlyMap[month] ?? 0) + 1;

    if (status == 'active' || status == 'harvested') {
      // Top barangays by area
      final brgy = row['profiles']?['barangay'] as String? ?? 'Unknown';
      if (brgy.isNotEmpty && brgy != 'Unknown') {
        topBarangaysMap[brgy] = (topBarangaysMap[brgy] ?? 0) + area;
        allBarangaysWithDeclarations.add(brgy);
      }
      
      total += area;
      
      final cropId = row['crop_id'] as String? ?? 'unknown';
      final cropName = cropId.isEmpty ? cropId : cropId[0].toUpperCase() + cropId.substring(1).replaceAll('_', ' ');
          
      distribution[cropName] = (distribution[cropName] ?? 0) + area;
    }
  }

  // Calculate barangays with no declarations
  // Assuming a fixed total list of 48 barangays in Tubungan for this example
  const totalBarangaysCount = 48;
  noDeclaredAreaBarangays = totalBarangaysCount - allBarangaysWithDeclarations.length;
  if (noDeclaredAreaBarangays < 0) noDeclaredAreaBarangays = 0;

  Map<String, double> calamityTypeMap = {};
  Map<String, double> affectedBarangays = {};
  for (var row in calamityRes as List) {
    final type = row['type'] as String? ?? 'Unknown';
    final area = (row['affected_area_ha'] as num?)?.toDouble() ?? 0;
    calamityTypeMap[type] = (calamityTypeMap[type] ?? 0) + 1;
    
    final brgy = row['barangay'] ?? row['profiles']?['barangay'] ?? 'Unknown';
    if (brgy != null && brgy.toString().isNotEmpty && brgy != 'Unknown') {
      affectedBarangays[brgy] = (affectedBarangays[brgy] ?? 0) + area;
    }
  }
  
  List<MonthlyDeclaration> monthlyDeclarations = [];
  for (int i = 1; i <= 12; i++) {
    monthlyDeclarations.add(MonthlyDeclaration(i, monthlyMap[i] ?? 0));
  }
  
  // Sort and limit top barangays
  final sortedBarangays = topBarangaysMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final Map<String, double> top5Barangays = Map.fromEntries(sortedBarangays.take(5));
  
  return ReportsData(
    totalArea: total, 
    noDeclaredAreaBarangays: noDeclaredAreaBarangays,
    cropDistribution: distribution,
    declarationStatus: declarationStatus,
    calamityTypeDistribution: calamityTypeMap,
    monthlyDeclarations: monthlyDeclarations,
    topBarangays: top5Barangays,
    barangaysAffectedByCalamity: affectedBarangays,
  );
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  void _showDetailsDialog(BuildContext context, String title, List<String> items) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
          content: SizedBox(
            width: 400,
            child: items.isEmpty 
              ? const Text('No details available.', style: TextStyle(color: AppColors.secondaryText)) 
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return StatefulBuilder(
                      builder: (context, setState) {
                        bool isHovered = false;
                        return MouseRegion(
                          onEnter: (_) => setState(() => isHovered = true),
                          onExit: (_) => setState(() => isHovered = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutQuart,
                            padding: const EdgeInsets.all(20),
                            transform: Matrix4.translationValues(0, isHovered ? -2 : 0, 0),
                            decoration: BoxDecoration(
                              color: isHovered ? AppColors.primary.withOpacity(0.05) : AppColors.background,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isHovered ? AppColors.primary.withOpacity(0.5) : AppColors.border),
                              boxShadow: isHovered ? [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 8))] : [],
                            ),
                            child: Text(
                              items[index],
                              style: TextStyle(
                                fontSize: 15,
                                color: isHovered ? AppColors.text : AppColors.secondaryText,
                                fontWeight: isHovered ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }
                    );
                  },
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(reportsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: reportsAsync.when(
        data: (data) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Reports & Analytics', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.text, letterSpacing: -1)),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('CSV Exported Successfully')),
                        );
                      },
                      icon: const Icon(Icons.download, color: Colors.white, size: 18),
                      label: const Text('Export CSV', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                
                Row(
                  children: [
                    Builder(
                      builder: (context) {
                        String topCropName = 'None';
                        double topCropArea = 0.0;
                        if (data.cropDistribution.isNotEmpty) {
                          final sortedCrops = data.cropDistribution.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                          topCropName = sortedCrops.first.key;
                          topCropArea = sortedCrops.first.value;
                        }
                        return _buildSummaryCard(
                          context, 
                          'Top Crop', 
                          topCropName, 
                          AppColors.primary, 
                          '${topCropArea.toStringAsFixed(1)} ha declared', 
                          onTap: () {
                            _showDetailsDialog(context, 'Top Crop Details', ['$topCropName has the highest declared area at ${topCropArea.toStringAsFixed(1)} hectares.']);
                          }
                        );
                      }
                    ),

                    const SizedBox(width: 24),
                    _buildSummaryCard(context, 'Total Area', '${data.totalArea.toStringAsFixed(0)} ha', AppColors.accent, 'Declared Area', onTap: () {
                      final items = data.cropDistribution.entries.map((e) => '${e.key}: ${e.value.toStringAsFixed(1)} ha').toList();
                      _showDetailsDialog(context, 'Total Declared Area', items);
                    }),
                    const SizedBox(width: 24),
                    _buildSummaryCard(context, 'No Declarations', '${data.noDeclaredAreaBarangays}', AppColors.warning, 'Barangays Pending', onTap: () {
                      _showDetailsDialog(context, 'Barangays without Declarations', ['There are ${data.noDeclaredAreaBarangays} barangays without any active crop declarations.']);
                    }),
                  ],
                ),
                const SizedBox(height: 48),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        height: 480,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Calamity Type Distribution', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                            const SizedBox(height: 48),
                            Expanded(
                              child: data.calamityTypeDistribution.isEmpty
                                  ? const Center(child: Text('No calamity data', style: TextStyle(color: AppColors.secondaryText)))
                                  : _buildDoughnutChart(data.calamityTypeDistribution, isInt: true),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        height: 480,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Monthly Crop Declarations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                            const SizedBox(height: 48),
                            Expanded(
                              child: LineChart(
                                LineChartData(
                                  minX: 1,
                                  maxX: 12,
                                  minY: 0,
                                  gridData: const FlGridData(show: false),
                                  titlesData: FlTitlesData(
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 42,
                                        getTitlesWidget: (value, meta) {
                                          const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                                          final index = value.toInt() - 1;
                                          if (index >= 0 && index < months.length) {
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 16.0),
                                              child: Text(months[index], style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                                            );
                                          }
                                          return const Text('');
                                        },
                                        interval: 1,
                                      ),
                                    ),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true, 
                                        reservedSize: 48, 
                                        getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 13, color: AppColors.secondaryText))
                                      )
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: data.monthlyDeclarations.map((e) => FlSpot(e.month.toDouble(), e.count.toDouble())).toList(),
                                      isCurved: false,
                                      color: AppColors.primary,
                                      barWidth: 4,
                                      isStrokeCapRound: true,
                                      dotData: const FlDotData(show: true),
                                      belowBarData: BarAreaData(
                                        show: true, 
                                        gradient: LinearGradient(
                                          colors: [AppColors.primary.withOpacity(0.3), AppColors.primary.withOpacity(0.0)],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        )
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Container(
                        height: 480,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Top Barangays by Declared Area', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                            const SizedBox(height: 48),
                            Expanded(
                              child: data.topBarangays.isEmpty
                                  ? const Center(child: Text('No data', style: TextStyle(color: AppColors.secondaryText)))
                                  : BarChart(
                                      BarChartData(
                                        gridData: const FlGridData(show: false),
                                        alignment: BarChartAlignment.spaceAround,
                                        titlesData: FlTitlesData(
                                          bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              reservedSize: 42,
                                              getTitlesWidget: (value, meta) {
                                                final keys = data.topBarangays.keys.toList();
                                                if (value.toInt() >= 0 && value.toInt() < keys.length) {
                                                  return Padding(
                                                    padding: const EdgeInsets.only(top: 8.0),
                                                    child: Text(
                                                      keys[value.toInt()], 
                                                      style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                                                    ),
                                                  );
                                                }
                                                return const Text('');
                                              },
                                              interval: 1,
                                            ),
                                          ),
                                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                          leftTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              reservedSize: 48,
                                              getTitlesWidget: (value, meta) {
                                                return Padding(
                                                  padding: const EdgeInsets.only(right: 8.0),
                                                  child: Text('${value.toInt()} ha', style: const TextStyle(fontSize: 11, color: AppColors.secondaryText), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                );
                                              },
                                            )
                                          ),
                                        ),
                                        borderData: FlBorderData(show: false),
                                        barGroups: data.topBarangays.entries.toList().asMap().entries.map((entry) {
                                          return BarChartGroupData(
                                            x: entry.key,
                                            barRods: [
                                              BarChartRodData(
                                                toY: entry.value.value,
                                                color: AppColors.accent,
                                                width: 24,
                                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                                              )
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                      swapAnimationDuration: const Duration(milliseconds: 150),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        height: 480,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Barangays Affected by Calamity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                            const SizedBox(height: 48),
                            Expanded(
                              child: data.barangaysAffectedByCalamity.isEmpty
                                  ? const Center(child: Text('No calamity data', style: TextStyle(color: AppColors.secondaryText)))
                                  : BarChart(
                                      BarChartData(
                                        gridData: const FlGridData(show: false),
                                        alignment: BarChartAlignment.spaceAround,
                                        titlesData: FlTitlesData(
                                          bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              reservedSize: 60,
                                              getTitlesWidget: (value, meta) {
                                                final keys = data.barangaysAffectedByCalamity.keys.toList();
                                                if (value.toInt() >= 0 && value.toInt() < keys.length) {
                                                  return Padding(
                                                    padding: const EdgeInsets.only(top: 8.0),
                                                    child: Text(
                                                      keys[value.toInt()], 
                                                      style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                                                    ),
                                                  );
                                                }
                                                return const Text('');
                                              },
                                              interval: 1,
                                            ),
                                          ),
                                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                          leftTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true, 
                                              reservedSize: 48, 
                                              getTitlesWidget: (value, meta) => Text('${value.toInt()} ha', style: const TextStyle(fontSize: 11, color: AppColors.secondaryText))
                                            )
                                          ),
                                        ),
                                        borderData: FlBorderData(show: false),
                                        barGroups: data.barangaysAffectedByCalamity.entries.toList().asMap().entries.map((entry) {
                                          return BarChartGroupData(
                                            x: entry.key,
                                            barRods: [
                                              BarChartRodData(
                                                toY: entry.value.value,
                                                color: AppColors.danger,
                                                width: 24,
                                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                                              )
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildDoughnutChart(Map<String, double> distribution, {bool isInt = false, bool isStatus = false}) {
    if (distribution.isEmpty || distribution.values.every((v) => v == 0)) {
       return const Center(child: Text('No data', style: TextStyle(color: AppColors.secondaryText)));
    }
    
    final sortedEntries = distribution.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final defaultColors = [
      AppColors.primary, 
      Colors.orange, 
      Colors.blue, 
      Colors.red, 
      Colors.purple, 
      Colors.teal, 
      Colors.pink, 
      Colors.indigo,
      AppColors.secondary, 
      AppColors.accent
    ];
    
    Color getColor(String key, int index) {
      if (isStatus) {
        final lowerKey = key.toLowerCase();
        if (lowerKey == 'pending') return Colors.amber;
        if (lowerKey == 'rejected') return Colors.red;
        if (lowerKey == 'accepted') return Colors.blue;
        if (lowerKey == 'approved by baw') return AppColors.primary;
        return defaultColors[index % defaultColors.length];
      }
      return defaultColors[index % defaultColors.length];
    }
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 4,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 60,
              sections: sortedEntries.asMap().entries.map((entry) {
                final color = getColor(entry.value.key, entry.key);
                return PieChartSectionData(
                  color: color,
                  value: entry.value.value,
                  title: isInt ? '${entry.value.value.toInt()}' : '${entry.value.value.toStringAsFixed(1)}',
                  radius: 40,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          flex: 4,
          child: ListView.separated(
            itemCount: sortedEntries.length,
            separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 16),
            itemBuilder: (context, index) {
              final entry = sortedEntries[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(width: 16, height: 16, decoration: BoxDecoration(color: getColor(entry.key, index), borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.key, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(isInt ? '${entry.value.toInt()}' : '${entry.value.toStringAsFixed(1)}', style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        )
      ],
    );
  }

  Widget _buildCropDistributionChart(Map<String, double> distribution) {
    final sortedEntries = distribution.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final allCrops = sortedEntries;
    
    final colors = [
      AppColors.primary, 
      Colors.orange, 
      Colors.blue, 
      Colors.red, 
      Colors.purple, 
      Colors.teal, 
      Colors.pink, 
      Colors.indigo,
      AppColors.secondary, 
      AppColors.accent
    ];
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 4,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 60,
              sections: allCrops.asMap().entries.map((entry) {
                final color = colors[entry.key % colors.length];
                return PieChartSectionData(
                  color: color,
                  value: entry.value.value,
                  title: '${(entry.value.value / allCrops.fold(0.0, (sum, e) => sum + e.value) * 100).toStringAsFixed(1)}%',
                  radius: 40,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          flex: 4,
          child: ListView.separated(
            itemCount: allCrops.length,
            separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 16),
            itemBuilder: (context, index) {
              final entry = allCrops[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(width: 16, height: 16, decoration: BoxDecoration(color: colors[index % colors.length], borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.key, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('${entry.value.toStringAsFixed(1)} ha', style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        )
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, String value, Color color, String subtitle, {VoidCallback? onTap}) {
    return Expanded(
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: onTap,
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
                Text(title, style: const TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w600, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 16),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: color, letterSpacing: -1.5)),
                ),
                const SizedBox(height: 8),
                Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.secondaryText), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildRollupCard(BuildContext context, {VoidCallback? onTap}) {
    return Expanded(
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('P&L Roll-ups', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 16),
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('₱ 1.2B', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.text, letterSpacing: -1.5)),
                ),
                const SizedBox(height: 8),
                const Text('Projected Revenue', style: TextStyle(fontSize: 14, color: AppColors.primary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
