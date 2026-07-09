import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';

final calamitiesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final res = await supabase
      .from('calamity_reports')
      .select('*, profiles(full_name)')
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(res as List);
});

class CalamitiesScreen extends ConsumerStatefulWidget {
  const CalamitiesScreen({super.key});

  @override
  ConsumerState<CalamitiesScreen> createState() => _CalamitiesScreenState();
}

class _CalamitiesScreenState extends ConsumerState<CalamitiesScreen> {
  final double _calibratedValuePerHectare = 50000.0;
  Map<String, dynamic>? _selectedReport;
  int _touchedIndex = -1;

  String _formatCropId(String? cropId) {
    if (cropId == null) return 'Unknown Crop';
    return cropId
        .split('_')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  void _closeDrawer() {
    setState(() {
      _selectedReport = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final calamitiesAsync = ref.watch(calamitiesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: calamitiesAsync.when(
        data: (reports) {
          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_outline_rounded, size: 64, color: AppColors.primary),
                  ),
                  const SizedBox(height: 24),
                  const Text('No calamities reported', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text)),
                  const SizedBox(height: 8),
                  const Text('Great news! Your municipality has no active\nagricultural disaster reports.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.secondaryText, fontSize: 16)),
                ],
              ),
            );
          }

          double totalLoss = 0.0;
          for (var r in reports) {
            final lossFactor = ((r['loss_percent'] as num?)?.toDouble() ?? 0.0) / 100.0;
            final area = (r['affected_area_ha'] as num?)?.toDouble() ?? 0.0;
            totalLoss += lossFactor * area * _calibratedValuePerHectare;
          }

          String displayTotal;
          if (totalLoss >= 1000000) {
            displayTotal = '₱${(totalLoss / 1000000).toStringAsFixed(2)}M';
          } else if (totalLoss >= 1000) {
            displayTotal = '₱${(totalLoss / 1000).toStringAsFixed(1)}k';
          } else {
            displayTotal = '₱${totalLoss.toStringAsFixed(0)}';
          }

          return Row(
            children: [
              // Main Cinematic Area
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Estimated Loss', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.secondaryText, letterSpacing: 1.5)),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(displayTotal, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: AppColors.danger, letterSpacing: -2)),
                      ),
                      const SizedBox(height: 48),
                      Expanded(
                        child: _buildCinematicDonutChart(reports),
                      )
                    ],
                  ),
                ),
              ),

              // Right Panel (Live Feed / Drawer)
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                width: 400,
                decoration: const BoxDecoration(
                  color: AppColors.card,
                  border: Border(left: BorderSide(color: AppColors.border)),
                ),
                child: _selectedReport == null ? _buildLiveFeed(reports) : _buildLossCalculator(_selectedReport!),
              )
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.danger))),
      ),
    );
  }

  Widget _buildCinematicDonutChart(List<Map<String, dynamic>> reports) {
    Map<String, double> lossByType = {};
    for (var r in reports) {
      final type = r['type'] as String? ?? 'Unknown';
      final lossFactor = ((r['loss_percent'] as num?)?.toDouble() ?? 0.0) / 100.0;
      final area = (r['affected_area_ha'] as num?)?.toDouble() ?? 0.0;
      lossByType[type] = (lossByType[type] ?? 0.0) + (lossFactor * area * _calibratedValuePerHectare);
    }

    final colors = [AppColors.information, AppColors.danger, AppColors.warning, AppColors.primary, AppColors.accent];
    List<PieChartSectionData> sections = [];
    int i = 0;

    lossByType.forEach((type, value) {
      if (value > 0) {
        final isTouched = i == _touchedIndex;
        final radius = isTouched ? 130.0 : 100.0;
        final fontSize = isTouched ? 16.0 : 12.0;

        // Display exact formatting based on value magnitude
        String displayValue;
        if (value >= 1000000) {
          displayValue = '${(value / 1000000).toStringAsFixed(1)}M';
        } else if (value >= 1000) {
          displayValue = '${(value / 1000).toStringAsFixed(0)}k';
        } else {
          displayValue = value.toStringAsFixed(0);
        }

        sections.add(
          PieChartSectionData(
            color: colors[i % colors.length],
            value: value,
            title: displayValue,
            radius: radius,
            titleStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white),
            badgeWidget: isTouched ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: AppColors.text.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: Text(type.toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text, letterSpacing: 1.2)),
            ) : null,
            badgePositionPercentageOffset: 1.2,
          )
        );
        i++;
      }
    });

    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            setState(() {
              if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                _touchedIndex = -1;
                return;
              }
              _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
            });
          },
        ),
        borderData: FlBorderData(show: false),
        sectionsSpace: 4,
        centerSpaceRadius: 120,
        sections: sections,
      ),
    );
  }

  Widget _buildLiveFeed(List<Map<String, dynamic>> reports) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('Live Report Feed', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: reports.length,
            separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 1),
            itemBuilder: (context, index) {
              final r = reports[index];
              final type = r['type'] as String? ?? 'Unknown';
              final farmer = r['profiles']?['full_name'] ?? 'Unknown';
              
              String emoji = '⚠';
              if (type.toLowerCase().contains('flood')) emoji = '🌊';
              if (type.toLowerCase().contains('typhoon')) emoji = '🌪';
              if (type.toLowerCase().contains('drought')) emoji = '☀';
              if (type.toLowerCase().contains('pest')) emoji = '🐛';

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedReport = r;
                  });
                },
                hoverColor: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(type, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.text)),
                            Text(farmer, style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
                          ],
                        ),
                      ),
                      const Text('Just now', style: TextStyle(color: AppColors.secondaryText, fontSize: 12)), // Dummy time
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLossCalculator(Map<String, dynamic> report) {
    final lossFactor = ((report['loss_percent'] as num?)?.toDouble() ?? 0.0) / 100.0;
    final area = (report['affected_area_ha'] as num?)?.toDouble() ?? 0.0;
    final estimatedSubsidy = lossFactor * area * _calibratedValuePerHectare;
    final type = report['type'] ?? 'Unknown';
    final farmer = report['profiles']?['full_name'] ?? 'Unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.secondaryText),
            onPressed: _closeDrawer,
            style: IconButton.styleFrom(backgroundColor: AppColors.background),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Loss Calculator', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text(type, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.text, letterSpacing: -1)),
                Text('Reported by $farmer', style: const TextStyle(color: AppColors.secondaryText, fontSize: 16)),
                const SizedBox(height: 48),

                _buildCalcRow('Affected Area', '${area.toStringAsFixed(1)} ha'),
                const SizedBox(height: 24),
                _buildCalcRow('Loss Percentage', '${(lossFactor * 100).toStringAsFixed(0)}%'),
                const SizedBox(height: 48),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Estimated Subsidy', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text('₱${estimatedSubsidy.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: -1)),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _closeDrawer,
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: AppColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Back', style: TextStyle(color: AppColors.text)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Approve Subsidy', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalcRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, color: AppColors.secondaryText)),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)),
      ],
    );
  }
}
