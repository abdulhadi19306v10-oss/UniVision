import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/bridge_client.dart';

class TopBar extends StatelessWidget {
  final BridgeClient client;

  const TopBar({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final user = client.currentUser;
    final role = (user?['role'] ?? 'admin').toString().toLowerCase();
    final fullName = user?['full_name'] ?? 'User';
    final rollNo = user?['roll_no'] ?? user?['username'] ?? '';

    final activeSession = client.status['active_session'];
    final bool hasActiveSession = activeSession != null && activeSession['local_id'] != null;

    String headerTitle = '';
    IconData headerIcon = Icons.info_outline;
    Color headerColor = AppTheme.textMuted;

    if (role == 'student') {
      headerTitle = 'Student Portal • Welcome $fullName ($rollNo)';
      headerIcon = Icons.person_rounded;
      headerColor = const Color(0xFFA855F7);
    } else if (role == 'teacher') {
      headerTitle = hasActiveSession
          ? 'Active Session #${activeSession['local_id']} • ${activeSession['course_code']} - ${activeSession['course_name']}'
          : 'Teacher Portal • Ready to configure and start class session';
      headerIcon = hasActiveSession ? Icons.sensors : Icons.school_rounded;
      headerColor = hasActiveSession ? AppTheme.primary : AppTheme.success;
    } else {
      headerTitle = hasActiveSession
          ? 'Active Session #${activeSession['local_id']} • ${activeSession['course_code']} - ${activeSession['course_name']}'
          : 'Administrator Console • System Overview & Biometric Station';
      headerIcon = hasActiveSession ? Icons.sensors : Icons.security_rounded;
      headerColor = AppTheme.primary;
    }

    final int presentCount = client.status['stats']?['total_present'] ?? client.liveRoster.length;
    final double fps = (client.status['camera']?['fps'] ?? 0.0).toDouble();
    final int pendingSync = client.status['stats']?['pending_sync'] ?? 0;
    final int enrolledCount = client.status['stats']?['enrolled_students'] ?? client.enrolledStudents.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(headerIcon, color: headerColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              headerTitle,
              style: TextStyle(
                color: hasActiveSession || role == 'student' ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: hasActiveSession ? FontWeight.w600 : FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),

          // Role-Specific KPI Chips
          if (role == 'student') ...[
            _buildKpiChip('ROLL', rollNo.isNotEmpty ? rollNo : 'N/A', AppTheme.primary),
            const SizedBox(width: 12),
            _buildKpiChip('STATUS', 'Good Standing', AppTheme.success),
            const SizedBox(width: 12),
            _buildKpiChip('CLASSES', '${client.studentAttendanceRecords.length}', const Color(0xFFA855F7)),
          ] else ...[
            _buildKpiChip('PRESENT', presentCount.toString(), AppTheme.primary),
            const SizedBox(width: 12),
            _buildKpiChip('FPS', fps.toStringAsFixed(1), AppTheme.success),
            const SizedBox(width: 12),
            _buildKpiChip('SYNC QUEUE', pendingSync.toString(), AppTheme.warning),
          ],
        ],
      ),
    );
  }

  Widget _buildKpiChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSunken,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
