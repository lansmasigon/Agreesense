import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

class SupplyChainData {
  final List<Map<String, dynamic>> marketChannels;
  final List<Map<String, dynamic>> cooperatives;

  SupplyChainData({required this.marketChannels, required this.cooperatives});
}

final supplyChainProvider = FutureProvider.autoDispose<SupplyChainData>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  final mcRes = await supabase.from('market_channels').select();
  final coopRes = await supabase.from('cooperatives').select();

  return SupplyChainData(
    marketChannels: List<Map<String, dynamic>>.from(mcRes as List),
    cooperatives: List<Map<String, dynamic>>.from(coopRes as List),
  );
});

class SupplyChainScreen extends ConsumerWidget {
  const SupplyChainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(supplyChainProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FCFA),
      appBar: AppBar(
        title: const Text('Supply Chain Governance', style: TextStyle(color: Color(0xFF1E392A), fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF1E392A)),
      ),
      body: dataAsync.when(
        data: (data) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // KPI Cards
                Row(
                  children: [
                    _buildKpiCard(context, 'Total Channels', '${data.marketChannels.length}', Icons.storefront, const Color(0xFF2E7D32)),
                    const SizedBox(width: 16),
                    _buildKpiCard(context, 'Total Cooperatives', '${data.cooperatives.length}', Icons.groups, const Color(0xFF4CAF50)),
                    const SizedBox(width: 16),
                    _buildKpiCard(context, 'Market Saturation Index', '85% (High)', Icons.warning_amber, Colors.orange),
                  ],
                ),
                const SizedBox(height: 32),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Market Channels Table
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Market Channels', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E392A))),
                              const SizedBox(height: 24),
                              data.marketChannels.isEmpty 
                                  ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No market channels found.', style: TextStyle(color: Colors.grey))))
                                  : SizedBox(
                                      width: double.infinity,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                          headingRowColor: MaterialStateProperty.all(const Color(0xFFF1F8F4)),
                                          columns: const [
                                            DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E392A)))),
                                            DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E392A)))),
                                            DataColumn(label: Text('Location', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E392A)))),
                                          ],
                                          rows: data.marketChannels.map((mc) {
                                            return DataRow(cells: [
                                              DataCell(Text(mc['name']?.toString() ?? 'N/A', style: const TextStyle(color: Color(0xFF333333)))),
                                              DataCell(Text(mc['type']?.toString() ?? 'N/A', style: const TextStyle(color: Color(0xFF333333)))),
                                              DataCell(Text(mc['location']?.toString() ?? 'N/A', style: const TextStyle(color: Color(0xFF333333)))),
                                            ]);
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Cooperatives Table
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Cooperatives', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E392A))),
                              const SizedBox(height: 24),
                              data.cooperatives.isEmpty 
                                  ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No cooperatives found.', style: TextStyle(color: Colors.grey))))
                                  : SizedBox(
                                      width: double.infinity,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                          headingRowColor: MaterialStateProperty.all(const Color(0xFFF1F8F4)),
                                          columns: const [
                                            DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E392A)))),
                                            DataColumn(label: Text('Location', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E392A)))),
                                            DataColumn(label: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E392A)))),
                                          ],
                                          rows: data.cooperatives.map((coop) {
                                            return DataRow(cells: [
                                              DataCell(Text(coop['name']?.toString() ?? 'N/A', style: const TextStyle(color: Color(0xFF333333)))),
                                              DataCell(Text(coop['location']?.toString() ?? 'N/A', style: const TextStyle(color: Color(0xFF333333)))),
                                              DataCell(Text(coop['contact_info']?.toString() ?? 'N/A', style: const TextStyle(color: Color(0xFF333333)))),
                                            ]);
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
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

  Widget _buildKpiCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 14, color: Color(0xFF666666)))),
              ],
            ),
            const SizedBox(height: 20),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color == Colors.orange ? Colors.orange.shade700 : const Color(0xFF1E392A))),
          ],
        ),
      ),
    );
  }
}
