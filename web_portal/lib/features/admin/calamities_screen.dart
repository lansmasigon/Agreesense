import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import 'dart:async';
import 'dart:math' as math;

final incidentReportsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final res = await supabase
      .from('calamity_reports')
      .select('*, profiles(first_name, last_name, id, barangay)')
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
  
  String _searchQuery = '';
  Timer? _debounce;
  final ScrollController _horizontalScrollController = ScrollController();
  
  // Filters
  String? _filterMonth;
  String? _filterYear;
  String? _filterCropStage;

  final List<String> _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  final List<String> _years = ['2023', '2024', '2025', '2026'];
  final List<String> _cropStages = ['Seedling', 'Vegetative', 'Reproductive', 'Maturity', 'Harvesting'];

  @override
  void dispose() {
    _debounce?.cancel();
    _horizontalScrollController.dispose();
    super.dispose();
  }
  
  // Mock function to determine crop stage from created_at (since it might not be in DB)
  String _getCropStage(String dateStr) {
    int day = 0;
    try {
      day = DateTime.parse(dateStr).day;
    } catch(e) {
      day = 1;
    }
    if (day <= 7) return 'Seedling';
    if (day <= 14) return 'Vegetative';
    if (day <= 21) return 'Reproductive';
    if (day <= 28) return 'Maturity';
    return 'Harvesting';
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(incidentReportsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: reportsAsync.when(
        data: (reports) {
          // Apply Search and Filters
          var filteredReports = reports.where((r) {
            bool matchesSearch = true;
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              final type = (r['type'] ?? '').toString().toLowerCase();
              final farmer = (r['profiles'] != null ? "${r['profiles']['first_name']} ${r['profiles']['last_name']}" : '').toLowerCase();
              final brgy = (r['barangay'] ?? r['profiles']?['barangay'] ?? '').toString().toLowerCase();
              matchesSearch = type.contains(q) || farmer.contains(q) || brgy.contains(q);
            }
            
            bool matchesMonth = true;
            bool matchesYear = true;
            String dateStr = r['created_at'] ?? '';
            if (dateStr.isNotEmpty) {
              try {
                final dt = DateTime.parse(dateStr);
                if (_filterMonth != null && _filterMonth != 'All') {
                  matchesMonth = _months[dt.month - 1] == _filterMonth;
                }
                if (_filterYear != null && _filterYear != 'All') {
                  matchesYear = dt.year.toString() == _filterYear;
                }
              } catch(e) {
                // Ignore parse errors, defaulting to match
              }
            }
            
            bool matchesStage = true;
            if (_filterCropStage != null && _filterCropStage != 'All') {
              matchesStage = _getCropStage(dateStr) == _filterCropStage;
            }

            return matchesSearch && matchesMonth && matchesYear && matchesStage;
          }).toList();

          return Row(
            children: [
              // Main Tabular Area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: const BoxDecoration(
                        color: AppColors.card,
                        border: Border(bottom: BorderSide(color: AppColors.border))
                      ),
                      child: Row(
                        children: [
                          const Text('Incident Reports', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text, letterSpacing: -0.5)),
                          const SizedBox(width: 32),
                          
                          // Search Box
                          Container(
                            width: 200,
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                            child: Row(
                              children: [
                                const Icon(Icons.search, size: 16, color: AppColors.secondaryText),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    onChanged: (val) {
                                      if (_debounce?.isActive ?? false) _debounce!.cancel();
                                      _debounce = Timer(const Duration(milliseconds: 300), () {
                                        setState(() => _searchQuery = val);
                                      });
                                    },
                                    style: const TextStyle(fontSize: 13),
                                    decoration: const InputDecoration(border: InputBorder.none, hintText: 'Search incidents...', hintStyle: TextStyle(color: AppColors.secondaryText)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          
                          // Filters
                          _buildFilterDropdown('Month', _months, _filterMonth, (v) => setState(() => _filterMonth = v)),
                          const SizedBox(width: 12),
                          _buildFilterDropdown('Year', _years, _filterYear, (v) => setState(() => _filterYear = v)),
                          const SizedBox(width: 12),
                          _buildFilterDropdown('Crop Stage', _cropStages, _filterCropStage, (v) => setState(() => _filterCropStage = v)),
                        ],
                      ),
                    ),

                    // Table Area
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Scrollbar(
                            controller: _horizontalScrollController,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: math.max(1080.0, constraints.maxWidth),
                                  minHeight: constraints.maxHeight
                                ),
                                child: SizedBox(
                                  width: math.max(1080.0, constraints.maxWidth),
                                  child: _buildSpreadsheet(filteredReports),
                                )
                              ),
                            ),
                          );
                        }
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.danger))),
      ),
    );
  }

  Widget _buildFilterDropdown(String hint, List<String> items, String? value, ValueChanged<String?> onChanged) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
          icon: const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.secondaryText),
          style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w500),
          dropdownColor: AppColors.card,
          items: [
            const DropdownMenuItem(value: 'All', child: Text('All')),
            ...items.map((e) => DropdownMenuItem(value: e, child: Text(e))),
          ],
          onChanged: (v) => onChanged(v == 'All' ? null : v),
        ),
      ),
    );
  }

  Widget _buildSpreadsheet(List<Map<String, dynamic>> data) {
    final columns = [
      {'key': 'date', 'label': 'DATE', 'width': 120.0},
      {'key': 'type', 'label': 'INCIDENT TYPE', 'width': 150.0},
      {'key': 'farmer', 'label': 'FARMER', 'width': 200.0},
      {'key': 'barangay', 'label': 'BARANGAY', 'width': 150.0},
      {'key': 'area', 'label': 'AFFECTED (HA)', 'width': 120.0},
      {'key': 'loss', 'label': 'LOSS %', 'width': 100.0},
      {'key': 'stage', 'label': 'CROP STAGE', 'width': 120.0},
      {'key': 'status', 'label': 'STATUS', 'width': 120.0},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Row
        Container(
          height: 48,
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: columns.map((col) => Container(
              width: col['width'] as double,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.border))),
              child: Text(
                col['label'] as String,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondaryText, letterSpacing: 0.5),
              ),
            )).toList(),
          ),
        ),
        // Data Rows
        Expanded(
          child: data.isEmpty
            ? const Center(child: Text('No incident reports found.', style: TextStyle(color: AppColors.secondaryText)))
            : ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final row = data[index];

                  final dateStr = row['created_at'] != null ? row['created_at'].toString().split('T').first : '';
                  final type = row['type'] ?? 'Unknown';
                  final farmer = row['profiles'] != null ? "${row['profiles']['first_name']} ${row['profiles']['last_name']}" : 'Unknown';
                  final barangay = row['barangay'] ?? row['profiles']?['barangay'] ?? 'Unknown';
                  final area = (row['affected_area_ha'] as num?)?.toStringAsFixed(1) ?? '0.0';
                  final loss = (row['loss_percent'] as num?)?.toStringAsFixed(0) ?? '0';
                  final stage = _getCropStage(dateStr);
                  final status = row['status'] ?? 'Pending'; // fallback

                  return InkWell(
                    onTap: () {
                      _showValidationModal(context, row);
                    },
                    hoverColor: AppColors.accent.withValues(alpha: 0.05),
                    child: Container(
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        border: Border(bottom: BorderSide(color: AppColors.border)),
                      ),
                      child: Row(
                        children: [
                          _buildCell(dateStr, 120.0),
                          _buildCell(type, 150.0, isBold: true),
                          _buildCell(farmer, 200.0),
                          _buildCell(barangay, 150.0),
                          _buildCell(area, 120.0),
                          _buildCell('$loss%', 100.0),
                          _buildCell(stage, 120.0),
                          _buildStatusCell(status, 120.0),
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

  Widget _buildCell(String text, double width, {bool isBold = false}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.border))),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: AppColors.text, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
  
  Widget _buildStatusCell(String status, double width) {
    Color color = AppColors.warning;
    if (status.toLowerCase() == 'approved' || status.toLowerCase() == 'validated') color = AppColors.primary;
    if (status.toLowerCase() == 'rejected') color = AppColors.danger;

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.border))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          status.toUpperCase(),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  void _showValidationModal(BuildContext context, Map<String, dynamic> report) {
    final lossFactor = ((report['loss_percent'] as num?)?.toDouble() ?? 0.0) / 100.0;
    final area = (report['affected_area_ha'] as num?)?.toDouble() ?? 0.0;
    final estimatedSubsidy = lossFactor * area * _calibratedValuePerHectare;
    final type = report['type'] ?? 'Unknown';
    final profile = report['profiles'];
    final farmer = profile != null ? "${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}".trim() : 'Unknown';
    final farmerId = profile != null ? profile['id'] : 'N/A';
    final barangay = report['barangay'] ?? report['profiles']?['barangay'] ?? 'Unknown';
    final dateStr = report['created_at'] != null ? report['created_at'].toString().split('T').first : '';
    final stage = _getCropStage(dateStr);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: AppColors.card,
          child: Container(
            width: 500,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Incident Validation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.primary, letterSpacing: 1.2)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.secondaryText),
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(backgroundColor: AppColors.background),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(type, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.text, letterSpacing: -1)),
                const SizedBox(height: 16),
                
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Proof / Origin
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Icon(Icons.person, color: Colors.white),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Reported by $farmer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text('ID: $farmerId', style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.verified_user, color: AppColors.primary, size: 20),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        _buildCalcRow('Date of Incident', dateStr),
                        const SizedBox(height: 16),
                        _buildCalcRow('Barangay', barangay),
                        const SizedBox(height: 16),
                        _buildCalcRow('Affected Area', '${area.toStringAsFixed(1)} ha'),
                        const SizedBox(height: 16),
                        _buildCalcRow('Loss Percentage', '${(lossFactor * 100).toStringAsFixed(0)}%'),
                        const SizedBox(height: 16),
                        _buildCalcRow('Crop Stage', stage),
                        const SizedBox(height: 32),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
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
                                onPressed: () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: AppColors.danger), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                child: const Text('Reject', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incident Validated and Subsidy Approved')));
                                  Navigator.of(context).pop();
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                child: const Text('Validate & Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildCalcRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.secondaryText)),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
      ],
    );
  }
}
