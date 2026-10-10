import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/attendance_model.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8000'; // Android emulator to localhost
  static const String wsUrl = 'ws://10.0.2.2:8000';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<int?> getStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('student_id');
  }

  static Future<void> saveToken(String token, String studentName, int studentId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setString('student_name', studentName);
    await prefs.setInt('student_id', studentId);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<bool> loginStudent(String rollNo, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/student/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'roll_no': rollNo, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveToken(data['access_token'], data['full_name'], data['user_id']);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<List<CourseSummary>> getCourseSummaries() async {
    final token = await getToken();
    if (token == null) return [];

    final response = await http.get(
      Uri.parse('$baseUrl/me/summary'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((item) => CourseSummary.fromJson(item)).toList();
    }
    return [];
  }

  static Future<List<AttendanceHistoryItem>> getAttendanceHistory() async {
    final token = await getToken();
    if (token == null) return [];

    final response = await http.get(
      Uri.parse('$baseUrl/me/attendance'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((item) => AttendanceHistoryItem.fromJson(item)).toList();
    }
    return [];
  }

  /// Connects to real-time WebSocket event channel to receive instant push alerts
  static WebSocketChannel? connectNotificationSocket(int studentId) {
    try {
      final channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/ws/student/$studentId'),
      );
      return channel;
    } catch (e) {
      return null;
    }
  }
}
