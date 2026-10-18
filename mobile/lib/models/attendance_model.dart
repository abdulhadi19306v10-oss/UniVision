class CourseSummary {
  final int courseId;
  final String courseCode;
  final String courseName;
  final int totalSessions;
  final int attendedSessions;
  final double attendancePercentage;
  final bool isBelowThreshold;

  CourseSummary({
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.totalSessions,
    required this.attendedSessions,
    required this.attendancePercentage,
    required this.isBelowThreshold,
  });

  factory CourseSummary.fromJson(Map<String, dynamic> json) {
    return CourseSummary(
      courseId: json['course_id'],
      courseCode: json['course_code'],
      courseName: json['course_name'],
      totalSessions: json['total_sessions'],
      attendedSessions: json['attended_sessions'],
      attendancePercentage: (json['attendance_percentage'] as num).toDouble(),
      isBelowThreshold: json['is_below_threshold'] ?? false,
    );
  }
}

class AttendanceHistoryItem {
  final int attendanceId;
  final String courseCode;
  final String courseName;
  final int sessionId;
  final DateTime markedAt;
  final String method;
  final double? confidence;

  AttendanceHistoryItem({
    required this.attendanceId,
    required this.courseCode,
    required this.courseName,
    required this.sessionId,
    required this.markedAt,
    required this.method,
    this.confidence,
  });

  factory AttendanceHistoryItem.fromJson(Map<String, dynamic> json) {
    return AttendanceHistoryItem(
      attendanceId: json['attendance_id'] ?? json['id'] ?? 0,
      courseCode: json['course_code'] ?? 'CS-401',
      courseName: json['course_name'] ?? 'Lecture Session',
      sessionId: json['session_id'] ?? 1,
      markedAt: json['marked_at'] != null ? DateTime.parse(json['marked_at']) : DateTime.now(),
      method: json['method'] ?? 'face',
      confidence: json['confidence'] != null ? (json['confidence'] as num).toDouble() : null,
    );
  }
}
