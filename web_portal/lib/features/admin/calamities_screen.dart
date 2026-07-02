import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/auth_provider.dart';

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
  final double _calibratedValuePerHectare = 50000.0; // Dummy value

  String _formatCropId(String? cropId) {
    if (cropId == null) return 'Unknown Crop';
    return cropId
        .split('_')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  Future<void> _deleteReport(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text('Are you sure you want to delete this report?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(supabaseClientProvider)
            .from('calamity_reports')
            .delete()
            .eq('id', id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report deleted successfully')),
          );
        }
        ref.invalidate(calamitiesProvider);
        if (mounted) Navigator.pop(context); // Close details dialog
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting report: $e')),
          );
        }
      }
    }
  }

  Future<void> _editReport(Map<String, dynamic> report) async {
    final lossPercentCtrl = TextEditingController(
      text: ((report['loss_percent'] as num?)?.toDouble() ?? 0.0).toString(),
    );
    final affectedAreaCtrl = TextEditingController(
      text: ((report['affected_area_ha'] as num?)?.toDouble() ?? 0.0).toString(),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: lossPercentCtrl,
              decoration: const InputDecoration(labelText: 'Loss Percent (e.g. 0.5 for 50%)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: affectedAreaCtrl,
              decoration: const InputDecoration(labelText: 'Affected Area (hectares)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final newLoss = double.tryParse(lossPercentCtrl.text) ?? 0.0;
        final newArea = double.tryParse(affectedAreaCtrl.text) ?? 0.0;

        await ref.read(supabaseClientProvider)
            .from('calamity_reports')
            .update({
              'loss_percent': newLoss,
              'affected_area_ha': newArea,
            })
            .eq('id', report['id']);
            
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report updated successfully')),
          );
        }
        ref.invalidate(calamitiesProvider);
        if (mounted) Navigator.pop(context); // Close details dialog
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating report: $e')),
          );
        }
      }
    }
  }

  void _showReportDetails(Map<String, dynamic> report) {
    final user = ref.read(currentUserProvider);
    final userRole = user?['role'] as String?;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final rawLoss = (report['loss_percent'] as num?)?.toDouble() ?? 0.0;
            final lossFactor = rawLoss > 1.0 ? rawLoss / 100.0 : rawLoss;
            final affectedArea = (report['affected_area_ha'] as num?)?.toDouble() ?? 0.0;
            double estimatedSubsidy = lossFactor * affectedArea * _calibratedValuePerHectare;
            
            final farmerName = report['profiles']?['full_name'] ?? 'Unknown Farmer';
            final cropName = _formatCropId(report['crop_id']);
            final type = report['type'] ?? 'Unknown Type';
            final dateStr = report['occurred_on'] ?? 'Unknown Date';

            return AlertDialog(
              title: Text('Report Details: ${report['id']}'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Farmer: $farmerName', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Crop Affected: $cropName'),
                    Text('Type: $type'),
                    Text('Date: $dateStr'),
                    const SizedBox(height: 16),
                    Text('Affected Area: $affectedArea ha'),
                    Text('Loss Percentage: ${(lossFactor * 100).toStringAsFixed(0)}%'),
                    const SizedBox(height: 16),
                    Text(
                      'Estimated Subsidy: PHP ${estimatedSubsidy.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Chip(
                          label: Text(report['status'].toString().toUpperCase()),
                          backgroundColor: _getStatusColor(report['status']).withOpacity(0.2),
                          labelStyle: TextStyle(color: _getStatusColor(report['status'])),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                if (userRole == 'mao') ...[
                  TextButton(
                    onPressed: () => _deleteReport(report['id']),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                  TextButton(
                    onPressed: () => _editReport(report),
                    child: const Text('Edit'),
                  ),
                ],
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                if (userRole == 'mao' && report['status'] != 'endorsed')
                  ElevatedButton(
                    onPressed: () async {
                      final newStatus = _getNextStatus(report['status']);
                      await ref.read(supabaseClientProvider)
                          .from('calamity_reports')
                          .update({'status': newStatus})
                          .eq('id', report['id']);
                      ref.invalidate(calamitiesProvider);
                      if (mounted) Navigator.pop(context);
                    },
                    child: Text('Advance to ${_getNextStatus(report['status']).toUpperCase()}'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  String _getNextStatus(String currentStatus) {
    switch (currentStatus) {
      case 'submitted':
        return 'under_review';
      case 'under_review':
        return 'verified';
      case 'verified':
        return 'endorsed';
      default:
        return currentStatus;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'submitted':
        return Colors.blue;
      case 'under_review':
        return Colors.orange;
      case 'verified':
        return Colors.green;
      case 'endorsed':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
  
  Widget _buildChart(List<Map<String, dynamic>> reports) {
    // Calculate total loss by calamity type
    Map<String, double> lossByType = {};
    for (var report in reports) {
      final type = report['type'] as String? ?? 'Unknown';
      final rawLoss = (report['loss_percent'] as num?)?.toDouble() ?? 0.0;
      final lossFactor = rawLoss > 1.0 ? rawLoss / 100.0 : rawLoss;
      final affectedArea = (report['affected_area_ha'] as num?)?.toDouble() ?? 0.0;
      final lossValue = lossFactor * affectedArea * _calibratedValuePerHectare;
      
      lossByType[type] = (lossByType[type] ?? 0.0) + lossValue;
    }

    if (lossByType.isEmpty) {
      return const SizedBox.shrink();
    }

    List<PieChartSectionData> sections = [];
    int colorIndex = 0;
    final colors = [
      const Color(0xFF3B82F6), const Color(0xFFEF4444), const Color(0xFF10B981), const Color(0xFFF59E0B), 
      const Color(0xFF8B5CF6), const Color(0xFF14B8A6), const Color(0xFFF97316)
    ];

    lossByType.forEach((type, value) {
      if (value > 0) {
        sections.add(
          PieChartSectionData(
            color: colors[colorIndex % colors.length],
            value: value,
            title: '${(value / 1000).toStringAsFixed(1)}k',
            radius: 80,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            badgeWidget: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                ],
              ),
              child: Text(type, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
            ),
            badgePositionPercentageOffset: 1.3,
          )
        );
        colorIndex++;
      }
    });

    return Container(
      height: 350,
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total Estimated Loss by Calamity Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          const SizedBox(height: 24),
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: sections,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calamitiesAsync = ref.watch(calamitiesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Calamity Verification', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: calamitiesAsync.when(
        data: (reports) {
          if (reports.isEmpty) {
            return const Center(child: Text('No calamity reports found.', style: TextStyle(color: Color(0xFF64748B))));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChart(reports),
                const SizedBox(height: 24),
                const Text('Recent Reports', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reports.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      final status = report['status'] ?? 'unknown';
                      final type = report['type'] ?? 'Unknown Type';
                      final dateStr = report['occurred_on'] ?? '';
                      final farmerName = report['profiles']?['full_name'] ?? 'Unknown Farmer';

                      return InkWell(
                        onTap: () => _showReportDetails(report),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.warning_amber_rounded, color: _getStatusColor(status)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('$type - $farmerName', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                    const SizedBox(height: 4),
                                    Text('Report ID: ${report['id']} • Date: $dateStr', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status.toString().toUpperCase(),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _getStatusColor(status)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
      ),
    );
  }
}
