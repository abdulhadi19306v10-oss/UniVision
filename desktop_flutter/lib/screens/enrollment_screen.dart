import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/bridge_client.dart';
import '../widgets/camera_stream_view.dart';

// ponytail: biometric registration screen with real multi-angle camera capture and offline student directory
class EnrollmentScreen extends StatefulWidget {
  final BridgeClient client;

  const EnrollmentScreen({super.key, required this.client});

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  final TextEditingController _idCtrl = TextEditingController();
  final TextEditingController _rollCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _isEnrolling = false;

  @override
  void initState() {
    super.initState();
    widget.client.loadEnrolledStudents();
    widget.client.addListener(_onClientUpdated);
  }

  @override
  void dispose() {
    widget.client.removeListener(_onClientUpdated);
    _idCtrl.dispose();
    _rollCtrl.dispose();
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onClientUpdated() {
    if (!mounted) return;
    setState(() {});
  }

  void _clearForm() {
    setState(() {
      _idCtrl.clear();
      _rollCtrl.clear();
      _nameCtrl.clear();
      _isEnrolling = false;
    });
  }

  void _prefillTestStudent() {
    final nextId = widget.client.nextStudentId;
    setState(() {
      _idCtrl.text = nextId.toString();
      _rollCtrl.text = '2024-CS-${nextId.toString().padLeft(3, '0')}';
      _nameCtrl.text = 'Student #$nextId';
    });
  }

  Future<void> _startBiometricEnrollment() async {
    final String roll = _rollCtrl.text.trim();
    final String name = _nameCtrl.text.trim();

    if (roll.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all student biometric fields (Roll No, Name).')),
      );
      return;
    }

    final int id = int.tryParse(_idCtrl.text.trim()) ?? widget.client.nextStudentId;
    if (_idCtrl.text.trim().isEmpty) {
      _idCtrl.text = id.toString();
    }

    setState(() => _isEnrolling = true);

    final success = await widget.client.startBiometricEnrollment(
      id: id,
      rollNo: roll,
      name: name,
    );

    if (mounted) {
      setState(() => _isEnrolling = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not complete biometric enrollment. Please ensure your face is clearly visible to the camera and try again.')),
        );
      } else {
        _clearForm();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Text('Successfully registered biometric profile for $name ($roll)!'),
          ),
        );
      }
    }
  }

  Future<void> _cancelEnrollment() async {
    await widget.client.cancelBiometricEnrollment();
    if (mounted) {
      setState(() => _isEnrolling = false);
    }
  }

  Future<void> _manualDirectRegister() async {
    final String roll = _rollCtrl.text.trim();
    final String name = _nameCtrl.text.trim();

    if (roll.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter University Roll Number and Student Name.')),
      );
      return;
    }

    final int id = int.tryParse(_idCtrl.text.trim()) ?? widget.client.nextStudentId;

    final success = await widget.client.enrollStudent(id: id, rollNo: roll, name: name);
    if (mounted) {
      if (success) {
        _clearForm();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Text('Successfully registered student $name ($roll)!'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to register student.')),
        );
      }
    }
  }

  void _confirmDeleteStudent(int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Delete Biometric Profile', style: TextStyle(fontSize: 16)),
        content: Text('Are you sure you want to remove $name (#$id) from local biometrics storage?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.client.deleteEnrolled(id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Removed student $name from local database.')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditStudentDialog(int id, String currentRoll, String currentName) {
    final TextEditingController editRollCtrl = TextEditingController(text: currentRoll);
    final TextEditingController editNameCtrl = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 22),
            const SizedBox(width: 8),
            Text('Edit Student #$id', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('University Roll Number:',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: editRollCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. 2024-CS-001',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),
              const Text('Full Name:',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: editNameCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. Alice Johnson',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newRoll = editRollCtrl.text.trim();
              final newName = editNameCtrl.text.trim();
              if (newRoll.isEmpty || newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide both roll number and student name.')),
                );
                return;
              }
              Navigator.pop(ctx);
              final success = await widget.client.updateEnrolledStudent(
                studentId: id,
                rollNo: newRoll,
                name: newName,
              );
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        backgroundColor: AppTheme.success,
                        content: Text('Updated student details for $newName ($newRoll)!'),
                      ),
                    );
                } else {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(content: Text('Failed to update student details.')),
                    );
                }
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String searchQuery = _searchCtrl.text.trim().toLowerCase();
    final enrolledList = widget.client.enrolledStudents.where((s) {
      if (searchQuery.isEmpty) return true;
      final name = (s['full_name'] ?? '').toString().toLowerCase();
      final roll = (s['roll_no'] ?? '').toString().toLowerCase();
      return name.contains(searchQuery) || roll.contains(searchQuery);
    }).toList();

    final activeProg = widget.client.activeEnrollmentProgress;
    final int currentSample = activeProg != null ? (activeProg['current'] ?? 0) : 0;
    final int totalSamples = activeProg != null ? (activeProg['total'] ?? 5) : 5;
    final bool isCapturing = _isEnrolling || activeProg != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // LEFT: Biometric Registration Form
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.person_add_rounded, color: AppTheme.primary, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Biometric Registration',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Extracts and averages 5 facial embeddings using SFace ONNX into offline SQLite storage.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.3),
                  ),
                  const SizedBox(height: 18),

                  const Text('Student ID:',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _idCtrl,
                    decoration: InputDecoration(hintText: 'e.g. ${widget.client.nextStudentId} (Auto if blank)'),
                  ),
                  const SizedBox(height: 14),

                  const Text('University Roll Number:',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _rollCtrl,
                    decoration: const InputDecoration(hintText: 'e.g. 2024-CS-001'),
                  ),
                  const SizedBox(height: 14),

                  const Text('Full Name:',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(hintText: 'e.g. Alice Johnson'),
                  ),
                  const SizedBox(height: 18),

                  if (isCapturing) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSunken,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primary),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Capturing Angle $currentSample of $totalSamples...',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: currentSample / totalSamples,
                            backgroundColor: AppTheme.surfaceElevated,
                            color: AppTheme.success,
                            minHeight: 6,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Please look directly into the camera. Ensure only one face is visible in frame.',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          ),
                          if (widget.client.status['camera']?['running'] == true) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                height: 160,
                                width: double.infinity,
                                child: CameraStreamView(
                                  streamUrl: '${widget.client.baseUrl}/api/camera/stream',
                                  isRunning: true,
                                  currentFps: (widget.client.status['camera']?['fps'] ?? 0.0).toDouble(),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _cancelEnrollment,
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
                        child: const Text('Cancel Biometric Capture'),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _startBiometricEnrollment,
                        icon: const Icon(Icons.camera_alt_rounded, size: 16),
                        label: const Text('Capture Biometrics via Camera'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: OutlinedButton(
                            onPressed: _manualDirectRegister,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            ),
                            child: const Text('Manual Register', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 3,
                          child: OutlinedButton(
                            onPressed: _prefillTestStudent,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            ),
                            child: const Text('Prefill', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: _clearForm,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            ),
                            child: const Text('Clear', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // RIGHT: Enrolled Students Directory
        Expanded(
          flex: 6,
          child: Container(
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
                      const Icon(Icons.badge_rounded, color: AppTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Enrolled Students Directory',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 160,
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'Search enrolled...',
                            prefixIcon: Icon(Icons.search, size: 16, color: AppTheme.textMuted),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary, size: 20),
                        onPressed: () => widget.client.loadEnrolledStudents(),
                        tooltip: 'Refresh directory',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                Expanded(
                  child: enrolledList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.folder_open_rounded, size: 40, color: AppTheme.textMuted),
                              const SizedBox(height: 8),
                              Text(
                                searchQuery.isNotEmpty
                                    ? 'No students matching "$searchQuery"'
                                    : 'No biometric profiles in local database.\nRegister students using the form on the left.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: enrolledList.length,
                          separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 1),
                          itemBuilder: (context, i) {
                            final s = enrolledList[i];
                            final int id = s['student_id'] ?? 0;
                            final String name = s['full_name'] ?? '';
                            final String roll = s['roll_no'] ?? '';
                            final String enrolledAt = (s['enrolled_at'] ?? '').toString();
                            final String formattedDate =
                                enrolledAt.contains('T') ? enrolledAt.split('T')[0] : enrolledAt;

                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              leading: CircleAvatar(
                                radius: 15,
                                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                      color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary),
                              ),
                              subtitle: Text(
                                '$roll • Registered: $formattedDate',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                                    tooltip: 'Edit student details',
                                    onPressed: () => _showEditStudentDialog(id, roll, name),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.error),
                                    tooltip: 'Delete biometric profile',
                                    onPressed: () => _confirmDeleteStudent(id, name),
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
}
