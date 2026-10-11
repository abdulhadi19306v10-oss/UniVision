import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_flutter/main.dart';

void main() {
  testWidgets('UniVision Desktop Station UI renders and navigates seamlessly', (WidgetTester tester) async {
    // Set a large desktop window size
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const UniVisionDesktopApp());
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

    // 3. Test Session Start on Live Monitoring page
    expect(find.text('Start Session'), findsOneWidget);
    await tester.tap(find.text('Start Session'));
    await tester.pump();
    expect(find.text('End Session'), findsOneWidget);

    // 4. Test Face Recognition Simulation
    expect(find.text('Simulate Face Recognition'), findsOneWidget);
    await tester.tap(find.text('Simulate Face Recognition'));
    await tester.pump();
    expect(find.text('Alice Johnson'), findsWidgets);

    // 5. Navigate to Biometrics Enroll
    await tester.tap(find.text('Biometrics Enroll'));
    await tester.pump();
    expect(find.text('Biometric Registration'), findsOneWidget);
    expect(find.text('Enrolled Students Directory'), findsOneWidget);
    expect(find.text('Prefill Test Student'), findsOneWidget);

    // Prefill test student and verify form
    await tester.tap(find.text('Prefill Test Student'));
    await tester.pump();
    expect(find.text('Diana Prince'), findsOneWidget);

    // 6. Navigate to Attendance Logs
    await tester.tap(find.text('Attendance Logs'));
    await tester.pump();
    expect(find.text('Attendance Queue & Verification Logs'), findsOneWidget);
    expect(find.text('Export to CSV'), findsOneWidget);

    // 7. Navigate to Cloud & Diagnostics
    await tester.tap(find.text('Cloud & Diagnostics'));
    await tester.pump();
    expect(find.text('Postgres Cloud Synchronization'), findsOneWidget);
    expect(find.text('System Activity & Error Logs'), findsOneWidget);
    expect(find.text('Push Queued Attendance to Cloud'), findsOneWidget);

    // Trigger cloud sync
    await tester.tap(find.text('Push Queued Attendance to Cloud'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Uploaded'), findsOneWidget);
  });
}
