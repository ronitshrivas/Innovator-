import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/KMS/api_calling_services.dart/coordinator_service.dart'; 
import 'package:innovator/KMS/model/coordinator_model/coordinator_teacher_response_model.dart';
import 'package:innovator/KMS/model/coordinator_model/teacher_notes_model.dart';

final coordinatorServiceProvider = Provider<CoordinatorService>(
  (_) => CoordinatorService(),
);

final coordinatorAttendanceProvider =
    FutureProvider<CoordinatorAttendanceResponse>((ref) {
  return ref.watch(coordinatorServiceProvider).getTeacherAttendances();
});

final updateAttendanceProvider =
    FutureProvider.family<Map<String, dynamic>, Map<String, String>>(
  (ref, params) => ref.read(coordinatorServiceProvider).updateAttendance(
        attendanceId: params['attendanceId']!,
        action: params['action']!,
      ),
);

final coordinatorInvoicesProvider =
    FutureProvider<List<CoordinatorInvoiceModel>>((ref) {
  return ref.watch(coordinatorServiceProvider).getInvoices();
});

final teacherSessionsProvider = FutureProvider<TeacherSessionResponse>((ref) {
  return ref.watch(coordinatorServiceProvider).getTeacherSessions();
});

final verifySessionProvider =
    FutureProvider.family<Map<String, dynamic>, Map<String, String?>>(
  (ref, params) => ref.read(coordinatorServiceProvider).verifyTeacherSession(
        teacherId: params['teacherId']!,
        classroomId: params['classroomId']!,
        date: params['date']!,
        notes: params['notes']!,
        action: params['action']!,
        coordinatorNotes: params['coordinatorNotes'],
      ),
);