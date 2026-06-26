import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_actions.dart';

final validationQueueProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  
  final res = await supabase
      .from('crop_declarations')
      .select('*, profiles(full_name)')
      .order('created_at', ascending: false);
      
  return List<Map<String, dynamic>>.from(res as List);
});

class ValidationQueueScreen extends ConsumerStatefulWidget {
  const ValidationQueueScreen({super.key});

  @override
  ConsumerState<ValidationQueueScreen> createState() => _ValidationQueueScreenState();
}

class _ValidationQueueScreenState extends ConsumerState<ValidationQueueScreen> {
  String _selectedStatus = 'All';
  final List<String> _statuses = ['All', 'pending', 'baw_approved', 'technician_verified', 'approved', 'rejected'];

  String _formatCropId(String id) {
    if (id.isEmpty) return id;
    return id[0].toUpperCase() + id.substring(1).replaceAll('_', ' ');
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'pending':
        bgColor = const Color(0xFFFFFBEB);
        textColor = const Color(0xFFD97706);
        icon = Icons.access_time_filled;
        break;
      case 'baw_approved':
        bgColor = const Color(0xFFEFF6FF);
        textColor = const Color(0xFF2563EB);
        icon = Icons.shield;
        break;
      case 'technician_verified':
        bgColor = const Color(0xFFFAF5FF);
        textColor = const Color(0xFF9333EA);
        icon = Icons.verified;
        break;
      case 'approved':
        bgColor = const Color(0xFFF0FDF4);
        textColor = const Color(0xFF16A34A);
        icon = Icons.check_circle;
        break;
      case 'rejected':
        bgColor = const Color(0xFFFEF2F2);
        textColor = const Color(0xFFDC2626);
        icon = Icons.cancel;
        break;
      default:
        bgColor = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF64748B);
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            status.replaceAll('_', ' ').toUpperCase(),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final declarationsAsync = ref.watch(validationQueueProvider);
    final user = ref.watch(currentUserProvider);
    final userRole = user?['role'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Validation Queue', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                    style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                    items: _statuses.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedStatus = value;
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
          )
        ],
      ),
      body: declarationsAsync.when(
        data: (declarations) {
          final filteredDeclarations = _selectedStatus == 'All'
              ? declarations
              : declarations.where((d) => d['status'] == _selectedStatus).toList();

          if (filteredDeclarations.isEmpty) {
            return const Center(child: Text('No declarations found.', style: TextStyle(color: Color(0xFF64748B))));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
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
                itemCount: filteredDeclarations.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final declaration = filteredDeclarations[index];
                  final farmerName = declaration['profiles']?['full_name'] ?? 'Unknown Farmer';
                  final cropId = declaration['crop_id'] as String? ?? 'unknown';
                  final cropName = _formatCropId(cropId);
                  final status = declaration['status'] as String? ?? 'pending';

                  final canReview = (userRole == 'baw' && status == 'pending') ||
                                    (userRole == 'technician' && status == 'baw_approved') ||
                                    (userRole == 'mao' && status == 'technician_verified');
                  
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.assignment_turned_in, color: Color(0xFF3B82F6)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$cropName - $farmerName', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                              const SizedBox(height: 4),
                              Text('Area: ${declaration['area_ha']} ha', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        _buildStatusBadge(status),
                        if (canReview) ...[
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () {
                              _showReviewDialog(context, declaration, userRole);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Review', style: TextStyle(color: Colors.white)),
                          )
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  void _showReviewDialog(BuildContext context, Map<String, dynamic> declaration, String? userRole) {
    final TextEditingController remarksController = TextEditingController();
    final status = declaration['status'] as String;
    final id = declaration['id'] as String;
    final farmerName = declaration['profiles']?['full_name'] ?? 'Unknown Farmer';
    final cropId = declaration['crop_id'] as String? ?? 'unknown';
    final cropName = _formatCropId(cropId);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Review Declaration $id'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Farmer: $farmerName'),
              Text('Crop: $cropName'),
              Text('Area Planted: ${declaration['area_ha']} ha'),
              Text('Status: $status'),
              const SizedBox(height: 16),
              const Text('Remarks:'),
              TextField(
                controller: remarksController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter remarks here...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            if (userRole == 'baw' && status == 'pending')
              ElevatedButton(
                onPressed: () async {
                  await ref.read(supabaseClientProvider).from('crop_declarations').update({'status': 'baw_approved'}).eq('id', id);
                  ref.invalidate(validationQueueProvider);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('BAW Approve'),
              ),
            if (userRole == 'technician' && status == 'baw_approved')
              ElevatedButton(
                onPressed: () async {
                  await ref.read(supabaseClientProvider).from('crop_declarations').update({'status': 'technician_verified'}).eq('id', id);
                  ref.invalidate(validationQueueProvider);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Verify'),
              ),
            if (userRole == 'mao' && status == 'technician_verified')
              ElevatedButton(
                onPressed: () async {
                  await ref.read(supabaseClientProvider).from('crop_declarations').update({'status': 'approved'}).eq('id', id);
                  ref.invalidate(validationQueueProvider);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Approve'),
              ),
            ElevatedButton(
              onPressed: () async {
                await ref.read(supabaseClientProvider).from('crop_declarations').update({'status': 'rejected'}).eq('id', id);
                ref.invalidate(validationQueueProvider);
                if (context.mounted) Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reject', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
