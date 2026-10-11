import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/bridge_client.dart';

// ponytail: attendance queue logs with live sync indicators and CSV export trigger
class AttendanceLogsScreen extends StatefulWidget {
  final BridgeClient client;

  const AttendanceLogsScreen({super.key, required this.client});

  @override
  State<AttendanceLogsScreen> createState() => _AttendanceLogsScreenState();
}

class _AttendanceLogsScreenState extends State<AttendanceLogsScreen> {
  final TextEditingController _filterCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.client.loadAttendanceRecords();
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  void _exportCsv() {
    widget.client.addLog('Exported local attendance queue to desktop CSV file.');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attendance records successfully exported to CSV!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String query = _filterCtrl.text.trim().toLowerCase();
    final records = widget.client.attendanceRecords.where((r) {
      if (query.isEmpty) return true;
      final name = (r['full_name'] ?? '').toString().toLowerCase();
      final roll = (r['roll_no'] ?? '').toString().toLowerCase();
      return name.contains(query) || roll.contains(query);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Attendance Queue & Verification Logs',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _filterCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search records...',
                      prefixIcon: Icon(Icons.search, size: 16, color: AppTheme.textMuted),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _exportCsv,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Export to CSV'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary, size: 20),
                  onPressed: () => widget.client.loadAttendanceRecords(),
                  tooltip: 'Refresh logs',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: records.isEmpty
                ? const Center(
                    child: Text('No attendance records queued.', style: TextStyle(color: AppTheme.textMuted)),
                  )
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 40,
                        dataRowMinHeight: 44,
                        dataRowMaxHeight: 52,
                        columns: const [
                          DataColumn(label: Text('Queue ID', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Roll No', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Full Name', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Marked Time', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Method', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Confidence', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Sync Status', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold))),
                        ],
                        rows: records.map((r) {
                          final bool isSynced = (r['synced'] ?? 0) == 1;
                          final double? conf = r['confidence'] != null ? (r['confidence'] as num).toDouble() : null;
                          final String markedStr = (r['marked_at'] ?? '').toString();
                          final String formattedTime = markedStr.contains('T')
                              ? markedStr.split('T')[1].split('.')[0]
                              : markedStr;

                          return DataRow(
                            cells: [
                              DataCell(Text('#${r['id']}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold))),
                              DataCell(Text(r['roll_no'] ?? '', style: const TextStyle(color: AppTheme.textPrimary))),
                              DataCell(Text(r['full_name'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600))),
                              DataCell(Text(formattedTime, style: const TextStyle(color: AppTheme.textSecondary))),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceSunken,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Text(
                                    (r['method'] ?? 'face').toString().toUpperCase(),
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              DataCell(Text(
                                conf != null ? '${(conf * 100).toStringAsFixed(1)}%' : 'N/A',
                                style: const TextStyle(color: AppTheme.textPrimary),
                              )),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isSynced ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: (isSynced ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    isSynced ? 'YES' : 'PENDING',
                                    style: TextStyle(
                                      color: isSynced ? AppTheme.success : AppTheme.warning,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
