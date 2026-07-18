import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'dart:ui';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';

class ReferenceData {
  final List<Map<String, dynamic>> crops;
  final List<Map<String, dynamic>> marketPrices;
  final List<Map<String, dynamic>> demandBaselines;

  ReferenceData({
    required this.crops,
    required this.marketPrices,
    required this.demandBaselines,
  });
}

final referenceDataProvider = FutureProvider.autoDispose<ReferenceData>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final cropsRes = await supabase.from('crops').select();
  final pricesRes = await supabase.from('market_prices').select();
  final demandRes = await supabase.from('demand_baselines').select();

  return ReferenceData(
    crops: List<Map<String, dynamic>>.from(cropsRes as List),
    marketPrices: List<Map<String, dynamic>>.from(pricesRes as List),
    demandBaselines: List<Map<String, dynamic>>.from(demandRes as List),
  );
});

class ReferenceDataScreen extends ConsumerStatefulWidget {
  const ReferenceDataScreen({super.key});

  @override
  ConsumerState<ReferenceDataScreen> createState() => _ReferenceDataScreenState();
}

class _ReferenceDataScreenState extends ConsumerState<ReferenceDataScreen> {
  int _selectedTab = 0;
  Set<String> _selectedIds = {}; // For multi-select
  String _searchQuery = '';
  Timer? _debounce;
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _debounce?.cancel();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(referenceDataProvider);

    return Scaffold(
      backgroundColor: AppColors.card, // Make it flush white like Airtable
      body: dataAsync.when(
        data: (data) {
          List<Map<String, dynamic>> currentData;
          List<String> currentColumns;
          String idField = 'id';

          if (_selectedTab == 0) {
            currentData = data.crops;
            currentColumns = ['id', 'name', 'growth_duration_days', 'baseline_yield_per_ha', 'baseline_price_per_kg'];
          } else if (_selectedTab == 1) {
            currentData = data.marketPrices;
            currentColumns = ['crop_id', 'market', 'price_per_kg', 'recorded_on'];
            idField = 'crop_id'; // compound key simplified for UI mock
          } else {
            currentData = data.demandBaselines;
            currentColumns = ['crop_id', 'annual_demand_tons'];
            idField = 'crop_id';
          }

          if (_searchQuery.isNotEmpty) {
            currentData = currentData.where((item) {
              return item.values.any((val) => val.toString().toLowerCase().contains(_searchQuery.toLowerCase()));
            }).toList();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Airtable-like Top Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                child: Row(
                  children: [
                    const Text('Reference Database', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text, letterSpacing: -0.5)),
                    const SizedBox(width: 32),
                    // Tabs
                    _buildAnimatedTab('Crops', 0),
                    const SizedBox(width: 8),
                    _buildAnimatedTab('Market Prices', 1),
                    const SizedBox(width: 8),
                    _buildAnimatedTab('Demand Baselines', 2),
                    const Spacer(),
                    // Actions
                    if (_selectedIds.isNotEmpty) ...[
                      Text('${_selectedIds.length} selected', style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
                      const SizedBox(width: 16),
                      TextButton.icon(onPressed: () {}, icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger), label: const Text('Delete', style: TextStyle(color: AppColors.danger))),
                      const SizedBox(width: 16),
                    ],
                    Container(
                      width: 200,
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 14, color: AppColors.secondaryText),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              onChanged: (val) {
                                if (_debounce?.isActive ?? false) _debounce!.cancel();
                                _debounce = Timer(const Duration(milliseconds: 500), () {
                                  setState(() => _searchQuery = val);
                                });
                              },
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(border: InputBorder.none, hintText: 'Search records...', hintStyle: TextStyle(color: AppColors.secondaryText)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.file_download_outlined, size: 16), label: const Text('Export'), style: OutlinedButton.styleFrom(foregroundColor: AppColors.text, padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 32), side: const BorderSide(color: AppColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)))),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.add, size: 16), label: const Text('New record'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 32), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)))),
                  ],
                ),
              ),

              // Spreadsheet Area (with horizontal scroll)
              Expanded(
                child: Scrollbar(
                  controller: _horizontalScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                      child: SizedBox(
                        width: math.max(MediaQuery.of(context).size.width, columnsWidth(currentColumns) + 200), // Added more padding
                        child: _buildSpreadsheet(currentData, currentColumns, idField),
                      ),
                    ),
                  ),
                ),
              )
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
  
  double columnsWidth(List<String> cols) {
    return cols.length * 200.0; // Rough estimate of 200px per column
  }

  Widget _buildAnimatedTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedTab = index;
        _selectedIds.clear();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildSpreadsheet(List<Map<String, dynamic>> data, List<String> columns, String idField) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Row
        Container(
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              // Checkbox Column
              Container(
                width: 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.border))),
                child: Checkbox(
                  value: data.isNotEmpty && _selectedIds.length == data.length,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedIds = data.map((e) => e[idField].toString()).toSet();
                      } else {
                        _selectedIds.clear();
                      }
                    });
                  },
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
              // Data Columns
              ...columns.map((col) => Container(
                width: 200,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.border))),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        col.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondaryText, letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 14, color: AppColors.border),
                  ],
                ),
              )),
              // Fill remaining space
              Expanded(child: Container()),
            ],
          ),
        ),
        // Data Rows
        Expanded(
          child: data.isEmpty
            ? const Center(child: Text('No records', style: TextStyle(color: AppColors.secondaryText)))
            : ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final row = data[index];
                  final id = row[idField].toString();
                  final isSelected = _selectedIds.contains(id);

                  return Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.accent.withOpacity(0.05) : Colors.transparent,
                      border: const Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        // Checkbox Column
                        Container(
                          width: 48,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.border))),
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) _selectedIds.add(id);
                                else _selectedIds.remove(id);
                              });
                            },
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        // Data Columns
                        ...columns.map((col) {
                          // Formatting for specific types (Airtable style)
                          final val = row[col];
                          Widget cellContent;
                          
                          if (val is num) {
                            cellContent = Text(val.toString(), style: const TextStyle(fontSize: 13, color: AppColors.text, fontFamily: 'monospace'));
                          } else if (col == 'id' || col == 'crop_id') {
                            cellContent = Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(4)),
                              child: Text(val?.toString() ?? '', style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                            );
                          } else {
                            cellContent = Text(val?.toString() ?? '', style: const TextStyle(fontSize: 13, color: AppColors.text), maxLines: 1, overflow: TextOverflow.ellipsis);
                          }

                          return Container(
                            width: 200,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: val is num ? Alignment.centerRight : Alignment.centerLeft,
                            decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.border))),
                            child: cellContent,
                          );
                        }),
                        // Fill remaining space + Hover Actions (blank for now)
                        Expanded(
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 16),
                            child: isSelected ? const Icon(Icons.drag_indicator, size: 16, color: AppColors.secondaryText) : null
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }
}
