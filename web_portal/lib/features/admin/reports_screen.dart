import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/auth_provider.dart';

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
      backgroundColor: const Color(0xFFF9FCFA),
      appBar: AppBar(
        title: const Text('Reports & Analytics', style: TextStyle(color: Color(0xFF1E392A), fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF1E392A)),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV Exported Successfully')),
              );
            },
            icon: const Icon(Icons.download, color: Colors.white, size: 18),
            label: const Text('Export CSV', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32), // Green
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
      body: reportsAsync.when(
        data: (data) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: ListView(
              children: [
                const Text('Summary Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E392A))),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildSummaryCard(context, 'Rice (Q3)', '45,000 MT', Icons.trending_up, const Color(0xFF2E7D32), 'Production Forecast', onTap: () {
                      _showDetailsDialog(context, 'Rice (Q3) Forecast', ['Based on 9,000 ha of validated area.', 'Expected yield: 5 MT/ha.']);
                    }),
                    _buildSummaryCard(context, 'Corn (Q3)', '22,000 MT', Icons.trending_flat, const Color(0xFF4CAF50), 'Production Forecast', onTap: () {
                      _showDetailsDialog(context, 'Corn (Q3) Forecast', ['Based on 5,500 ha of validated area.', 'Expected yield: 4 MT/ha.']);
                    }),
                    _buildSummaryCard(context, 'Total Area', '${data.totalArea.toStringAsFixed(1)} ha', Icons.map, const Color(0xFF388E3C), 'Validated Area', onTap: () {
                      final items = data.cropDistribution.entries.map((e) => '${e.key}: ${e.value.toStringAsFixed(1)} ha').toList();
                      _showDetailsDialog(context, 'Total Validated Area', items);
                    }),
                    _buildSummaryCard(context, 'Pending Validation', '${data.pendingArea.toStringAsFixed(1)} ha', Icons.pending_actions, const Color(0xFF81C784), 'Validated Area', onTap: () {
                      _showDetailsDialog(context, 'Pending Validation Area', ['Total pending area: ${data.pendingArea.toStringAsFixed(1)} ha across all barangays.']);
                    }),
                    _buildRollupCard(context, onTap: () {
                      _showDetailsDialog(context, 'P&L Roll-ups', [
                        'Rice projected revenue: ₱ 900M',
                        'Corn projected revenue: ₱ 300M'
                      ]);
                    }),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Charts Section
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    Container(
                      width: _getChartWidth(context),
                      height: 400,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8))],
                        border: Border.all(color: Colors.grey.withOpacity(0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Crop Distribution (Area)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                          const SizedBox(height: 32),
                          Expanded(
                            child: data.cropDistribution.isEmpty
                                ? const Center(child: Text('No data', style: TextStyle(color: Colors.grey)))
                                : _buildCropDistributionChart(data.cropDistribution),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: _getChartWidth(context),
                      height: 400,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8))],
                        border: Border.all(color: Colors.grey.withOpacity(0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Validated Area Over Time (Months)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                          const SizedBox(height: 32),
                          Expanded(
                            child: LineChart(
                              LineChartData(
                                gridData: FlGridData(
                                  show: true, 
                                  drawVerticalLine: false, 
                                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)
                                ),
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                                        final index = value.toInt() - 1;
                                        if (index >= 0 && index < months.length) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 12.0),
                                            child: Text(months[index], style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
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
                                      getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500))
                                    )
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: data.validationOverTime.map((e) => FlSpot(e.month.toDouble(), e.area)).toList(),
                                    isCurved: true,
                                    color: const Color(0xFF10B981),
                                    barWidth: 4,
                                    isStrokeCapRound: true,
                                    dotData: const FlDotData(show: true),
                                    belowBarData: BarAreaData(
                                      show: true, 
                                      color: const Color(0xFF10B981).withOpacity(0.08)
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
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  double _getCardWidth(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (width > 1400) return (width - 290 - 48 - 64) / 5; // 5 cards
    if (width > 1100) return (width - 290 - 48 - 48) / 4; // 4 cards
    if (width > 800) return (width - 290 - 48 - 32) / 3; // 3 cards
    if (width > 600) return (width - 48 - 16) / 2;
    return width - 48;
  }

  double _getChartWidth(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double sidebar = width > 800 ? 290.0 : 0.0;
    double available = width - sidebar - 48;
    if (available > 1000) return (available - 24) / 2;
    return available;
  }

  Widget _buildCropDistributionChart(Map<String, double> distribution) {
    // Sort and get all
    final sortedEntries = distribution.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final allCrops = sortedEntries;
    
    final colors = [
      const Color(0xFF1B5E20), // Dark Green
      const Color(0xFF2E7D32), // Forest Green
      const Color(0xFF4CAF50), // Green
      const Color(0xFF81C784), // Light Green
      const Color(0xFFA5D6A7), // Pale Green
    ];
    
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 50,
              sections: allCrops.asMap().entries.map((entry) {
                final color = colors[entry.key % colors.length];
                return PieChartSectionData(
                  color: color,
                  value: entry.value.value,
                  title: '${entry.value.value.toStringAsFixed(0)}',
                  radius: 50,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: allCrops.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[entry.key % colors.length], shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(entry.value.key, style: const TextStyle(fontSize: 14, color: Color(0xFF333333)), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, String value, IconData icon, Color color, String subtitle, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          width: _getCardWidth(context),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8))],
            border: Border.all(color: Colors.grey.withOpacity(0.08)),
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
                    child: Icon(icon, size: 24, color: color),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600))),
                ],
              ),
              const SizedBox(height: 20),
              Text(title, style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildRollupCard(BuildContext context, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          width: _getCardWidth(context),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8))],
            border: Border.all(color: const Color(0xFFBBF7D0).withOpacity(0.5)),
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
                    decoration: BoxDecoration(color: const Color(0xFF4CAF50).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.attach_money, size: 24, color: Color(0xFF15803D)),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(child: Text('P&L Roll-ups', style: TextStyle(fontSize: 13, color: Color(0xFF15803D), fontWeight: FontWeight.w700))),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Projected Rev.', style: TextStyle(fontSize: 14, color: Color(0xFF166534), fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              const Text('₱ 1.2B', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF14532D))),
            ],
          ),
        ),
      ),
    );
  }
}

