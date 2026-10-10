import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/attendance_model.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentTabIndex = 0;
  List<CourseSummary> _summaries = [];
  List<AttendanceHistoryItem> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    setState(() => _loading = true);
    final sums = await ApiService.getCourseSummaries();
    final hist = await ApiService.getAttendanceHistory();
    setState(() {
      _summaries = sums;
      _history = hist;
      _loading = false;
    });
  }

  void _logout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _currentTabIndex == 0
              ? _buildSummaryTab()
              : _buildHistoryTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        selectedItemColor: const Color(0xFF2563EB),
        onTap: (index) => setState(() => _currentTabIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Summary'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    if (_summaries.isEmpty) {
      return const Center(child: Text('No course enrollments found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _summaries.length,
      itemBuilder: (context, index) {
        final item = _summaries[index];
        final isWarning = item.isBelowThreshold;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isWarning ? Colors.red.shade300 : Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.courseCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2563EB))),
                    Chip(
                      label: Text('${item.attendancePercentage.toStringAsFixed(1)}%'),
                      backgroundColor: isWarning ? Colors.red.shade100 : Colors.green.shade100,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isWarning ? Colors.red.shade800 : Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
                Text(item.courseName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: item.attendancePercentage / 100.0,
                  backgroundColor: Colors.grey.shade200,
                  color: isWarning ? Colors.red : Colors.green,
                  minHeight: 8,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Attended: ${item.attendedSessions} / ${item.totalSessions} sessions', style: const TextStyle(color: Colors.grey)),
                    if (isWarning)
                      const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red, size: 16),
                          SizedBox(width: 4),
                          Text('Below 75% Threshold', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return const Center(child: Text('No attendance records logged yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final rec = _history[index];
        final formattedDate = DateFormat('EEE, MMM d, yyyy • hh:mm a').format(rec.markedAt.toLocal());

        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFDCFCE7),
            child: Icon(Icons.check, color: Color(0xFF16A34A)),
          ),
          title: Text(rec.courseCode, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('$formattedDate\nMethod: ${rec.method.toUpperCase()}'),
          trailing: const Chip(label: Text('PRESENT', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)), backgroundColor: Color(0xFFF0FDF4)),
          isThreeLine: true,
        );
      },
    );
  }
}
