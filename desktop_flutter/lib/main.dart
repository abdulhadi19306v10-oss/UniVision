import 'package:flutter/material.dart';
import 'theme.dart';
import 'services/bridge_client.dart';
import 'widgets/sidebar.dart';
import 'widgets/top_bar.dart';
import 'screens/live_monitoring_screen.dart';
import 'screens/enrollment_screen.dart';
import 'screens/attendance_logs_screen.dart';
import 'screens/cloud_diagnostics_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UniVisionDesktopApp());
}

class UniVisionDesktopApp extends StatelessWidget {
  const UniVisionDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniVision — Biometric Classroom Station',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainWorkstationView(),
    );
  }
}

class MainWorkstationView extends StatefulWidget {
  const MainWorkstationView({super.key});

  @override
  State<MainWorkstationView> createState() => _MainWorkstationViewState();
}

class _MainWorkstationViewState extends State<MainWorkstationView> {
  final BridgeClient _client = BridgeClient();
  int _selectedTab = 0;

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _client,
      builder: (context, _) {
        return Scaffold(
          body: Row(
            children: [
              // Sidebar Navigation
              Sidebar(
                selectedIndex: _selectedTab,
                onItemSelected: (index) {
                  setState(() => _selectedTab = index);
                },
              ),

              // Main Workstation Content Area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Top KPI Bar
                      TopBar(client: _client),
                      const SizedBox(height: 16),

                      // Stacked Page Views
                      Expanded(
                        child: IndexedStack(
                          index: _selectedTab,
                          children: [
                            LiveMonitoringScreen(client: _client),
                            EnrollmentScreen(client: _client),
                            AttendanceLogsScreen(client: _client),
                            CloudDiagnosticsScreen(client: _client),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
