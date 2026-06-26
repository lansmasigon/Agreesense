import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'dart:ui';
import '../../providers/auth_provider.dart';

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
  int _currentPage = 0;
  final int _rowsPerPage = 5;

  void _showAddEditDialog(String title, List<String> fields, Function(Map<String, dynamic>) onSave, [Map<String, dynamic>? initialData]) {
    final controllers = {for (var field in fields) field: TextEditingController(text: initialData?[field]?.toString() ?? '')};

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: const TextStyle(color: Color(0xFF1E392A), fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: fields.map((field) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: TextField(
                controller: controllers[field],
                decoration: InputDecoration(
                  labelText: field.replaceAll('_', ' ').toUpperCase(),
                  labelStyle: const TextStyle(color: Color(0xFF2E7D32), fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2E7D32))),
                ),
              ),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final result = <String, dynamic>{};
              for (var field in fields) {
                final val = controllers[field]!.text;
                if (field == 'growth_duration_days') {
                  result[field] = int.tryParse(val) ?? 0;
                } else if (field == 'baseline_yield_per_ha' || field == 'baseline_price_per_kg' || field == 'price_per_kg' || field == 'annual_demand_tons' || field == 'projected_demand_tons') {
                  result[field] = double.tryParse(val) ?? 0.0;
                } else {
                  result[field] = val;
                }
              }
              onSave(result);
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(List<Map<String, dynamic>> data, List<String> columns, Function(Map<String, dynamic>) onEdit, Function(Map<String, dynamic>) onDelete) {
    if (data.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No data available', style: TextStyle(color: Colors.grey))));
    
    final totalItems = data.length;
    final totalPages = (totalItems / _rowsPerPage).ceil();
    final startIndex = _currentPage * _rowsPerPage;
    final paginatedData = data.skip(startIndex).take(_rowsPerPage).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F8F4)),
                      columns: [
                        ...columns.map((c) => DataColumn(label: Text(c.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E392A))))),
                        const DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E392A)))),
                      ],
                      rows: paginatedData.map((item) => DataRow(
                        cells: [
                          ...columns.map((c) => DataCell(Text(item[c]?.toString() ?? '', style: const TextStyle(color: Color(0xFF333333))))),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit_outlined, color: Color(0xFF2E7D32), size: 20), onPressed: () => onEdit(item)),
                              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), onPressed: () => onDelete(item)),
                            ],
                          )),
                        ],
                      )).toList(),
                    ),
                  ),
                ),
                ));
              }
            ),
          ),
        ),
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                  color: _currentPage > 0 ? const Color(0xFF2E7D32) : Colors.grey,
                ),
                Text('Page ${_currentPage + 1} of $totalPages', style: const TextStyle(color: Color(0xFF1E392A), fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                  color: _currentPage < totalPages - 1 ? const Color(0xFF2E7D32) : Colors.grey,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _handleSave(String table, Map<String, dynamic> data, {String? id}) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      double? projectedDemand;
      if (table == 'crops' && data.containsKey('projected_demand_tons')) {
        projectedDemand = data.remove('projected_demand_tons') as double?;
      }

      if (id != null) {
        await supabase.from(table).update(data).eq('id', id);
        if (table == 'crops' && projectedDemand != null) {
          final existing = await supabase.from('demand_baselines').select().eq('crop_id', id);
          if (existing.isEmpty) {
            await supabase.from('demand_baselines').insert({'crop_id': id, 'annual_demand_tons': projectedDemand});
          } else {
            await supabase.from('demand_baselines').update({'annual_demand_tons': projectedDemand}).eq('crop_id', id);
          }
        }
      } else {
        final res = await supabase.from(table).insert(data).select().single();
        if (table == 'crops' && projectedDemand != null && res['id'] != null) {
          await supabase.from('demand_baselines').insert({'crop_id': res['id'], 'annual_demand_tons': projectedDemand});
        }
      }
      ref.invalidate(referenceDataProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved successfully!'), backgroundColor: Color(0xFF2E7D32)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _handleMarketPriceSave(Map<String, dynamic> data, {Map<String, dynamic>? oldItem}) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      if (oldItem != null) {
        await supabase.from('market_prices').update(data)
          .eq('crop_id', oldItem['crop_id'])
          .eq('market', oldItem['market']);
      } else {
        await supabase.from('market_prices').insert(data);
      }
      ref.invalidate(referenceDataProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved successfully!'), backgroundColor: Color(0xFF2E7D32)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _handleDelete(String table, String id) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from(table).delete().eq('id', id);
      ref.invalidate(referenceDataProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully!'), backgroundColor: Color(0xFF2E7D32)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _handleMarketPriceDelete(Map<String, dynamic> item) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('market_prices').delete()
        .eq('crop_id', item['crop_id'])
        .eq('market', item['market']);
      ref.invalidate(referenceDataProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully!'), backgroundColor: Color(0xFF2E7D32)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _handleDemandBaselineSave(Map<String, dynamic> data, {Map<String, dynamic>? oldItem}) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      if (oldItem != null) {
        await supabase.from('demand_baselines').update(data).eq('crop_id', oldItem['crop_id']);
      } else {
        await supabase.from('demand_baselines').insert(data);
      }
      ref.invalidate(referenceDataProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved successfully!'), backgroundColor: Color(0xFF2E7D32)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _handleDemandBaselineDelete(Map<String, dynamic> item) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('demand_baselines').delete().eq('crop_id', item['crop_id']);
      ref.invalidate(referenceDataProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully!'), backgroundColor: Color(0xFF2E7D32)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Widget _buildDemandChart(List<Map<String, dynamic>> crops, List<Map<String, dynamic>> demandData) {
    if (crops.isEmpty) return const SizedBox.shrink();

    // Group by crop_id and sum demand
    Map<String, double> aggregatedDemand = {};
    for (var c in crops) {
      final cropId = c['id']?.toString() ?? 'Unknown';
      
      // Look for it in demandData
      final demandItem = demandData.where((d) => d['crop_id']?.toString() == cropId).toList();
      if (demandItem.isNotEmpty) {
        aggregatedDemand[cropId] = (demandItem.first['annual_demand_tons'] as num?)?.toDouble() ?? 0.0;
      } else {
        aggregatedDemand[cropId] = (c['projected_demand_tons'] as num?)?.toDouble() ?? 0.0;
      }
    }

    final barGroups = aggregatedDemand.entries.toList().asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value.value,
            color: const Color(0xFF4CAF50),
            width: 20,
            borderRadius: BorderRadius.circular(4),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: aggregatedDemand.values.reduce((a, b) => a > b ? a : b) * 1.1,
              color: const Color(0xFFF1F8F4),
            )
          )
        ],
      );
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total Annual Demand (Tons)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E392A))),
          const SizedBox(height: 24),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        width: math.max(constraints.maxWidth, aggregatedDemand.length * 80.0),
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            barGroups: barGroups,
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() >= 0 && value.toInt() < aggregatedDemand.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          aggregatedDemand.keys.elementAt(value.toInt()),
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 11, color: Colors.grey)))),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(referenceDataProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FCFA),
      appBar: AppBar(
        title: const Text('Reference Data Management', style: TextStyle(color: Color(0xFF1E392A), fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF1E392A)),
      ),
      body: dataAsync.when(
        data: (data) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildTab('Crops', 0),
                      const SizedBox(width: 12),
                      _buildTab('Market Prices', 1),
                      const SizedBox(width: 12),
                      _buildTab('Demand Baselines', 2),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _selectedTab == 0
                        ? _buildDataTable(data.crops, ['id', 'name', 'growth_duration_days', 'baseline_yield_per_ha', 'baseline_price_per_kg', 'projected_demand_tons'], 
                            (item) => _showAddEditDialog('Edit Crop', ['id', 'name', 'growth_duration_days', 'baseline_yield_per_ha', 'baseline_price_per_kg', 'projected_demand_tons'], (newData) {
                              _handleSave('crops', newData, id: item['id'].toString());
                            }, item),
                            (item) => _handleDelete('crops', item['id'].toString()))
                        : _selectedTab == 1
                            ? _buildDataTable(data.marketPrices, ['crop_id', 'market', 'price_per_kg', 'recorded_on'], 
                                (item) => _showAddEditDialog('Edit Market Price', ['crop_id', 'market', 'price_per_kg', 'recorded_on'], (newData) {
                                  _handleMarketPriceSave(newData, oldItem: item);
                                }, item),
                                (item) => _handleMarketPriceDelete(item))
                            : _buildDataTable(data.demandBaselines, ['crop_id', 'annual_demand_tons'], 
                                (item) => _showAddEditDialog('Edit Demand Baseline', ['crop_id', 'annual_demand_tons'], (newData) {
                                  _handleDemandBaselineSave(newData, oldItem: item);
                                }, item),
                                (item) => _handleDemandBaselineDelete(item)),
                      if (data.crops.isNotEmpty)
                        const SizedBox(height: 24),
                      if (data.crops.isNotEmpty)
                        SizedBox(
                          height: 350,
                          child: _buildDemandChart(data.crops, data.demandBaselines),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2E7D32),
        onPressed: () {
          if (_selectedTab == 0) {
            _showAddEditDialog('Add New Crop', ['id', 'name', 'growth_duration_days', 'baseline_yield_per_ha', 'baseline_price_per_kg', 'projected_demand_tons'], (newData) {
              _handleSave('crops', newData);
            });
          } else if (_selectedTab == 1) {
            _showAddEditDialog('Add New Market Price', ['crop_id', 'market', 'price_per_kg', 'recorded_on'], (newData) {
              _handleMarketPriceSave(newData);
            });
          } else {
            _showAddEditDialog('Add New Demand Baseline', ['crop_id', 'annual_demand_tons'], (newData) {
              _handleDemandBaselineSave(newData);
            });
          }
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add New', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () {
        if (_selectedTab != index) {
          setState(() {
            _selectedTab = index;
            _currentPage = 0;
          });
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E7D32) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF666666),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
