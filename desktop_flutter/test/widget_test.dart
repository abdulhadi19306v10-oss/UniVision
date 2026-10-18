import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_flutter/main.dart';
import 'package:desktop_flutter/services/bridge_client.dart';

void main() {
  testWidgets('UniVision Desktop Station UI renders and navigates seamlessly', (WidgetTester tester) async {
    // Set a large desktop window size
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final testClient = BridgeClient(
      enableBackgroundPolling: false,
      initialUser: const {
        'id': 1,
        'username': 'admin',
        'role': 'admin',
        'full_name': 'System Administrator',
      },
    );
    addTearDown(() {
      testClient.dispose();
    });

    await tester.pumpWidget(UniVisionDesktopApp(client: testClient));
    await tester.pump();

    // 1. Check Sidebar & Branding
    expect(find.text('UNIVISION'), findsOneWidget);
    expect(find.text('Biometric Station'), findsOneWidget);
    expect(find.text('Live Monitoring'), findsOneWidget);
    expect(find.text('Biometrics Enroll'), findsOneWidget);
    expect(find.text('Attendance Logs'), findsOneWidget);
    expect(find.text('Cloud & Diagnostics'), findsOneWidget);
    expect(find.text('SQLite Offline-First'), findsOneWidget);

    // 2. Check Top Bar KPI Badges
    expect(find.textContaining('PRESENT:'), findsOneWidget);
    expect(find.textContaining('FPS:'), findsOneWidget);
    expect(find.textContaining('SYNC QUEUE:'), findsOneWidget);

    // 3. Test Session Start & End on Live Monitoring page
    expect(find.text('Start Session'), findsOneWidget);
    await tester.tap(find.text('Start Session'));
    await tester.pump();
    expect(find.text('End Session'), findsOneWidget);

    // 4. Test Camera Stream Controls & Manual Override Button
    expect(find.text('Start Camera Stream'), findsOneWidget);
    expect(find.text('Manual Override'), findsOneWidget);

    // 5. Navigate to Biometrics Enroll
    await tester.tap(find.text('Biometrics Enroll'));
    await tester.pump();
    expect(find.text('Biometric Registration'), findsOneWidget);
    expect(find.text('Enrolled Students Directory'), findsOneWidget);
    expect(find.text('Capture Biometrics via Camera'), findsOneWidget);
    expect(find.text('Manual Register'), findsOneWidget);

    // 6. Navigate to Attendance Logs
    await tester.tap(find.text('Attendance Logs'));
    await tester.pump();
    expect(find.text('Attendance Queue & Verification Logs'), findsOneWidget);
    expect(find.text('Export to CSV'), findsOneWidget);

    // 7. Navigate to Cloud & Diagnostics
    await tester.tap(find.text('Cloud & Diagnostics'));
    await tester.pump();
    expect(find.text('Cloud Database Synchronization'), findsOneWidget);
    expect(find.text('Live Telemetry & Diagnostics Log'), findsOneWidget);
    expect(find.text('Push Queued Attendance to Cloud'), findsOneWidget);
    expect(find.text('Test Connection'), findsOneWidget);

    // Trigger cloud sync
    await tester.tap(find.text('Push Queued Attendance to Cloud'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Uploaded'), findsOneWidget);

    // Cleanly unmount widget tree before tearDown
    await tester.pumpWidget(const SizedBox());
  });
}
