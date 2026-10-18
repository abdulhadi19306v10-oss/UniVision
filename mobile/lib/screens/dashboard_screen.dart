import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';
import '../models/attendance_model.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _studentName = 'Student';
  String _studentRoll = '';
  int? _studentId;

  List<CourseSummary> _summaries = [];
  List<AttendanceHistoryItem> _history = [];
  bool _loading = true;

  // History filtering
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCourseFilter = 'ALL';

  // WebSocket
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  String? _latestAlertMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadProfileAndData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    super.dispose();
  }

  Future<void> _loadProfileAndData() async {
    setState(() => _loading = true);

    final name = await ApiService.getStudentName();
    final roll = await ApiService.getStudentRoll();
    final sId = await ApiService.getStudentId();

    final sums = await ApiService.getCourseSummaries();
    final hist = await ApiService.getAttendanceHistory();

    if (!mounted) return;

    setState(() {
      _studentName = name;
      _studentRoll = roll;
      _studentId = sId;
      _summaries = sums;
      _history = hist;
      _loading = false;
    });

    _initWebSocket(sId ?? 1);
  }

  void _initWebSocket(int studentId) {
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();

    _wsChannel = ApiService.connectNotificationSocket(studentId);
    if (_wsChannel != null) {
      _wsSubscription = _wsChannel!.stream.listen((message) {
        try {
          final data = jsonDecode(message);
          if (data['event'] == 'AttendanceMarked' || data['type'] == 'attendance_confirmed') {
            final course = data['course_code'] ?? 'Course';
            final method = (data['method'] ?? 'face').toString().toUpperCase();
            setState(() {
              _latestAlertMessage = '🎉 Just Marked Present in $course via $method!';
            });
            // Refresh data
            _refreshDataQuietly();
          }
        } catch (_) {}
      }, onError: (_) {});
    }
  }

  Future<void> _refreshDataQuietly() async {
    final sums = await ApiService.getCourseSummaries();
    final hist = await ApiService.getAttendanceHistory();
    if (mounted) {
      setState(() {
        _summaries = sums;
        _history = hist;
      });
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of the UniVision student portal?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.logout();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overallAttended = _summaries.fold<int>(0, (sum, c) => sum + c.attendedSessions);
    final overallTotal = _summaries.fold<int>(0, (sum, c) => sum + c.totalSessions);
    final overallPct = overallTotal > 0 ? (overallAttended / overallTotal * 100.0) : 100.0;
    final warningCount = _summaries.where((c) => c.isBelowThreshold).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'UniVision Student Portal',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
            Text(
              '$_studentName • ${_studentRoll.isNotEmpty ? _studentRoll : 'Active Student'}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Color(0xFFBFDBFE)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Data',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadProfileAndData,
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF2563EB),
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.pie_chart_outline_rounded, size: 20), text: 'Course Summaries'),
                Tab(icon: Icon(Icons.history_rounded, size: 20), text: 'Attendance Logs'),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : Column(
              children: [
                // Top KPI Summary Cards
                _buildTopMetricSummary(overallAttended, overallTotal, overallPct, warningCount),

                // Real-Time Alert Banner
                if (_latestAlertMessage != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active_rounded, color: Color(0xFF16A34A), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _latestAlertMessage!,
                            style: const TextStyle(color: Color(0xFF14532D), fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.close, size: 16, color: Color(0xFF14532D)),
                          onPressed: () => setState(() => _latestAlertMessage = null),
                        ),
                      ],
                    ),
                  ),

                // Main Content Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSummaryTab(),
                      _buildHistoryTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTopMetricSummary(int attended, int total, double pct, int warningCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Total Classes
          Expanded(
            child: _buildMetricTile(
              'ATTENDED',
              '$attended / $total',
              Icons.school_outlined,
              const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 8),
          // Overall %
          Expanded(
            child: _buildMetricTile(
              'OVERALL',
              '${pct.toStringAsFixed(1)}%',
              Icons.trending_up_rounded,
              pct >= 75.0 ? const Color(0xFF16A34A) : Colors.red,
            ),
          ),
          const SizedBox(width: 8),
          // Warning Status
          Expanded(
            child: _buildMetricTile(
              '75% STATUS',
              warningCount == 0 ? 'Eligible' : '$warningCount At Risk',
              warningCount == 0 ? Icons.verified_rounded : Icons.warning_amber_rounded,
              warningCount == 0 ? const Color(0xFF16A34A) : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    if (_summaries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No course enrollments found.', style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProfileAndData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _summaries.length,
        itemBuilder: (context, index) {
          final item = _summaries[index];
          final isWarning = item.isBelowThreshold;
          final pct = item.attendancePercentage;
          final color = isWarning ? Colors.red : const Color(0xFF16A34A);

          return Card(
            elevation: 1.5,
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: isWarning ? Colors.red.shade300 : const Color(0xFFE2E8F0)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                // Filter history by this course and switch tab
                setState(() {
                  _selectedCourseFilter = item.courseCode;
                  _searchCtrl.text = item.courseCode;
                  _tabController.animateTo(1);
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.courseCode,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${pct.toStringAsFixed(1)}%',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.courseName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 12),

                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (pct / 100.0).clamp(0.0, 1.0),
                        backgroundColor: const Color(0xFFE2E8F0),
                        color: color,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Attended: ${item.attendedSessions} / ${item.totalSessions} lectures',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isWarning)
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 14),
                              SizedBox(width: 4),
                              Text('Below 75% Rule', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          )
                        else
                          const Text('Eligibility: OK', style: TextStyle(color: Color(0xFF16A34A), fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryTab() {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _history.where((rec) {
      if (_selectedCourseFilter != 'ALL' && !rec.courseCode.toUpperCase().contains(_selectedCourseFilter)) {
        return false;
      }
      if (query.isEmpty) return true;
      return rec.courseCode.toLowerCase().contains(query) ||
          rec.courseName.toLowerCase().contains(query) ||
          rec.method.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        // Search & Filter Box
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              SizedBox(
                height: 42,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search course code, date, or method...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              _selectedCourseFilter = 'ALL';
                              setState(() {});
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // List View
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadProfileAndData,
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('No matching attendance logs found.', style: TextStyle(color: Color(0xFF64748B))),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final rec = filtered[index];
                      final isFace = rec.method.toLowerCase() == 'face';
                      final formattedDate = DateFormat('EEE, MMM d, yyyy • hh:mm a').format(rec.markedAt.toLocal());
                      final confStr = rec.confidence != null ? ' (${(rec.confidence! * 100).toInt()}% Match)' : '';

                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Row(
                            children: [
                              // Avatar Icon
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: isFace ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE),
                                child: Icon(
                                  isFace ? Icons.face_rounded : Icons.edit_note_rounded,
                                  color: isFace ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          rec.courseCode,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2563EB)),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            rec.courseName,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      formattedDate,
                                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Method: ${rec.method.toUpperCase()}$confStr',
                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),

                              // Present Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                ),
                                child: const Text(
                                  'PRESENT',
                                  style: TextStyle(color: Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
