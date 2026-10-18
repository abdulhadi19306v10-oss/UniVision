import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_flutter/main.dart';
import 'package:desktop_flutter/services/bridge_client.dart';

void main() {
  testWidgets('Role-Based Authentication, Navigation & View Isolation Test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final testClient = BridgeClient(enableBackgroundPolling: false);
    addTearDown(() => testClient.dispose());

    await tester.pumpWidget(UniVisionDesktopApp(client: testClient));
    await tester.pump();

    // 1. Initial State: Login Screen is displayed
    expect(find.text('UNIVISION'), findsOneWidget);
    expect(find.text('Biometric Station & Attendance Portal'), findsOneWidget);
    expect(find.text('Demo Admin'), findsOneWidget);
    expect(find.text('Demo Teacher'), findsOneWidget);
    expect(find.text('Demo Student'), findsOneWidget);

    // 2. Login as Admin
    await tester.tap(find.text('Demo Admin'));
    await tester.pumpAndSettle();

    expect(testClient.currentUser?['role'], 'admin');
    expect(find.text('ADMINISTRATOR'), findsOneWidget);
    expect(find.text('Attendance Logs'), findsOneWidget);
    expect(find.text('Biometrics Enroll'), findsOneWidget);
    expect(find.text('Live Monitoring'), findsOneWidget);
    expect(find.text('Cloud & Diagnostics'), findsOneWidget);

    // 3. Logout
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm Logout'), findsOneWidget);
    // Tap confirm in dialog
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log Out'));
    await tester.pumpAndSettle();

    // Verify back at Login Screen
    expect(find.text('Demo Admin'), findsOneWidget);
    expect(testClient.currentUser, isNull);

    // 4. Login as Teacher
    await tester.tap(find.text('Demo Teacher'));
    await tester.pumpAndSettle();

    expect(testClient.currentUser?['role'], 'teacher');
    expect(find.text('FACULTY TEACHER'), findsOneWidget);
    expect(find.text('Live Class Session'), findsOneWidget);
    expect(find.text('Student Attendance'), findsOneWidget);
    // Teacher must NOT have access to Biometrics Enroll
    expect(find.text('Biometrics Enroll'), findsNothing);

    // 5. Logout
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log Out'));
    await tester.pumpAndSettle();

    // 6. Login as Student
    await tester.tap(find.text('Demo Student'));
    await tester.pumpAndSettle();

    expect(testClient.currentUser?['role'], 'student');
    expect(find.textContaining('STUDENT • 2025(s)-SE-5'), findsOneWidget);
    expect(find.text('My Attendance'), findsOneWidget);
    // Student must NOT have live session controls, biometrics enroll, or cloud diagnostics
    expect(find.text('Live Class Session'), findsNothing);
    expect(find.text('Live Monitoring'), findsNothing);
    expect(find.text('Biometrics Enroll'), findsNothing);
    expect(find.text('Cloud & Diagnostics'), findsNothing);

    // Verify Student Attendance Screen elements
    expect(find.text('CLASSES ATTENDED'), findsOneWidget);
    expect(find.text('LATEST ATTENDANCE'), findsOneWidget);
    expect(find.text('VERIFICATION'), findsOneWidget);
    expect(find.text('ACADEMIC STATUS'), findsOneWidget);
    expect(find.text('My Verified Attendance Records'), findsOneWidget);
    expect(find.text('Export My Report (CSV)'), findsOneWidget);

    // Cleanly tear down
    await tester.pumpWidget(const SizedBox());
  });
}
