import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/bridge_client.dart';

class StudentAttendanceScreen extends StatefulWidget {
  final BridgeClient client;

  const StudentAttendanceScreen({super.key, required this.client});

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    widget.client.loadStudentAttendance();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportCsv() async {
    setState(() => _isExporting = true);
    final filePath = await widget.client.exportStudentCsv();
    if (!mounted) return;
    setState(() => _isExporting = false);

    if (filePath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance report exported to:\n$filePath'),
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendance records available to export.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.client.currentUser;
    final fullName = user?['full_name'] ?? 'Student';
    final rollNo = user?['roll_no'] ?? user?['username'] ?? '';

    final query = _searchCtrl.text.trim().toLowerCase();
    final records = widget.client.studentAttendanceRecords.where((r) {
      if (query.isEmpty) return true;
      final code = (r['course_code'] ?? '').toString().toLowerCase();
      final name = (r['course_name'] ?? '').toString().toLowerCase();
      final date = (r['marked_at'] ?? '').toString().toLowerCase();
      return code.contains(query) || name.contains(query) || date.contains(query);
    }).toList();

    return Column(
      children: [
        // 1. Top Summary KPI Cards
        Row(
          children: [
            _buildStatCard(
              'CLASSES ATTENDED',
              '${widget.client.studentAttendanceRecords.length} Lectures',
              Icons.school_rounded,
              AppTheme.primary,
            ),
            const SizedBox(width: 14),
            _buildStatCard(
              'LATEST ATTENDANCE',
              widget.client.studentAttendanceRecords.isNotEmpty
                  ? _formatDate(widget.client.studentAttendanceRecords.first['marked_at'])
                  : 'No records yet',
              Icons.access_time_rounded,
              AppTheme.success,
            ),
            const SizedBox(width: 14),
            _buildStatCard(
              'VERIFICATION',
              'Biometric Face',
              Icons.fingerprint_rounded,
              const Color(0xFFA855F7),
            ),
            const SizedBox(width: 14),
            _buildStatCard(
              'ACADEMIC STATUS',
              'Good Standing',
              Icons.verified_rounded,
              AppTheme.success,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 2. Main Records Table Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Bar
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Verified Attendance Records',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Showing personal attendance history for $fullName ($rollNo)',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Search Filter
                    SizedBox(
                      width: 180,
                      height: 36,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Filter course or date...',
                          prefixIcon: const Icon(Icons.search, size: 16, color: AppTheme.textMuted),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 14),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Refresh Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onPressed: () => widget.client.loadStudentAttendance(),
                      icon: const Icon(Icons.refresh, size: 15, color: AppTheme.textPrimary),
                      label: const Text('Refresh', style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 8),

                    // Export CSV Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: _isExporting ? null : _exportCsv,
                      icon: const Icon(Icons.download_rounded, size: 15),
                      label: Text(_isExporting ? 'Exporting...' : 'Export My Report (CSV)',
                          style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSunken,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(width: 60, child: Text('#', style: _headerStyle)),
                      SizedBox(width: 100, child: Text('Course Code', style: _headerStyle)),
                      Expanded(flex: 3, child: Text('Course Name', style: _headerStyle)),
                      Expanded(flex: 3, child: Text('Marked Time', style: _headerStyle)),
                      Expanded(flex: 2, child: Text('Method', style: _headerStyle)),
                      Expanded(flex: 2, child: Text('Confidence', style: _headerStyle)),
                      SizedBox(width: 110, child: Text('Sync Status', style: _headerStyle)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Table Content Rows
                Expanded(
                  child: records.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.assignment_outlined, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              const Text(
                                'No attendance records found for this student.',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: records.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
                          itemBuilder: (context, index) {
                            final r = records[index];
                            final conf = r['confidence'];
                            final confStr = conf != null ? '${((conf as num) * 100).toInt()}%' : 'N/A';
                            final isSynced = r['synced'] == 1;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      '#${r['id'] ?? (index + 1)}',
                                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      r['course_code'] ?? 'CS-401',
                                      style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      r['course_name'] ?? 'Lecture Session',
                                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      _formatDate(r['marked_at']),
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      children: [
                                        Icon(
                                          (r['method'] ?? 'face') == 'manual' ? Icons.edit_note_rounded : Icons.face_rounded,
                                          size: 14,
                                          color: AppTheme.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          (r['method'] ?? 'face').toString().toUpperCase(),
                                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      confStr,
                                      style: TextStyle(
                                        color: conf != null && (conf as num) >= 0.75 ? AppTheme.success : AppTheme.warning,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 110,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isSynced ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.warning.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isSynced ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.warning.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        isSynced ? 'SYNCED' : 'QUEUED',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: isSynced ? AppTheme.success : AppTheme.warning,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return 'N/A';
    final str = raw.toString();
    if (str.length >= 19) {
      return str.substring(0, 19).replaceAll('T', ' ');
    }
    return str;
  }

  static const TextStyle _headerStyle = TextStyle(
    color: AppTheme.textMuted,
    fontSize: 11,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
  );
}
