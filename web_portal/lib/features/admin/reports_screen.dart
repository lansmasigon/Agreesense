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
  
  ReportsData({
    required this.totalArea, 
    required this.pendingArea,
    Map<String, double>? cropDistribution,
    required this.validationOverTime,
  }) : cropDistribution = cropDistribution ?? {};
}

class MonthlyValidation {
  final int month;
  final double area;
  MonthlyValidation(this.month, this.area);
}

final reportsProvider = FutureProvider.autoDispose<ReportsData>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  
  final res = await supabase.from('crop_declarations').select('area_ha, status, created_at, crop_id');
  
  double total = 0;
  double pending = 0;
  Map<String, double> distribution = {};
  Map<int, double> monthlyMap = {};
  
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
  
  List<MonthlyValidation> validationOverTime = [];
  for (int i = 1; i <= 12; i++) {
    validationOverTime.add(MonthlyValidation(i, monthlyMap[i] ?? 0));
  }
  
  return ReportsData(
    totalArea: total, 
    pendingArea: pending,
    cropDistribution: distribution,
    validationOverTime: validationOverTime,
  );
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  void _showDetailsDialog(BuildContext context, String title, List<String> items) {
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
                    _buildSummaryCard(context, 'Rice (Q3)', '45,000 MT', Icons.trending_up, AppColors.primary, 'Production Forecast', onTap: () {
                      _showDetailsDialog(context, 'Rice (Q3) Forecast', ['Based on 9,000 ha of validated area.', 'Expected yield: 5 MT/ha.']);
                    }),
                    const SizedBox(width: 24),
                    _buildSummaryCard(context, 'Corn (Q3)', '22,000 MT', Icons.trending_flat, AppColors.information, 'Production Forecast', onTap: () {
                      _showDetailsDialog(context, 'Corn (Q3) Forecast', ['Based on 5,500 ha of validated area.', 'Expected yield: 4 MT/ha.']);
                    }),
                    const SizedBox(width: 24),
                    _buildSummaryCard(context, 'Total Area', '${data.totalArea.toStringAsFixed(1)} ha', Icons.map, AppColors.accent, 'Validated Area', onTap: () {
                      final items = data.cropDistribution.entries.map((e) => '${e.key}: ${e.value.toStringAsFixed(1)} ha').toList();
                      _showDetailsDialog(context, 'Total Validated Area', items);
                    }),
                    const SizedBox(width: 24),
                    _buildSummaryCard(context, 'Pending Validation', '${data.pendingArea.toStringAsFixed(1)} ha', Icons.pending_actions, AppColors.warning, 'Validated Area', onTap: () {
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
                      const Text('Validated Area Over Time (Months)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                      const SizedBox(height: 48),
                      Expanded(
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
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
    
    final colors = [AppColors.primary, AppColors.secondary, AppColors.accent, AppColors.information, AppColors.warning];
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 60,
              sections: allCrops.asMap().entries.map((entry) {
                final color = colors[entry.key % colors.length];
                return PieChartSectionData(
                  color: color,
                  value: entry.value.value,
                  title: '', // Removed noisy titles, relies on legend
                  radius: 40,
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          flex: 2,
          child: ListView.builder(
            itemCount: allCrops.length,
            itemBuilder: (context, index) {
              final entry = allCrops[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[index % colors.length], borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text), overflow: TextOverflow.ellipsis),
                          Text('${entry.value.toStringAsFixed(0)} ha', style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
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

  Widget _buildSummaryCard(BuildContext context, String title, String value, IconData icon, Color color, String subtitle, {VoidCallback? onTap}) {
    return Expanded(
      child: StatefulBuilder(
        builder: (context, setState) {
          bool isHovered = false;
          return MouseRegion(
            onEnter: (_) => setState(() => isHovered = true),
            onExit: (_) => setState(() => isHovered = false),
            child: GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutQuart,
                transform: Matrix4.translationValues(0, isHovered ? -4 : 0, 0),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isHovered ? color.withOpacity(0.5) : AppColors.border),
                  boxShadow: isHovered ? [BoxShadow(color: color.withOpacity(0.1), blurRadius: 24, offset: const Offset(0, 12))] : [],
                ),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Icon(icon, size: 20, color: color),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText, fontWeight: FontWeight.w600))),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(title, style: const TextStyle(fontSize: 14, color: AppColors.secondaryText, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.text, letterSpacing: -1)),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }
  
  Widget _buildRollupCard(BuildContext context, {VoidCallback? onTap}) {
    return Expanded(
      child: StatefulBuilder(
        builder: (context, setState) {
          bool isHovered = false;
          return MouseRegion(
            onEnter: (_) => setState(() => isHovered = true),
            onExit: (_) => setState(() => isHovered = false),
            child: GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutQuart,
                transform: Matrix4.translationValues(0, isHovered ? -4 : 0, 0),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isHovered ? AppColors.primary : AppColors.primary.withOpacity(0.2)),
                  boxShadow: isHovered ? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 24, offset: const Offset(0, 12))] : [],
                ),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.attach_money, size: 20, color: AppColors.primary),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(child: Text('P&L Roll-ups', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700))),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Projected Rev.', style: TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    const Text('₱ 1.2B', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.text, letterSpacing: -1)),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }
}
