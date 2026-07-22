import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import 'dart:math' as math;

class SupplyChainData {
  final List<Map<String, dynamic>> marketChannels;
  final List<Map<String, dynamic>> cooperatives;
  final List<Map<String, dynamic>> activities;
  final List<Map<String, dynamic>> v2Data; // Disposition Funnel
  final List<Map<String, dynamic>> v3Data; // Leakage Heatmap
  final List<Map<String, dynamic>> v4Data; // Channel Mix Monthly
  final Map<String, double> totalByChannel; // Total volume by channel
  final List<Map<String, dynamic>> channelCropMix; // Stacked Bar Chart data

  SupplyChainData({
    required this.marketChannels,
    required this.cooperatives,
    required this.activities,
    required this.v2Data,
    required this.v3Data,
    required this.v4Data,
    required this.totalByChannel,
    required this.channelCropMix,
  });
}

final supplyChainProvider = FutureProvider.autoDispose<SupplyChainData>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  final mcRes = await supabase.from('market_channels').select();
  final coopRes = await supabase.from('cooperatives').select();
  
  final activitiesRes = await supabase.from('crop_declarations')
      .select('status, created_at, crop_id, profiles(full_name)')
      .order('created_at', ascending: false)
      .limit(5);

  // V2 & V3 Data Mocking / Dart Aggregation
  // In production, these should query v_harvest_disposition and v_leakage_by_barangay
  
  final declarationsRes = await supabase.from('crop_declarations')
      .select('id, crop_id, barangay, area_ha, expected_harvest_date, expected_yield_kg, status')
      .neq('status', 'cancelled');
      
  final reportsRes = await supabase.from('production_reports')
      .select('declaration_id, actual_yield_kg, loss_kg, sold_to_channel, actual_price_per_kg, harvested_on');
      
  // Aggregation Logic for V2
  Map<String, Map<String, double>> cropDispositions = {};
  
  // Aggregation Logic for V3
  Map<String, Map<String, dynamic>> leakageByBrgyCrop = {};

  // Aggregation Logic for V4
  Map<String, Map<String, double>> v4Mix = {};
  
  // Total by Channel
  Map<String, double> totalByChannel = {};

  // Channel Crop Mix (Channel -> Crop -> Tons)
  Map<String, Map<String, double>> channelCropRaw = {};

  // Build a lookup for reports
  Map<String, dynamic> reportByDeclaration = {};
  for (var r in reportsRes as List) {
    reportByDeclaration[r['declaration_id']] = r;
    
    // Process V4 Data and Totals
    String channel = r['sold_to_channel'] as String? ?? 'association_surplus_buy_back';
    if (channel == 'bagsakan') {
      channel = 'association_surplus_buy_back';
    }
    
    final actualTons = ((r['actual_yield_kg'] as num?) ?? 0) / 1000.0;
    
    totalByChannel[channel] = (totalByChannel[channel] ?? 0.0) + actualTons;
    
    if (r['harvested_on'] != null) {
      final date = DateTime.tryParse(r['harvested_on'].toString());
      if (date != null) {
        final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        
        v4Mix.putIfAbsent(monthKey, () => {});
        v4Mix[monthKey]![channel] = (v4Mix[monthKey]![channel] ?? 0.0) + actualTons;
      }
    }
  }

  for (var d in declarationsRes as List) {
    final cropId = d['crop_id'] as String;
    final brgy = d['barangay'] as String? ?? 'Unknown';
    final declaredTons = ((d['expected_yield_kg'] as num?) ?? 0) / 1000.0;
    
    cropDispositions.putIfAbsent(cropId, () => {
      'monitored': 0.0,
      'own_consumption': 0.0,
      'leaked': 0.0,
      'loss': 0.0,
      'unreported': 0.0,
      'shortfall': 0.0,
      'declared_total': 0.0,
    });
    
    cropDispositions[cropId]!['declared_total'] = cropDispositions[cropId]!['declared_total']! + declaredTons;
    
    String brgyCropKey = '${brgy}_$cropId';
    leakageByBrgyCrop.putIfAbsent(brgyCropKey, () => {
      'barangay': brgy,
      'crop_id': cropId,
      'reports_n': 0,
      'reported_tons': 0.0,
      'leaked_tons': 0.0,
      'unreported_n': 0,
    });

    final r = reportByDeclaration[d['id']];
    if (r == null) {
      // Unreported if expected_harvest_date has passed (assuming all for simplicity)
      cropDispositions[cropId]!['unreported'] = cropDispositions[cropId]!['unreported']! + declaredTons;
      leakageByBrgyCrop[brgyCropKey]!['unreported_n'] += 1;
      } else {
        final actualTons = ((r['actual_yield_kg'] as num?) ?? 0) / 1000.0;
        final lossTons = ((r['loss_kg'] as num?) ?? 0) / 1000.0;
        
        // Handle database value change for bagsakan
        String channel = r['sold_to_channel'] as String? ?? 'association_surplus_buy_back';
        if (channel == 'bagsakan') {
          channel = 'association_surplus_buy_back';
        }
        
        // Aggregate Channel Crop Mix
        channelCropRaw.putIfAbsent(channel, () => {});
        channelCropRaw[channel]![cropId] = (channelCropRaw[channel]![cropId] ?? 0.0) + actualTons;
        
        final isLeaked = channel == 'trader' || channel == 'neighbouring_municipality';
        final isMonitored = channel == 'association_surplus_buy_back' || channel == 'cooperative' || channel == 'direct_market';
        
        if (isLeaked) cropDispositions[cropId]!['leaked'] = cropDispositions[cropId]!['leaked']! + actualTons;
        else if (isMonitored) cropDispositions[cropId]!['monitored'] = cropDispositions[cropId]!['monitored']! + actualTons;
        else if (channel == 'own_consumption') cropDispositions[cropId]!['own_consumption'] = cropDispositions[cropId]!['own_consumption']! + actualTons;
      
      cropDispositions[cropId]!['loss'] = cropDispositions[cropId]!['loss']! + lossTons;
      
      if (actualTons < declaredTons) {
         cropDispositions[cropId]!['shortfall'] = cropDispositions[cropId]!['shortfall']! + (declaredTons - actualTons);
      }
      
      leakageByBrgyCrop[brgyCropKey]!['reports_n'] += 1;
      leakageByBrgyCrop[brgyCropKey]!['reported_tons'] += actualTons;
      if (isLeaked) leakageByBrgyCrop[brgyCropKey]!['leaked_tons'] += actualTons;
    }
  }

  // Format V2 Data
  List<Map<String, dynamic>> v2Data = [];
  cropDispositions.forEach((crop, data) {
    if (data['declared_total']! > 0) {
      v2Data.add({
        'crop_id': crop,
        'monitored': (data['monitored']! / data['declared_total']!) * 100,
        'own_consumption': (data['own_consumption']! / data['declared_total']!) * 100,
        'leaked': (data['leaked']! / data['declared_total']!) * 100,
        'loss': (data['loss']! / data['declared_total']!) * 100,
        'unreported': (data['unreported']! / data['declared_total']!) * 100,
        'shortfall': (data['shortfall']! / data['declared_total']!) * 100,
        'leak_score': (data['leaked']! / data['declared_total']!) * 100 + (data['unreported']! / data['declared_total']!) * 100
      });
    }
  });
  v2Data.sort((a, b) => (b['leak_score'] as double).compareTo(a['leak_score'] as double));

  // Format V3 Data
  List<Map<String, dynamic>> v3Data = [];
  leakageByBrgyCrop.forEach((key, data) {
    double leakageRate = data['reported_tons'] > 0 ? (data['leaked_tons'] / data['reported_tons']) * 100 : 0.0;
    v3Data.add({
      'barangay': data['barangay'],
      'crop_id': data['crop_id'],
      'leakage_rate': leakageRate,
      'reports_n': data['reports_n'],
      'unreported_n': data['unreported_n']
    });
  });

  // Format V4 Data
  List<Map<String, dynamic>> v4Data = [];
  v4Mix.forEach((month, channels) {
    v4Data.add({
      'month': month,
      'channels': channels,
    });
  });
  v4Data.sort((a, b) => a['month'].compareTo(b['month']));

  // Format Channel Crop Mix
  List<Map<String, dynamic>> channelCropMix = [];
  channelCropRaw.forEach((channel, crops) {
    double totalVolume = crops.values.fold(0.0, (sum, val) => sum + val);
    channelCropMix.add({
      'channel': channel,
      'total_volume': totalVolume,
      'crops': crops,
    });
  });
  channelCropMix.sort((a, b) => (b['total_volume'] as double).compareTo(a['total_volume'] as double));

  return SupplyChainData(
    marketChannels: List<Map<String, dynamic>>.from(mcRes as List),
    cooperatives: List<Map<String, dynamic>>.from(coopRes as List),
    activities: List<Map<String, dynamic>>.from(activitiesRes as List),
    v2Data: v2Data,
    v3Data: v3Data,
    v4Data: v4Data,
    totalByChannel: totalByChannel,
    channelCropMix: channelCropMix,
  );
});

