import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_flutter/main.dart';
import 'package:desktop_flutter/services/bridge_client.dart';

void main() {
  testWidgets('Enrollment page register buttons and prefill work seamlessly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final testClient = BridgeClient(enableBackgroundPolling: false);
    addTearDown(() => testClient.dispose());

    await tester.pumpWidget(UniVisionDesktopApp(client: testClient));
    await tester.pump();

    // 1. Navigate to Biometrics Enroll
    await tester.tap(find.text('Biometrics Enroll'));
    await tester.pumpAndSettle();

    // Check elements
    expect(find.text('Biometric Registration'), findsOneWidget);
    expect(find.text('Capture Biometrics via Camera'), findsOneWidget);
    expect(find.text('Manual Register'), findsOneWidget);
    expect(find.text('Prefill'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);

    // 2. Test Prefill button
    await tester.tap(find.text('Prefill'));
    await tester.pump();
    expect(find.textContaining('Student #'), findsOneWidget);

    // 3. Test Manual Register button
    await tester.tap(find.text('Manual Register'));
    await tester.pumpAndSettle();

    expect(testClient.enrolledStudents.length, 1);
    expect(find.textContaining('Successfully registered student'), findsOneWidget);

    // 4. Test Auto-ID registration with blank ID field
    final textFields = find.byType(TextField);
    // Leave Field 0 (Student ID) blank
    await tester.enterText(textFields.at(0), '');
    await tester.enterText(textFields.at(1), '2024-AUTO-002');
    await tester.enterText(textFields.at(2), 'Auto ID Student');
    await tester.pump();

    await tester.tap(find.text('Manual Register'));
    await tester.pumpAndSettle();

    expect(testClient.enrolledStudents.length, 2);
    expect(testClient.enrolledStudents.any((s) => s['roll_no'] == '2024-AUTO-002'), isTrue);

    // 5. Test Capture Biometrics via Camera button
    await tester.enterText(textFields.at(0), '103');
    await tester.enterText(textFields.at(1), '2024-BIO-003');
    await tester.enterText(textFields.at(2), 'Biometric Cam Student');
    await tester.pump();

    await tester.tap(find.text('Capture Biometrics via Camera'));
    await tester.pump();
    // Verify capture progress appears
    expect(find.textContaining('Capturing Angle'), findsOneWidget);

    // Let 5-angle capture finish
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(testClient.enrolledStudents.length, 3);
    expect(testClient.enrolledStudents.any((s) => s['roll_no'] == '2024-BIO-003'), isTrue);

    // 6. Test Edit Student Details feature
    final editButtons = find.byIcon(Icons.edit_outlined);
    expect(editButtons, findsWidgets);

    // Tap first edit button
    await tester.tap(editButtons.first);
    await tester.pumpAndSettle();

    // Verify Edit Dialog appears
    expect(find.textContaining('Edit Student #'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);

    // Enter updated details in dialog textfields
    final dialogTextFields = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(dialogTextFields.at(0), '2024-EDITED-001');
    await tester.enterText(dialogTextFields.at(1), 'Edited Student Name');
    await tester.pump();

    // Save changes
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Edited Student Name'), findsOneWidget);
    expect(find.textContaining('2024-EDITED-001'), findsOneWidget);
    expect(testClient.enrolledStudents.any((s) => s['roll_no'] == '2024-EDITED-001'), isTrue);
    expect(testClient.enrolledStudents.any((s) => s['full_name'] == 'Edited Student Name'), isTrue);
  });
}
