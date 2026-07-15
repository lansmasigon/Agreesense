import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import 'dart:math' as math;

class SupplyChainData {
  final List<Map<String, dynamic>> marketChannels;
  final List<Map<String, dynamic>> cooperatives;
  final List<Map<String, dynamic>> activities;

  SupplyChainData({required this.marketChannels, required this.cooperatives, required this.activities});
}

final supplyChainProvider = FutureProvider.autoDispose<SupplyChainData>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  final mcRes = await supabase.from('market_channels').select();
  final coopRes = await supabase.from('cooperatives').select();
  
  // Fetch recent activities (crop declarations)
  final activitiesRes = await supabase.from('crop_declarations')
      .select('status, created_at, crop_id, profiles(full_name)')
      .order('created_at', ascending: false)
      .limit(5);

  return SupplyChainData(
    marketChannels: List<Map<String, dynamic>>.from(mcRes as List),
    cooperatives: List<Map<String, dynamic>>.from(coopRes as List),
    activities: List<Map<String, dynamic>>.from(activitiesRes as List),
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
                                final isSelected = _selectedCoop?['id'] == coop['id'];
                                
                                return InkWell(
                                  onTap: () => setState(() => _selectedCoop = coop),
                                  child: Container(
                                    padding: const EdgeInsets.all(24),
                                    color: isSelected ? AppColors.accent.withOpacity(0.05) : Colors.transparent,
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent)),
                                          child: Icon(Icons.groups_rounded, color: isSelected ? AppColors.primary : AppColors.secondaryText),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(coop['name'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSelected ? AppColors.primary : AppColors.text)),
                                              const SizedBox(height: 4),
                                              Text(coop['location'] ?? 'Location N/A', style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                        if (isSelected) const Icon(Icons.map_rounded, color: AppColors.primary),
                                      ],
                                    ),
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
                                final isSelected = _selectedMarket?['name'] == mc['name'];
                                
                                return InkWell(
                                  onTap: () => setState(() => _selectedMarket = mc),
                                  child: Container(
                                    padding: const EdgeInsets.all(24),
                                    color: isSelected ? AppColors.accent.withOpacity(0.05) : Colors.transparent,
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent)),
                                          child: Icon(Icons.storefront_rounded, color: isSelected ? AppColors.primary : AppColors.secondaryText),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(mc['name'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSelected ? AppColors.primary : AppColors.text)),
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
                                        if (isSelected) const Icon(Icons.map_rounded, color: AppColors.primary),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 48),
                          const Text('Institutional Buyers', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
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
                              itemCount: 7,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                              itemBuilder: (context, index) {
                                final buyers = [
                                  'Walang gutom program',
                                  'Tesda',
                                  'Region 6 BFP',
                                  'Region 6 PNP',
                                  'St. Pauls',
                                  'Bantay kalusugan garin',
                                  'Robinson'
                                ];
                                final buyer = buyers[index];
                                
                                return Container(
                                  padding: const EdgeInsets.all(24),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                                        child: const Icon(Icons.business_rounded, color: AppColors.secondaryText),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(buyer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text)),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(color: AppColors.border.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
                                                  child: const Text('Institutional', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                                ),
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
                          if (_selectedCoop != null) ...[
                             Container(
                               height: 200,
                               width: double.infinity,
                               decoration: BoxDecoration(
                                 color: AppColors.card,
                                 borderRadius: BorderRadius.circular(24),
                                 border: Border.all(color: AppColors.primary, width: 2),
                                 image: const DecorationImage(
                                   image: NetworkImage('https://images.unsplash.com/photo-1524661135-423995f22d0b?q=80&w=600&auto=format&fit=crop'),
                                   fit: BoxFit.cover,
                                   opacity: 0.8
                                 )
                               ),
                               child: Center(
                                 child: Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                   decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
                                   child: Row(
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                       const Icon(Icons.location_on, color: AppColors.danger, size: 16),
                                       const SizedBox(width: 8),
                                       Text(_selectedCoop!['location'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                     ],
                                   ),
                                 ),
                               ),
                             ),
                             const SizedBox(height: 48),
                          ],

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
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
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
