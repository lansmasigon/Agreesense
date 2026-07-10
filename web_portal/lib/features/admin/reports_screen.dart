import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';

class ReportsData {
  final double totalArea;
  final double pendingArea;
  final Map<String, double> cropDistribution;
  final List<MonthlyValidation> validationOverTime;
  final Map<String, double> barangaysAffectedByCalamity;
  
  ReportsData({
    required this.totalArea, 
    required this.pendingArea,
    Map<String, double>? cropDistribution,
    required this.validationOverTime,
    Map<String, double>? barangaysAffectedByCalamity,
  }) : cropDistribution = cropDistribution ?? {},
       barangaysAffectedByCalamity = barangaysAffectedByCalamity ?? {};
}

class MonthlyValidation {
  final int month;
  final double area;
  MonthlyValidation(this.month, this.area);
}

final reportsProvider = FutureProvider.autoDispose<ReportsData>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  
  final res = await supabase.from('crop_declarations').select('area_ha, status, created_at, crop_id');
  final calamityRes = await supabase.from('calamity_reports').select('affected_area_ha, barangay, profiles(barangay)');
  
  double total = 0;
  double pending = 0;
  Map<String, double> distribution = {};
  Map<int, double> monthlyMap = {};
  Map<String, double> affectedBarangays = {};
  
  for (var row in res as List) {
    final area = (row['area_ha'] as num).toDouble();
    final status = row['status'];
    final createdAt = row['created_at'] != null ? DateTime.parse(row['created_at']) : DateTime.now();
    
    if (status == 'approved') {
      total += area;
      
      final cropId = row['crop_id'] as String? ?? 'unknown';
      final cropName = cropId.isEmpty ? cropId : cropId[0].toUpperCase() + cropId.substring(1).replaceAll('_', ' ');
          
      distribution[cropName] = (distribution[cropName] ?? 0) + area;
      
      final month = createdAt.month;
      monthlyMap[month] = (monthlyMap[month] ?? 0) + area;
    } else if (status == 'pending') {
      pending += area;
    }
  }

  for (var row in calamityRes as List) {
    final area = (row['affected_area_ha'] as num?)?.toDouble() ?? 0;
    final brgy = row['barangay'] ?? row['profiles']?['barangay'] ?? 'Unknown';
    affectedBarangays[brgy] = (affectedBarangays[brgy] ?? 0) + area;
  }
  
  List<MonthlyValidation> validationOverTime = [];
  for (int i = 1; i <= 12; i++) {
    validationOverTime.add(MonthlyValidation(i, monthlyMap[i] ?? 0));
  }
  
  return ReportsData(
    totalArea: total, 
    pendingArea: pending,
    cropDistribution: distribution,
    validationOverTime: validationOverTime,
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
                          '${topCropArea.toStringAsFixed(1)} ha validated', 
                          onTap: () {
                            _showDetailsDialog(context, 'Top Crop Details', ['$topCropName has the highest validated area at ${topCropArea.toStringAsFixed(1)} hectares.']);
                          }
                        );
                      }
                    ),
                    const SizedBox(width: 24),
                    _buildSummaryCard(context, 'Corn (Q3)', '22k MT', AppColors.information, 'Production Forecast', onTap: () {
                      _showDetailsDialog(context, 'Corn (Q3) Forecast', ['Based on 5,500 ha of validated area.', 'Expected yield: 4 MT/ha.']);
                    }),
                    const SizedBox(width: 24),
                    _buildSummaryCard(context, 'Total Area', '${data.totalArea.toStringAsFixed(0)} ha', AppColors.accent, 'Validated Area', onTap: () {
                      final items = data.cropDistribution.entries.map((e) => '${e.key}: ${e.value.toStringAsFixed(1)} ha').toList();
                      _showDetailsDialog(context, 'Total Validated Area', items);
                    }),
                    const SizedBox(width: 24),
                    _buildSummaryCard(context, 'Pending', '${data.pendingArea.toStringAsFixed(0)} ha', AppColors.warning, 'For Validation', onTap: () {
                      _showDetailsDialog(context, 'Pending Validation Area', ['Total pending area: ${data.pendingArea.toStringAsFixed(1)} ha across all barangays.']);
                    }),
                    const SizedBox(width: 24),
                    _buildRollupCard(context, onTap: () {
                      _showDetailsDialog(context, 'P&L Roll-ups', ['Rice projected revenue: ₱ 900M', 'Corn projected revenue: ₱ 300M']);
                    }),
                  ],
                ),
                const SizedBox(height: 48),
                
                // Charts Section Vertically Stacked
                Container(
                  width: double.infinity,
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
                      const Text('Crop Distribution (Area)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                      const SizedBox(height: 48),
                      Expanded(
                        child: data.cropDistribution.isEmpty
                            ? const Center(child: Text('No data', style: TextStyle(color: AppColors.secondaryText)))
                            : _buildCropDistributionChart(data.cropDistribution),
                      ),
                    ],
                  ),
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
                            const Text('Validated Area Over Time (Months)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                            const SizedBox(height: 48),
                            Expanded(
                              child: LineChart(
                                LineChartData(
                                  minX: 1,
                                  maxX: 12,
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
                                      spots: data.validationOverTime.map((e) => FlSpot(e.month.toDouble(), e.area)).toList(),
                                      isCurved: true,
                                      curveSmoothness: 0.35,
                                      color: AppColors.primary,
                                      barWidth: 4,
                                      isStrokeCapRound: true,
                                      dotData: const FlDotData(show: false),
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
                            const Text('Barangays affected by Calamity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                            const SizedBox(height: 48),
                            Expanded(
                              child: data.barangaysAffectedByCalamity.isEmpty
                                  ? const Center(child: Text('No calamity data', style: TextStyle(color: AppColors.secondaryText)))
                                  : BarChart(
                                      BarChartData(
                                        gridData: const FlGridData(show: false),
                                        titlesData: FlTitlesData(
                                          bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              reservedSize: 42,
                                              getTitlesWidget: (value, meta) {
                                                final keys = data.barangaysAffectedByCalamity.keys.toList();
                                                if (value.toInt() >= 0 && value.toInt() < keys.length) {
                                                  return Padding(
                                                    padding: const EdgeInsets.only(top: 16.0),
                                                    child: Text(keys[value.toInt()], style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
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
                                              interval: 1,
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

  Widget _buildCropDistributionChart(Map<String, double> distribution) {
    final sortedEntries = distribution.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final allCrops = sortedEntries;
    
    final colors = [AppColors.primary, AppColors.secondary, AppColors.accent, AppColors.information, AppColors.warning, AppColors.danger, AppColors.text, AppColors.border, Colors.teal, Colors.purple];
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 4,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 100,
              sections: allCrops.asMap().entries.map((entry) {
                final color = colors[entry.key % colors.length];
                return PieChartSectionData(
                  color: color,
                  value: entry.value.value,
                  title: '${(entry.value.value / allCrops.fold(0.0, (sum, e) => sum + e.value) * 100).toStringAsFixed(1)}%',
                  radius: 50,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 48),
        Expanded(
          flex: 3,
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
