import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/KMS/core/constants/app_style.dart';
import 'package:innovator/KMS/model/coordinator_model/coordinator_teacher_response_model.dart';
import 'package:innovator/KMS/provider/coordinator_provider.dart';
import 'package:innovator/KMS/screens/coordinator/coordinator_shared_widget.dart'; 

final _approvalFilterProvider = StateProvider<String>((ref) => 'ALL');

class CoordinatorAttendanceApprovalScreen extends ConsumerWidget {
  const CoordinatorAttendanceApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(coordinatorAttendanceProvider);
    final filter = ref.watch(_approvalFilterProvider);

    return Scaffold(
      backgroundColor: AppStyle.primaryColor,
      appBar: AppBar(
        backgroundColor: AppStyle.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Attendance Approval',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => ref.refresh(coordinatorAttendanceProvider),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.refresh_rounded,
                    size: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // stats
          attendanceAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (data) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  CoordinatorMiniStat(
                      label: 'Total',
                      value: '${data.total}',
                      color: Colors.white),
                  const SizedBox(width: 10),
                  CoordinatorMiniStat(
                      label: 'Pending',
                      value: '${data.pending}',
                      color: const Color(0xFFFFB347)),
                  const SizedBox(width: 10),
                  CoordinatorMiniStat(
                    label: 'Approved',
                    value:
                        '${data.attendances.where((a) => a.isApproved).length}',
                    color: Colors.greenAccent.shade200,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F7FA),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: CoordinatorFilterChips(
                        provider: _approvalFilterProvider),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: attendanceAsync.when(
                      loading: () => const Center(
                          child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: CoordinatorErrorBox(error: e,)
                      ),
                      data: (data) {
                        final list = filter == 'ALL'
                            ? data.attendances
                            : data.attendances
                                .where((a) => a.status == filter)
                                .toList();

                        if (list.isEmpty) {
                          return CoordinatorEmptyState(
                            icon: filter == 'ALL'
                                ? Icons.check_circle_rounded
                                : Icons.filter_list_rounded,
                            message: filter == 'ALL'
                                ? 'No attendance records'
                                : 'No ${filter.toLowerCase()} records',
                          );
                        }

                        return ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: list.length,
                          itemBuilder: (context, i) {
                            final item = list[i];
                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CoordinatorAttendanceDetailScreen(
                                          item: item),
                                ),
                              ),
                              child: CoordinatorAttendanceTile(item: item),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Attendance Detail Screen ─────────────────────────────────────────────────

class CoordinatorAttendanceDetailScreen extends ConsumerStatefulWidget {
  final CoordinatorAttendanceModel item;
  const CoordinatorAttendanceDetailScreen({super.key, required this.item});

  @override
  ConsumerState<CoordinatorAttendanceDetailScreen> createState() =>
      _CoordinatorAttendanceDetailScreenState();
}

class _CoordinatorAttendanceDetailScreenState
    extends ConsumerState<CoordinatorAttendanceDetailScreen> {
  bool _isLoading = false;
  String? _localStatus;

  String get _status => _localStatus ?? widget.item.status;

  Future<void> _act(String action, {String? reason}) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(
        updateAttendanceProvider({
          'attendanceId': widget.item.id,
          'action': action,
        }).future,
      );
      setState(() =>
          _localStatus = action == 'approve' ? 'APPROVED' : 'REJECTED');
      if (mounted) {
        ref.refresh(coordinatorAttendanceProvider);
        _snack(
          action == 'approve'
              ? 'Attendance approved!'
              : 'Attendance rejected.',
          action == 'approve' ? Colors.green : Colors.red.shade400,
          action == 'approve'
              ? Icons.check_circle_rounded
              : Icons.cancel_rounded,
        );
      }
    } catch (e) {
      if (mounted)
        _snack('Failed: $e', Colors.red.shade400, Icons.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, Color color, IconData icon) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(msg, style: const TextStyle(fontFamily: 'Inter')),
        ]),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ));
  }

  void _showRejectDialog() {
    final ctrl = TextEditingController();
    showAdaptiveDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text('Reason for Rejection',
            style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter reason (optional)...',
            hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontFamily: 'Inter',
                fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF5F7FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    color: Colors.grey.shade500, fontFamily: 'Inter')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _act('reject', reason: ctrl.text.trim());
            },
            child: const Text('Reject',
                style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = _status == 'PENDING';
    final isApproved = _status == 'APPROVED';
    final statusColor = isPending
        ? const Color(0xFFE85D04)
        : isApproved
            ? const Color(0xFF059669)
            : Colors.red;

    return Scaffold( 
        backgroundColor: AppStyle.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppStyle.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Attendance Detail',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
            fontSize: 18,
          ),
        ),
      ),
      body: Container(
     
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // teacher card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor:
                          AppStyle.primaryColor.withValues(alpha: 0.12),
                      child: Text(
                        widget.item.teacherName[0],
                        style: TextStyle(
                            color: AppStyle.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            fontFamily: 'Inter'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(widget.item.teacherName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            fontFamily: 'Inter',
                            color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text(widget.item.schoolName,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            fontFamily: 'Inter')),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _status,
                        style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            color: statusColor),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // info rows
              _DetailCard(children: [
                _DetailRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Date',
                    value:
                        '${widget.item.date.day}/${widget.item.date.month}/${widget.item.date.year}'),
                _DetailRow(
                    icon: Icons.school_rounded,
                    label: 'School',
                    value: widget.item.schoolName),
              ]),

              const SizedBox(height: 24),

              // action area
              if (_isLoading)
                const Center(
                    child: CircularProgressIndicator())
              else if (!isPending)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isApproved
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isApproved
                          ? Colors.green.shade300
                          : Colors.red.shade300,
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isApproved
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: isApproved ? Colors.green : Colors.red,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isApproved ? 'Approved' : 'Rejected',
                          style: TextStyle(
                            color: isApproved
                                ? Colors.green.shade700
                                : Colors.red.shade600,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _showRejectDialog,
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: Colors.red.shade200),
                          ),
                          child: Center(
                            child: Text('Reject',
                                style: TextStyle(
                                    color: Colors.red.shade600,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Inter',
                                    fontSize: 15)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _act('approve'),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.green.shade300),
                          ),
                          child: Center(
                            child: Text('Approve',
                                style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Inter',
                                    fontSize: 15)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared detail widgets ────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  final List<Widget> children;
  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontFamily: 'Inter')),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}