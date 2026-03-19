import 'dart:io';
import 'package:dio/dio.dart';
import 'package:innovator/KMS/core/constants/api_constants.dart';
import 'package:innovator/KMS/core/constants/network/base_api_service.dart';
import 'package:innovator/KMS/core/constants/network/dio_client.dart';
import 'package:innovator/KMS/model/teacher_model/student_model.dart';
import 'package:innovator/KMS/model/teacher_model/teacher-profile.dart';
import 'package:innovator/KMS/model/teacher_model/teacher_kyc_model.dart';
import 'package:innovator/KMS/model/teacher_model/teacher_salary_slips.dart';
 

class TeacherService extends BaseApiService {
  TeacherService() : super(dio: DioClient.instance);

  Future<TeacherProfileModel> teacherProfile() async {
    final data = await get<Map<String, dynamic>>(ApiConstants.teacherProfile);
    return TeacherProfileModel.fromJson(data);
  }

  Future<Map<String, dynamic>> checkIn({required String schoolId}) async {
    return await post<Map<String, dynamic>>(
      ApiConstants.teacherCheckIn,
      data: {'school': schoolId, 'check_in': DateTime.now().toIso8601String()},
    );
  }

  Future<Map<String, dynamic>> checkOut({required dynamic id}) async {
    return await post<Map<String, dynamic>>(
      ApiConstants.teacherCheckOut(id),
      data: {'check_out': DateTime.now().toIso8601String()},
    );
  }

  Future<Map<String, dynamic>> uploadKyc({
    required File idDoc,
    required String bankAccountNumber,
    required String bankName,
    required String citizenship,
    required File photo,
    required File cv,
    required String nIdNumber,
  }) async {
    final formData = FormData.fromMap({
      'id_doc': await MultipartFile.fromFile(
        idDoc.path,
        filename: idDoc.path.split('/').last,
      ),
      'bank_account_number': bankAccountNumber,
      'bank_name': bankName,
      'citizenship': citizenship,
      'photo': await MultipartFile.fromFile(
        photo.path,
        filename: photo.path.split('/').last,
      ),
      'cv': await MultipartFile.fromFile(
        cv.path,
        filename: cv.path.split('/').last,
      ),
      'n_id_number': nIdNumber,
    });

    return await post<Map<String, dynamic>>(
      ApiConstants.teacherKyc,
      data: formData,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );
  }

  Future<KycModel> checkKycStatus() async {
    final data = await get<Map<String, dynamic>>(ApiConstants.teacherKyc);
    return KycModel.fromJson(data);
  }

 Future<List<StudentModel>> getStudents() async {
  final data = await get<List<dynamic>>(ApiConstants.students);
  return data
      .map((e) => StudentModel.fromJson(e as Map<String, dynamic>))
      .toList();
}

  Future<Map<String, dynamic>> markAttendance({
    required String studentId,
    required String classroomId,
    required String date,
    required String status,  
    required String notes,
  }) async {
    return await post<Map<String, dynamic>>(
      ApiConstants.markAttendance,
      data: {
        'student_id': studentId,
        'classroom_id': classroomId,
        'date': date,
        'status': status,
        'notes': notes,
      },
    );
  }
  Future<Map<String, dynamic>> createStudent({
  required String name,
  required String schoolId,
  required String classroomId,
}) async {
  return await post<Map<String, dynamic>>(
    ApiConstants.addStudents,
    data: {
      'name': name,
      'school': schoolId,
      'classroom': classroomId,
    },
  );
}
Future<SalarySlipResponse> getSalarySlips() async {
  final data = await get<Map<String, dynamic>>(ApiConstants.teacherSalarySlips);
  return SalarySlipResponse.fromJson(data);
}
}
