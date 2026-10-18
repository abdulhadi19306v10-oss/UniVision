import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focus_attendance_mobile/main.dart';
import 'package:focus_attendance_mobile/screens/dashboard_screen.dart';
import 'package:focus_attendance_mobile/services/api_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Student Mobile App: Authentication, Summaries, History & Navigation Test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const AttendanceApp());
    await tester.pumpAndSettle();

    // 1. Verify Login Screen renders
    expect(find.text('UNIVISION'), findsOneWidget);
    expect(find.text('Student Attendance Self-Service'), findsOneWidget);
    expect(find.text('Roll Number'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Alice (CS-001)'), findsOneWidget);
    expect(find.text('Hamza (SE-5)'), findsOneWidget);

    // 2. Perform 1-Click Demo Login
    await tester.tap(find.text('Alice (CS-001)'));
    await tester.pumpAndSettle();

    // 3. Verify Dashboard Screen is displayed
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text('UniVision Student Portal'), findsOneWidget);
    expect(find.textContaining('Alice Johnson'), findsOneWidget);

    // 4. Verify KPI Metric Tiles
    expect(find.text('ATTENDED'), findsOneWidget);
    expect(find.text('OVERALL'), findsOneWidget);
    expect(find.text('75% STATUS'), findsOneWidget);

    // 5. Verify Course Summaries
    expect(find.text('Course Summaries'), findsOneWidget);
    expect(find.text('CS-401'), findsOneWidget);
    expect(find.text('CS-302'), findsOneWidget);
    expect(find.text('CS-305'), findsOneWidget);
    expect(find.text('Below 75% Rule'), findsOneWidget);

    // 6. Switch to Attendance Logs Tab
    await tester.tap(find.text('Attendance Logs'));
    await tester.pumpAndSettle();

    // Verify history logs
    expect(find.textContaining('PRESENT'), findsWidgets);
    expect(find.byType(TextField), findsOneWidget); // Search filter

    // 7. Test Search Filter
    await tester.enterText(find.byType(TextField), 'CS-302');
    await tester.pumpAndSettle();
    expect(find.text('Artificial Intelligence & Neural Nets'), findsOneWidget);

    // Clear search
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    // 8. Sign Out
    await tester.tap(find.byIcon(Icons.logout_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Sign Out'), findsWidgets);

    // Confirm dialog sign out
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Out'));
    await tester.pumpAndSettle();

    // Verify returned to Login Screen
    expect(find.text('UNIVISION'), findsOneWidget);
    expect(find.text('Student Attendance Self-Service'), findsOneWidget);

    // Clean unmount
    await tester.pumpWidget(const SizedBox());
  });
}
