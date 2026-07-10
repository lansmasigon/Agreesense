import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_actions.dart';
import '../../core/theme/app_colors.dart';

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
  final List<String> _statuses = ['All', 'pending', 'baw_approved', 'approved', 'rejected'];
  Map<String, dynamic>? _selectedDeclaration;

  String _formatCropId(String id) {
    if (id.isEmpty) return id;
    return id[0].toUpperCase() + id.substring(1).replaceAll('_', ' ');
  }

  void _closeDrawer() {
    setState(() {
      _selectedDeclaration = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final declarationsAsync = ref.watch(validationQueueProvider);
    final user = ref.watch(currentUserProvider);
    final userRole = user?['role'] as String?;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: declarationsAsync.when(
        data: (declarations) {
          final filteredDeclarations = _selectedStatus == 'All'
              ? declarations
              : declarations.where((d) => d['status'] == _selectedStatus).toList();

          return Row(
            children: [
              // Left: Queue List
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Validation Queue', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text, letterSpacing: -0.5)),
                          _buildFilterDropdown(),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filteredDeclarations.isEmpty
                        ? const Center(child: Text('No declarations found.', style: TextStyle(color: AppColors.secondaryText)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            itemCount: filteredDeclarations.length,
                            itemBuilder: (context, index) {
                              final declaration = filteredDeclarations[index];
                              final isSelected = _selectedDeclaration?['id'] == declaration['id'];
                              return _buildQueueCard(declaration, isSelected);
                            },
                          ),
                    ),
                  ],
                ),
              ),

              // Right: Drawer Workflow
              if (_selectedDeclaration != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutQuart,
                  width: 500,
                  decoration: const BoxDecoration(
                    color: AppColors.card,
                    border: Border(left: BorderSide(color: AppColors.border)),
                  ),
                  child: _buildWorkflowDrawer(_selectedDeclaration!, userRole),
                )
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.danger))),
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatus,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.secondaryText),
          items: _statuses.map((status) {
            return DropdownMenuItem(
              value: status,
              child: Text(status.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedStatus = value);
              _closeDrawer();
            }
          },
        ),
      ),
    );
  }

  Widget _buildQueueCard(Map<String, dynamic> declaration, bool isSelected) {
    final farmerName = declaration['profiles']?['full_name'] ?? 'Unknown Farmer';
    final cropName = _formatCropId(declaration['crop_id'] as String? ?? '');
    final area = declaration['area_ha'] ?? 0;
    final status = declaration['status'] as String? ?? 'pending';

    return GestureDetector(
      onTap: () {
        setState(() => _selectedDeclaration = declaration);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 4))] : [],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.grass_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cropName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text)),
                  const SizedBox(height: 4),
                  Text('$farmerName • $area ha', style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _buildStatusChip(status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'pending': color = AppColors.warning; break;
      case 'baw_approved': color = AppColors.information; break;
      case 'approved': color = AppColors.primary; break;
      case 'rejected': color = AppColors.danger; break;
      default: color = AppColors.secondaryText;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildWorkflowDrawer(Map<String, dynamic> declaration, String? userRole) {
    final status = declaration['status'] as String? ?? 'pending';
    final id = declaration['id'] as String;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.close), onPressed: _closeDrawer),
              const SizedBox(width: 16),
              const Text('Review Workflow', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT: Declaration Info
              Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DECLARATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondaryText, letterSpacing: 1.2)),
                      const SizedBox(height: 16),
                      _buildInfoRow('Farmer', declaration['profiles']?['full_name'] ?? 'Unknown'),
                      _buildInfoRow('Crop', _formatCropId(declaration['crop_id'] as String? ?? '')),
                      _buildInfoRow('Area', '${declaration['area_ha']} ha'),
                      _buildInfoRow('Barangay', declaration['barangay'] ?? 'N/A'),
                      const SizedBox(height: 32),
                      const Text('DOCUMENTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondaryText, letterSpacing: 1.2)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
                        child: const Row(
                          children: [
                            Icon(Icons.insert_drive_file_outlined, color: AppColors.primary, size: 16),
                            SizedBox(width: 8),
                            Text('Land_Title.pdf', style: TextStyle(fontSize: 13, color: AppColors.text)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1, color: AppColors.border),
              // RIGHT: Approval Timeline
              Expanded(
                flex: 1,
                child: Container(
                  color: AppColors.background,
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TIMELINE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondaryText, letterSpacing: 1.2)),
                      const SizedBox(height: 24),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTimelineNode('Pending', isActive: status == 'pending', isPast: ['baw_approved', 'approved'].contains(status)),
                              _buildTimelineNode('BAW Review', isActive: status == 'baw_approved', isPast: status == 'approved'),
                              _buildTimelineNode('MAO Approval', isActive: status == 'approved', isPast: false, isLast: true),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      if (_canReview(status, userRole)) ...[
                        const TextField(
                          decoration: InputDecoration(
                            hintText: 'Add remarks...',
                            filled: true,
                            fillColor: AppColors.card,
                            border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12))),
                            contentPadding: EdgeInsets.all(16)
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _updateStatus(id, 'rejected'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  foregroundColor: AppColors.danger,
                                  side: const BorderSide(color: AppColors.danger),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                ),
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _updateStatus(id, _getNextStatus(status)),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: AppColors.primary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                ),
                                child: const Text('Approve', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                          ],
                        )
                      ] else if (status == 'rejected') ...[
                         Container(
                           padding: const EdgeInsets.all(16),
                           decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                           child: const Row(children: [Icon(Icons.cancel, color: AppColors.danger), SizedBox(width: 8), Expanded(child: Text('Declaration Rejected', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)))]),
                         )
                      ] else if (status == 'approved') ...[
                         Container(
                           padding: const EdgeInsets.all(16),
                           decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                           child: const Row(children: [Icon(Icons.check_circle, color: AppColors.primary), SizedBox(width: 8), Expanded(child: Text('Workflow Completed', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)))]),
                         )
                      ]
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
        ],
      ),
    );
  }

  Widget _buildTimelineNode(String title, {required bool isActive, required bool isPast, bool isLast = false}) {
    final color = isPast ? AppColors.primary : (isActive ? AppColors.accent : AppColors.border);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? color : Colors.transparent,
                  border: Border.all(color: color, width: 2),
                  boxShadow: isActive ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)] : [],
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: isPast ? AppColors.primary : AppColors.border)),
            ],
          ),
          const SizedBox(width: 16),
          Padding(
            padding: const EdgeInsets.only(bottom: 32.0),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: (isActive || isPast) ? AppColors.text : AppColors.secondaryText,
              ),
            ),
          )
        ],
      ),
    );
  }

  bool _canReview(String status, String? role) {
    if (role == 'baw' && status == 'pending') return true;
    if (role == 'mao' && status == 'baw_approved') return true;
    return false;
  }

  String _getNextStatus(String current) {
    if (current == 'pending') return 'baw_approved';
    if (current == 'baw_approved') return 'approved';
    return current;
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    await ref.read(supabaseClientProvider).from('crop_declarations').update({'status': newStatus}).eq('id', id);
    ref.invalidate(validationQueueProvider);
    _closeDrawer();
  }
}
