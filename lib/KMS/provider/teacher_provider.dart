import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/KMS/api_calling_services.dart/teacher_service.dart';
import 'package:innovator/KMS/model/teacher_model/student_model.dart';
import 'package:innovator/KMS/model/teacher_model/teacher-profile.dart';
import 'package:innovator/KMS/model/teacher_model/teacher_kyc_model.dart';
import 'package:innovator/KMS/model/teacher_model/teacher_salary_slips.dart';

final teacherServiceProvider = Provider<TeacherService>(
  (_) => TeacherService(),
);

final teacherProfileProvider = FutureProvider<TeacherProfileModel>((ref) {
  return ref.read(teacherServiceProvider).teacherProfile();
});

final checkInProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, schoolId) =>
      ref.read(teacherServiceProvider).checkIn(schoolId: schoolId),
);
final checkOutProvider = FutureProvider.family<Map<String, dynamic>, dynamic>(
  (ref, id) =>
      ref.read(teacherServiceProvider).checkOut(id: id),
);

final kycUploadProvider =
    FutureProvider.family<Map<String, dynamic>, Map<String, dynamic>>(
      (ref, params) => ref
          .read(teacherServiceProvider)
          .uploadKyc(
            idDoc: params['idDoc'] as File,
            bankAccountNumber: params['bankAccountNumber'] as String,
            bankName: params['bankName'] as String,
            citizenship: params['citizenship'] as String,
            photo: params['photo'] as File,
            cv: params['cv'] as File,
            nIdNumber: params['nIdNumber'] as String,
          ),
    );
final kycStatusProvider = FutureProvider<KycModel>((ref) {
  return ref.read(teacherServiceProvider).checkKycStatus();
});

final studentsProvider = FutureProvider<List<StudentModel>>((ref) {
  return ref.read(teacherServiceProvider).getStudents();
});

final markAttendanceProvider =
    FutureProvider.family<Map<String, dynamic>, Map<String, dynamic>>(
  (ref, params) => ref.read(teacherServiceProvider).markAttendance(
        studentId: params['student_id'] as String,
        classroomId: params['classroom_id'] as String,
        date: params['date'] as String,
        status: params['status'] as String,
        notes: params['notes'] as String,
      ),
);
final createStudentProvider =
    FutureProvider.family<Map<String, dynamic>, Map<String, dynamic>>(
  (ref, params) => ref.read(teacherServiceProvider).createStudent(
        name: params['name'] as String,
        schoolId: params['school'] as String,
        classroomId: params['classroom'] as String,
      ),
);

final salarySlipsProvider = FutureProvider<SalarySlipResponse>((ref) {
  return ref.read(teacherServiceProvider).getSalarySlips();
});