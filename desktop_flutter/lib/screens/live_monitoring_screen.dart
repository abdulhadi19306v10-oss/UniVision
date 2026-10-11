import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/bridge_client.dart';
import '../widgets/camera_stream_view.dart';

// ponytail: production live biometric monitoring screen with real video rendering and live roster
class LiveMonitoringScreen extends StatefulWidget {
  final BridgeClient client;

  const LiveMonitoringScreen({super.key, required this.client});

  @override
  State<LiveMonitoringScreen> createState() => _LiveMonitoringScreenState();
}

class _LiveMonitoringScreenState extends State<LiveMonitoringScreen> {
  final TextEditingController _codeCtrl = TextEditingController(text: 'CS-401');
  final TextEditingController _nameCtrl = TextEditingController(text: 'Software Architecture');
  final TextEditingController _idCtrl = TextEditingController(text: '101');

  Timer? _sessionTimer;
  int _elapsedSeconds = 0;
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final activeSession = widget.client.status['active_session'];
      if (activeSession != null && activeSession['local_id'] != null) {
        setState(() => _elapsedSeconds++);
      } else {
        if (_elapsedSeconds != 0) setState(() => _elapsedSeconds = 0);
      }
    });
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _idCtrl.dispose();
    super.dispose();
  }

  String _formatElapsedTime(int totalSecs) {
    final h = (totalSecs ~/ 3600).toString().padLeft(2, '0');
    final m = ((totalSecs % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (totalSecs % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void _showManualMarkDialog() {
    final enrolled = widget.client.enrolledStudents;
    Map<String, dynamic>? selectedStudent = enrolled.isNotEmpty ? enrolled.first : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('Manual Attendance Override', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select an enrolled student to manually mark present in this session:',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (enrolled.isEmpty)
                  const Text('No enrolled students found. Please register students first.',
                      style: TextStyle(color: AppTheme.warning, fontSize: 13))
                else
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedStudent,
                    dropdownColor: AppTheme.surfaceElevated,
                    decoration: const InputDecoration(labelText: 'Student'),
                    items: enrolled.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text('${s['full_name']} (${s['roll_no']})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedStudent = val);
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedStudent == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      final success = await widget.client.manualMarkAttendance(
                        studentId: selectedStudent!['student_id'],
                        rollNo: selectedStudent!['roll_no'],
                        name: selectedStudent!['full_name'],
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success
                                ? 'Marked ${selectedStudent!['full_name']} present!'
                                : 'Failed to record manual attendance. Make sure a session is active.'),
                          ),
                        );
                      }
                    },
              child: const Text('Confirm Attendance'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeSession = widget.client.status['active_session'];
    final bool hasActiveSession = activeSession != null && activeSession['local_id'] != null;
    final bool isCameraRunning = widget.client.status['camera']?['running'] ?? false;
    final double fps = (widget.client.status['camera']?['fps'] ?? 0.0).toDouble();

    return Column(
      children: [
        // 1. Session Control Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Course Code:',
                    style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _codeCtrl,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    decoration: const InputDecoration(hintText: 'Code', isDense: true),
                  ),
                ),
                const SizedBox(width: 14),
                const Text('Name:',
                    style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    decoration: const InputDecoration(hintText: 'Course Name', isDense: true),
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _idCtrl,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    decoration: const InputDecoration(hintText: 'ID', isDense: true),
                  ),
                ),
                const SizedBox(width: 14),
                ElevatedButton.icon(
                  onPressed: () {
                    if (hasActiveSession) {
                      widget.client.endSession();
                    } else {
                      final int courseId = int.tryParse(_idCtrl.text.trim()) ?? 101;
                      widget.client.startSession(
                        courseId: courseId,
                        code: _codeCtrl.text.trim(),
                        name: _nameCtrl.text.trim(),
                      );
                    }
                  },
                  icon: Icon(hasActiveSession ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 16),
                  label: Text(hasActiveSession ? 'End Session' : 'Start Session'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasActiveSession ? AppTheme.error : AppTheme.success,
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSunken,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    'SESSION DURATION: ${_formatElapsedTime(_elapsedSeconds)}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Main Body Split: Video Viewport (Left) vs Live Roster (Right)
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // LEFT: Live Video Feed & Controls
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      // Video Stream Viewport
                      Expanded(
                        child: CameraStreamView(
                          streamUrl: '${widget.client.baseUrl}/api/camera/stream',
                          isRunning: isCameraRunning,
                          currentFps: fps,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Status Bar & Controls
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => widget.client.toggleCamera(cameraIndex: _selectedCameraIndex),
                              icon: Icon(isCameraRunning ? Icons.videocam_off : Icons.videocam, size: 16),
                              label: Text(isCameraRunning ? 'Stop Camera' : 'Start Camera Stream'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isCameraRunning ? AppTheme.error : AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: hasActiveSession ? _showManualMarkDialog : null,
                              icon: const Icon(Icons.how_to_reg_rounded, size: 16, color: AppTheme.primary),
                              label: const Text('Manual Override', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 14),
                            const Text('Device:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            const SizedBox(width: 8),
                            DropdownButton<int>(
                              value: _selectedCameraIndex,
                              dropdownColor: AppTheme.surfaceElevated,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: 0, child: Text('Device 0 (Integrated / USB)')),
                                DropdownMenuItem(value: 1, child: Text('Device 1 (External / Secondary)')),
                              ],
                              onChanged: isCameraRunning
                                  ? null
                                  : (val) {
                                      if (val != null) setState(() => _selectedCameraIndex = val);
                                    },
                            ),
                          ],
                        ),
                      ),

                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // RIGHT: Live Recognized Attendance Roster
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_user_rounded, size: 18, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'Session Roster',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${widget.client.liveRoster.length} Present',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Expanded(
                        child: widget.client.liveRoster.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.people_alt_outlined, size: 36, color: AppTheme.textMuted),
                                    const SizedBox(height: 8),
                                    Text(
                                      isCameraRunning
                                          ? 'Scanning classroom feed...\nFaces will be verified and queued here.'
                                          : 'Start camera stream to begin automated facial recognition.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: widget.client.liveRoster.length,
                                separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 1),
                                itemBuilder: (context, i) {
                                  final r = widget.client.liveRoster[i];
                                  final double conf = (r['confidence'] ?? 0.95).toDouble();
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    leading: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                                      child: const Icon(Icons.person, size: 14, color: AppTheme.primary),
                                    ),
                                    title: Text(
                                      r['full_name'] ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary),
                                    ),
                                    subtitle: Text(
                                      '${r['roll_no']} • ${r['time']}',
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.success.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        '${(conf * 100).toInt()}%',
                                        style: const TextStyle(
                                            color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
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
          ),
        ),
      ],
    );
  }
}