class SupplyChainScreen extends ConsumerStatefulWidget {
  const SupplyChainScreen({super.key});

  @override
  ConsumerState<SupplyChainScreen> createState() => _SupplyChainScreenState();
}

class _SupplyChainScreenState extends ConsumerState<SupplyChainScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _selectedCoop;
  Map<String, dynamic>? _selectedMarket;
  late AnimationController _gaugeController;

  @override
  void initState() {
    super.initState();
    _gaugeController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..forward();
  }

  @override
  void dispose() {
    _gaugeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(supplyChainProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: dataAsync.when(
        data: (data) {
          final wholesales = data.marketChannels.where((c) => c['type']?.toString().toLowerCase().contains('wholesale') ?? false).length;
          final retails = data.marketChannels.where((c) => c['type']?.toString().toLowerCase().contains('retail') ?? false).length;
          final exports = data.marketChannels.where((c) => c['type']?.toString().toLowerCase().contains('export') ?? false).length;
          final institutionals = data.marketChannels.length - wholesales - retails - exports;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HERO GAUGE (Temporarily removed - to be implemented later)
                /*
                Center(
                  child: Column(
                    children: [
                      const Text('Market Health', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondaryText, letterSpacing: 2)),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: AnimatedBuilder(
                          animation: _gaugeController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: CircularGaugePainter(progress: 0.85 * _gaugeController.value, color: AppColors.primary),
                              child: const Center(
                                child: Text('85%', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.text, letterSpacing: -2)),
                              ),
                            );
                          }
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Strong demand. Oversupply risks mitigated.', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 64),
                */

                const SizedBox(height: 64),
                
                // (Channel Mix Over Time removed as requested)

                // WHOLESALE / RETAIL CARDS
                Row(
                  children: [
                    Expanded(child: _buildChannelCard(context, 'Buyer', '7', Icons.warehouse_rounded, AppColors.primary)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildChannelCard(context, 'Market Channels', data.marketChannels.length.toString(), Icons.storefront_rounded, AppColors.information)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildChannelCard(context, 'Cooperatives', data.cooperatives.length.toString(), Icons.domain_rounded, AppColors.accent)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildChannelCard(context, 'Export', exports.toString(), Icons.flight_takeoff_rounded, AppColors.warning)),
                  ],
                ),
                const SizedBox(height: 48),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT: Interactive Cooperatives
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Active Cooperatives', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                          const SizedBox(height: 24),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: data.cooperatives.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                              itemBuilder: (context, index) {
                                final coop = data.cooperatives[index];
                                
                                return Container(
                                  padding: const EdgeInsets.all(24),
                                  color: Colors.transparent,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.transparent)),
                                        child: const Icon(Icons.groups_rounded, color: AppColors.secondaryText),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(coop['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text)),
                                            const SizedBox(height: 4),
                                            Text(coop['location'] ?? 'Location N/A', style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 48),
                          const Text('Market Channels', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                          const SizedBox(height: 24),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: data.marketChannels.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                              itemBuilder: (context, index) {
                                final mc = data.marketChannels[index];
                                
                                return Container(
                                  padding: const EdgeInsets.all(24),
                                  color: Colors.transparent,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.transparent)),
                                        child: const Icon(Icons.storefront_rounded, color: AppColors.secondaryText),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(mc['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text)),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(color: AppColors.border.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
                                                  child: Text(mc['type'] ?? 'N/A', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(mc['location'] ?? 'Location N/A', style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 48),
                          const Text('Volume & Crop by Channel', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                          const SizedBox(height: 24),
                          Container(
                            height: 350,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: data.channelCropMix.isEmpty 
                              ? const Center(child: Text('No data available', style: TextStyle(color: AppColors.secondaryText)))
                              : BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    barTouchData: BarTouchData(enabled: true),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 40,
                                          getTitlesWidget: (value, meta) {
                                            if (value.toInt() >= data.channelCropMix.length) return const Text('');
                                            String channel = data.channelCropMix[value.toInt()]['channel'];
                                            if (channel == 'association_surplus_buy_back') channel = 'Assoc. Buy-back';
                                            else if (channel == 'neighbouring_municipality') channel = 'Neighbor Muni.';
                                            
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Text(
                                                channel.replaceAll('_', ' ').toUpperCase(),
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondaryText),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      leftTitles: const AxisTitles(
                                        sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                                      ),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      getDrawingHorizontalLine: (value) => const FlLine(color: AppColors.border, strokeWidth: 1),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    barGroups: data.channelCropMix.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final item = entry.value;
                                      final crops = item['crops'] as Map<String, double>;
                                      
                                      // Create stacked rod data
                                      List<BarChartRodStackItem> stackItems = [];
                                      double currentY = 0;
                                      
                                      // Simple predefined colors for top crops
                                      final colors = [AppColors.primary, AppColors.information, AppColors.warning, Colors.purple, Colors.teal];
                                      int colorIdx = 0;
                                      
                                      crops.forEach((crop, volume) {
                                        if (volume > 0) {
                                          stackItems.add(BarChartRodStackItem(currentY, currentY + volume, colors[colorIdx % colors.length]));
                                          currentY += volume;
                                          colorIdx++;
                                        }
                                      });
                                      
                                      return BarChartGroupData(
                                        x: index,
                                        barRods: [
                                          BarChartRodData(
                                            toY: currentY,
                                            width: 40,
                                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                                            rodStackItems: stackItems,
                                          )
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                          ),
                          const SizedBox(height: 16),
                          if (data.channelCropMix.isNotEmpty)
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: () {
                                final Set<String> allCrops = {};
                                for (var item in data.channelCropMix) {
                                  final crops = item['crops'] as Map<String, double>;
                                  allCrops.addAll(crops.keys.where((k) => crops[k]! > 0));
                                }
                                final colors = [AppColors.primary, AppColors.information, AppColors.warning, Colors.purple, Colors.teal];
                                int idx = 0;
                                return allCrops.map((crop) {
                                  final color = colors[idx % colors.length];
                                  idx++;
                                  return _buildLegendItem(crop.toUpperCase(), color);
                                }).toList();
                              }(),
                            )
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                    // RIGHT: Map details & GitHub feed
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Activity Feed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondaryText, letterSpacing: 1.5)),
                          const SizedBox(height: 24),
                          if (data.activities.isEmpty)
                            const Text('No recent activity.', style: TextStyle(color: AppColors.secondaryText))
                          else
                            ...data.activities.map((activity) {
                              final user = activity['profiles']?['full_name'] as String? ?? 'Unknown User';
                              final status = activity['status'] as String? ?? 'submitted';
                              final action = status == 'pending' ? 'submitted a' : status;
                              final cropId = activity['crop_id'] as String? ?? 'crop';
                              final target = cropId.isNotEmpty ? cropId[0].toUpperCase() + cropId.substring(1).replaceAll('_', ' ') : 'Crop';
                              
                              String timeStr = 'just now';
                              if (activity['created_at'] != null) {
                                final time = DateTime.parse(activity['created_at']);
                                final diff = DateTime.now().difference(time);
                                if (diff.inMinutes < 1) {
                                  timeStr = 'just now';
                                } else if (diff.inMinutes < 60) {
                                  timeStr = '${diff.inMinutes} min ago';
                                } else if (diff.inHours < 24) {
                                  timeStr = '${diff.inHours} hrs ago';
                                } else {
                                  timeStr = '${diff.inDays} days ago';
                                }
                              }
                              
                              final isSuccess = status == 'approved' || status == 'accepted' || status == 'approved_by_baw';
                              final isSystem = false;
                              
                              return _buildGitHubFeedItem(user, action, target, timeStr, isSuccess: isSuccess, isSystem: isSystem);
                            }).toList(),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 48),
                // V2: DISPOSITION FUNNEL
                const Text('Crop Disposition (V2)', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                const Text('Reported usage as % of declared volume. Sorted by highest leakage + unreported.', style: TextStyle(color: AppColors.secondaryText, fontSize: 14)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: data.v2Data.isEmpty 
                    ? const Text('No disposition data available.', style: TextStyle(color: AppColors.secondaryText))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...data.v2Data.map((crop) => Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(crop['crop_id'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Row(
                                    children: [
                                      if (crop['monitored'] > 0) Expanded(flex: (crop['monitored'] * 100).toInt(), child: Container(height: 24, color: AppColors.primary)),
                                      if (crop['own_consumption'] > 0) Expanded(flex: (crop['own_consumption'] * 100).toInt(), child: Container(height: 24, color: AppColors.information)),
                                      if (crop['leaked'] > 0) Expanded(flex: (crop['leaked'] * 100).toInt(), child: Container(height: 24, color: AppColors.warning)),
                                      if (crop['loss'] > 0) Expanded(flex: (crop['loss'] * 100).toInt(), child: Container(height: 24, color: Colors.orange)),
                                      if (crop['unreported'] > 0) Expanded(flex: (crop['unreported'] * 100).toInt(), child: Container(height: 24, color: AppColors.danger)),
                                      if (crop['shortfall'] > 0) Expanded(flex: (crop['shortfall'] * 100).toInt(), child: Container(height: 24, color: AppColors.border)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 12,
                                  children: [
                                    _buildLegendItem('Monitored (${crop['monitored'].toStringAsFixed(1)}%)', AppColors.primary),
                                    _buildLegendItem('Own Cons. (${crop['own_consumption'].toStringAsFixed(1)}%)', AppColors.information),
                                    _buildLegendItem('Leaked (${crop['leaked'].toStringAsFixed(1)}%)', AppColors.warning),
                                    _buildLegendItem('Loss (${crop['loss'].toStringAsFixed(1)}%)', Colors.orange),
                                    _buildLegendItem('Unreported (${crop['unreported'].toStringAsFixed(1)}%)', AppColors.danger),
                                    _buildLegendItem('Shortfall (${crop['shortfall'].toStringAsFixed(1)}%)', AppColors.border),
                                  ],
                                )
                              ],
                            ),
                          )).toList(),
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

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
      ],
    );
  }

  Widget _buildChannelCard(BuildContext context, String title, String count, IconData icon, Color color, {VoidCallback? onTap}) {
    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.secondaryText)),
                  Icon(icon, color: color, size: 20),
                ],
              ),
              const SizedBox(height: 16),
              Text(count, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGitHubFeedItem(String user, String action, String target, String time, {bool isSuccess = false, bool isSystem = false}) {
    Color dotColor = isSystem ? AppColors.secondaryText : (isSuccess ? AppColors.primary : AppColors.information);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: dotColor.withOpacity(0.3), blurRadius: 4)])),
              Container(width: 2, height: 40, color: AppColors.border), // connector
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: AppColors.text, fontFamily: 'Inter', fontSize: 14),
                    children: [
                      TextSpan(text: user, style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: ' $action ', style: const TextStyle(color: AppColors.secondaryText)),
                      TextSpan(text: target, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]
                  )
                ),
                const SizedBox(height: 4),
                Text(time, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class CircularGaugePainter extends CustomPainter {
  final double progress;
  final Color color;

  CircularGaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2);
    
    final bgPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, bgPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle * progress, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
