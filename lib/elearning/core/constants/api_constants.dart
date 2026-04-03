class ElearningApi {
  static const String baseUrl = 'http://182.93.94.220:8003/api';
  static const String courseList = '$baseUrl/student/courses';
  static const String studentEnrollment = '$baseUrl/student/enrollments/';
  static const String payment = '$baseUrl/payments/initiate/';
  // time out
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(seconds: 120);
}
