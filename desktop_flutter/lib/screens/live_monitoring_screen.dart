import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/bridge_client.dart';

// ponytail: live monitoring screen combining session control, camera HUD, and live roster
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
  String _selectedCamera = 'Camera 0 (Default)';

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

  @override
  Widget build(BuildContext context) {
    final activeSession = widget.client.status['active_session'];
    final bool hasActiveSession = activeSession != null && activeSession['local_id'] != null;
    final bool isCameraRunning = widget.client.status['camera']?['running'] ?? false;

    return Column(
      children: [
        // 1. Quick Session Bar
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
                const Text('Course Code:', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
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
                const Text('Name:', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
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
                    widget.client.startSession(courseId: courseId, code: _codeCtrl.text.trim(), name: _nameCtrl.text.trim());
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
                  'TIME: ${_formatElapsedTime(_elapsedSeconds)}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
        const SizedBox(height: 16),

        // 2. Main Body Split: Video HUD (Left) vs Recognized Roster (Right)
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // LEFT: Video HUD Stream Viewport
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
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceSunken,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (isCameraRunning)
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: AppTheme.success.withValues(alpha: 0.5), width: 2),
                                        ),
                                        child: const Icon(Icons.face_rounded, size: 64, color: AppTheme.success),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'AI Biometric Tracking Active',
                                        style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'YuNet Face Detection & SFace ArcFace Cosine Matcher',
                                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.videocam_off_rounded, size: 48, color: AppTheme.textMuted),
                                      SizedBox(height: 12),
                                      Text(
                                        'Camera is inactive.\nClick \'Start Camera Stream\' below to begin AI recognition.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
                                      ),
                                    ],
                                  ),
                                ),

                              // Live stream corner overlay
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isCameraRunning ? AppTheme.success : AppTheme.error,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isCameraRunning ? 'LIVE STREAM' : 'OFFLINE',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Status message
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isCameraRunning
                              ? 'Biometrics Engine Active • Tracking faces in classroom...'
                              : 'Biometrics Engine Ready • Waiting for camera stream...',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Camera Control Bar
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => widget.client.toggleCamera(),
                              icon: Icon(isCameraRunning ? Icons.videocam_off : Icons.videocam, size: 16),
                              label: Text(isCameraRunning ? 'Stop Camera Stream' : 'Start Camera Stream'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isCameraRunning ? AppTheme.error : AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                widget.client.simulateAttendanceMatch('2024-CS-001', 'Alice Johnson', 0.94);
                              },
                              icon: const Icon(Icons.bolt_rounded, size: 16, color: AppTheme.warning),
                              label: const Text('Simulate Face Recognition', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 14),
                            const Text('Device:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            const SizedBox(width: 8),
                            DropdownButton<String>(
                              value: _selectedCamera,
                              dropdownColor: AppTheme.surfaceElevated,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                              underline: const SizedBox(),
                              items: ['Camera 0 (Default)', 'Camera 1 (External)'].map((e) {
                                return DropdownMenuItem(value: e, child: Text(e));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCamera = val);
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

              // RIGHT: Live Attendance Roster
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
                          const Icon(Icons.how_to_reg_rounded, size: 18, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'Recognized Roster',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() => widget.client.liveRoster.clear());
                            },
                            child: const Text('Clear', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: widget.client.liveRoster.isEmpty
                            ? const Center(
                                child: Text(
                                  'No students recognized yet.\nStart camera stream to begin matching.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                ),
                              )
                            : ListView.separated(
                                itemCount: widget.client.liveRoster.length,
                                separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 1),
                                itemBuilder: (context, i) {
                                  final r = widget.client.liveRoster[i];
                                  final double conf = (r['confidence'] ?? 0.9).toDouble();
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
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary),
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
                                        style: const TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.bold),
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
