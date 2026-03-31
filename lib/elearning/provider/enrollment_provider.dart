import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/elearning/api_calling_service/course_list_service.dart';
import 'package:innovator/elearning/provider/course_provider.dart';

final enrollmentProvider =
    StateNotifierProvider<EnrollmentNotifier, Set<String>>(
  (ref) => EnrollmentNotifier(ref.read(courseServiceProvider)),
);
 
class EnrollmentNotifier extends StateNotifier<Set<String>> {
  final CourseListService _service;
 
  EnrollmentNotifier(this._service) : super({});
 
  Future<void> enroll(String courseId) async {
    await _service.enrollCourse(courseId);
    state = {...state, courseId};
  }
 
  bool isEnrolled(String courseId) => state.contains(courseId);
}
 