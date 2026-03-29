class TeacherSessionResponse {
  final int totalSessions;
  final List<TeacherSessionModel> sessions;

  TeacherSessionResponse({
    required this.totalSessions,
    required this.sessions,
  });

  factory TeacherSessionResponse.fromJson(Map<String, dynamic> json) =>
      TeacherSessionResponse(
        totalSessions: json['total_sessions'] as int,
        sessions: (json['sessions'] as List)
            .map((e) =>
                TeacherSessionModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TeacherSessionModel {
  final String teacherId;
  final String teacherName;
  final String classroomId;
  final String classroomName;
  final String date;
  final String notes;
  final int studentCount;

  TeacherSessionModel({
    required this.teacherId,
    required this.teacherName,
    required this.classroomId,
    required this.classroomName,
    required this.date,
    required this.notes,
    required this.studentCount,
  });

  factory TeacherSessionModel.fromJson(Map<String, dynamic> json) =>
      TeacherSessionModel(
        teacherId: json['teacher__id'] as String,
        teacherName: json['teacher__name'] as String,
        classroomId: json['classroom__id'] as String,
        classroomName: json['classroom__name'] as String,
        date: json['date'] as String,
        notes: json['notes'] as String,
        studentCount: json['student_count'] as int,
      );
}