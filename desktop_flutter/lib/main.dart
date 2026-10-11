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
  final BridgeClient? client;
  const UniVisionDesktopApp({super.key, this.client});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniVision — Biometric Classroom Station',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: MainWorkstationView(client: client),
    );
  }
}

class MainWorkstationView extends StatefulWidget {
  final BridgeClient? client;
  const MainWorkstationView({super.key, this.client});

  @override
  State<MainWorkstationView> createState() => _MainWorkstationViewState();
}

class _MainWorkstationViewState extends State<MainWorkstationView> {
  late final BridgeClient _client;
  bool _ownsClient = false;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    if (widget.client != null) {
      _client = widget.client!;
      _ownsClient = false;
    } else {
      _client = BridgeClient();
      _ownsClient = true;
    }
  }

  @override
  void dispose() {
    if (_ownsClient) {
      _client.dispose();
    }
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
