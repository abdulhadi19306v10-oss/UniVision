import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/bridge_client.dart';

// ponytail: top header bar with active session state and KPI chips
class TopBar extends StatelessWidget {
  final BridgeClient client;

  const TopBar({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final activeSession = client.status['active_session'];
    final bool hasActiveSession = activeSession != null && activeSession['local_id'] != null;
    final String sessionTitle = hasActiveSession
        ? 'Active Session #${activeSession['local_id']} • ${activeSession['course_code']} - ${activeSession['course_name']}'
        : 'No active lecture session. Configure course and start session below.';

    final int presentCount = client.status['stats']?['total_present'] ?? client.liveRoster.length;
    final double fps = (client.status['camera']?['fps'] ?? 0.0).toDouble();
    final int pendingSync = client.status['stats']?['pending_sync'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(
            hasActiveSession ? Icons.sensors : Icons.info_outline,
            color: hasActiveSession ? AppTheme.primary : AppTheme.textMuted,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              sessionTitle,
              style: TextStyle(
                color: hasActiveSession ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: hasActiveSession ? FontWeight.w600 : FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
          _buildKpiChip('PRESENT', presentCount.toString(), AppTheme.primary),
          const SizedBox(width: 12),
          _buildKpiChip('FPS', fps.toStringAsFixed(1), AppTheme.success),
          const SizedBox(width: 12),
          _buildKpiChip('SYNC QUEUE', pendingSync.toString(), AppTheme.warning),
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
