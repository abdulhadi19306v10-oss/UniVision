import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/bridge_client.dart';

// ponytail: biometrics registration screen with live directory and 5-sample progress feedback
class EnrollmentScreen extends StatefulWidget {
  final BridgeClient client;

  const EnrollmentScreen({super.key, required this.client});

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  final TextEditingController _idCtrl = TextEditingController(text: '103');
  final TextEditingController _rollCtrl = TextEditingController(text: '2024-CS-003');
  final TextEditingController _nameCtrl = TextEditingController(text: 'Charlie Davis');
  final TextEditingController _searchCtrl = TextEditingController();

  int _samplesCaptured = 0;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    widget.client.loadEnrolledStudents();
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _rollCtrl.dispose();
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _prefillSampleStudent() {
    setState(() {
      _idCtrl.text = '104';
      _rollCtrl.text = '2024-CS-004';
      _nameCtrl.text = 'Diana Prince';
    });
  }

  void _clearForm() {
    setState(() {
      _idCtrl.clear();
      _rollCtrl.clear();
      _nameCtrl.clear();
      _samplesCaptured = 0;
    });
  }

  Future<void> _startEnrollment() async {
    final int? id = int.tryParse(_idCtrl.text.trim());
    final String roll = _rollCtrl.text.trim();
    final String name = _nameCtrl.text.trim();

    if (id == null || roll.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all student biometric fields.')),
      );
      return;
    }

    setState(() {
      _isCapturing = true;
      _samplesCaptured = 0;
    });

    // Simulate 5 biometric sample captures
    for (int i = 1; i <= 5; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _samplesCaptured = i);
    }

    await widget.client.enrollStudent(id: id, rollNo: roll, name: name);

    if (!mounted) return;
    setState(() => _isCapturing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully registered biometric embeddings for $name!')),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // LEFT: Biometric Enrollment Registration Form
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
                  'Registers 5 facial embedding vectors into offline SQLite storage.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 18),

                const Text('Student System ID:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _idCtrl,
                  decoration: const InputDecoration(hintText: 'e.g. 101'),
                ),
                const SizedBox(height: 14),

                const Text('University Roll Number:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _rollCtrl,
                  decoration: const InputDecoration(hintText: 'e.g. 2024-CS-001'),
                ),
                const SizedBox(height: 14),

                const Text('Student Full Name:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(hintText: 'e.g. Alice Johnson'),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _prefillSampleStudent,
                        child: const Text('Prefill Test Student', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _clearForm,
                      child: const Text('Clear', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isCapturing ? null : _startEnrollment,
                    icon: Icon(_isCapturing ? Icons.hourglass_top_rounded : Icons.camera_alt_rounded, size: 16),
                    label: Text(_isCapturing ? 'Capturing Biometrics ($_samplesCaptured/5)...' : 'Capture 5 Biometric Samples'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                  ),
                ),
                const SizedBox(height: 14),

                // Capture Progress Bar
                LinearProgressIndicator(
                  value: _samplesCaptured / 5.0,
                  backgroundColor: AppTheme.surfaceSunken,
                  color: AppTheme.success,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Text(
                  _isCapturing
                      ? 'Collecting neural embeddings: $_samplesCaptured of 5 angles recorded'
                      : 'Biometric capture engine idle and ready.',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                ),
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
                        width: 180,
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

                // Directory Data Table
                Expanded(
                  child: enrolledList.isEmpty
                      ? const Center(
                          child: Text('No enrolled students match your search.', style: TextStyle(color: AppTheme.textMuted)),
                        )
                      : SingleChildScrollView(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowHeight: 40,
                              dataRowMinHeight: 44,
                              dataRowMaxHeight: 52,
                              columns: const [
                                DataColumn(label: Text('ID', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Roll Number', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Student Name', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Action', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold))),
                              ],
                              rows: enrolledList.map((s) {
                                final int sid = s['student_id'] ?? 0;
                                return DataRow(
                                  cells: [
                                    DataCell(Text('#$sid', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold))),
                                    DataCell(Text(s['roll_no'] ?? '', style: const TextStyle(color: AppTheme.textPrimary))),
                                    DataCell(Text(s['full_name'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600))),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 18),
                                        onPressed: () {
                                          widget.client.deleteEnrolled(sid);
                                        },
                                        tooltip: 'Delete Biometrics',
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
          ),
        ),
      ],
    );
  }
}
