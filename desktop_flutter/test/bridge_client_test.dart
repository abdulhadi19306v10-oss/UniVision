import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_flutter/services/bridge_client.dart';

void main() {
  group('BridgeClient Unit Tests', () {
    late BridgeClient client;

    setUp(() {
      client = BridgeClient(baseUrl: 'http://127.0.0.1:9999'); // offline mock test port
    });

    tearDown(() {
      client.dispose();
    });

    test('Initializes with default offline state', () {
      expect(client.isConnected, isFalse);
      expect(client.status['active_session']['local_id'], isNull);
      expect(client.status['camera']['running'], isFalse);
      expect(client.logMessages.isNotEmpty, isTrue);
    });

    test('Starts and ends lecture sessions cleanly', () async {
      final started = await client.startSession(courseId: 101, code: 'CS-401', name: 'Software Architecture');
      expect(started, isTrue);
      expect(client.status['active_session']['local_id'], isNotNull);
      expect(client.status['active_session']['course_code'], 'CS-401');
      expect(client.logMessages.first, contains('CS-401'));

      final ended = await client.endSession();
      expect(ended, isTrue);
      expect(client.status['active_session']['local_id'], isNull);
    });

    test('Toggles camera stream state', () async {
      expect(client.status['camera']['running'], isFalse);
      await client.toggleCamera();
      expect(client.status['camera']['running'], isTrue);
      await client.toggleCamera();
      expect(client.status['camera']['running'], isFalse);
    });

    test('Enrolls, lists, and deletes student biometrics', () async {
      await client.loadEnrolledStudents();
      final initialCount = client.enrolledStudents.length;

      final enrolled = await client.enrollStudent(id: 777, rollNo: '2024-TEST-777', name: 'Test Student');
      expect(enrolled, isTrue);
      expect(client.enrolledStudents.length, initialCount + 1);
      expect(client.enrolledStudents.any((s) => s['student_id'] == 777), isTrue);

      final deleted = await client.deleteEnrolled(777);
      expect(deleted, isTrue);
      expect(client.enrolledStudents.any((s) => s['student_id'] == 777), isFalse);
    });

    test('Simulates face recognition and appends to live roster and queue', () {
      client.simulateAttendanceMatch('2024-CS-099', 'Grace Hopper', 0.98);

      expect(client.liveRoster.length, 1);
      expect(client.liveRoster.first['roll_no'], '2024-CS-099');
      expect(client.liveRoster.first['full_name'], 'Grace Hopper');
      expect(client.status['stats']['total_present'], 1);

      expect(client.attendanceRecords.any((r) => r['roll_no'] == '2024-CS-099'), isTrue);
    });

    test('Syncs queued attendance records and updates sync status', () async {
      client.simulateAttendanceMatch('2024-CS-088', 'Donald Knuth', 0.96);
      expect(client.attendanceRecords.first['synced'], 0);

      final stats = await client.syncToCloud(
        url: 'http://localhost:8000',
        email: 'teacher@univision.edu',
        password: 'password',
      );

      expect(stats['synced'], greaterThanOrEqualTo(1));
      expect(client.attendanceRecords.first['synced'], 1);
    });
  });
}
