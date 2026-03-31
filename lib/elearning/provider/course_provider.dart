// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:innovator/elearning/api_calling_service/course_list_service.dart';
// import 'package:innovator/elearning/model/course_list_model.dart';

// final courseServiceProvider = Provider<CourseListService>(
//   (ref) => CourseListService(),
// );

// final courseListProvider = FutureProvider<List<CourseListModel>>((ref) {
//   final course = ref.watch(courseServiceProvider);
//   return course.getCourseList();
// });

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/elearning/api_calling_service/course_list_service.dart';
import 'package:innovator/elearning/model/course_list_model.dart';

/// Provides a singleton instance of [CourseListService]
final courseServiceProvider = Provider<CourseListService>(
  (ref) => CourseListService(),
);

/// Fetches the full list of courses from the API
final courseListProvider = FutureProvider<List<CourseListModel>>((ref) {
  final course = ref.watch(courseServiceProvider);
  return course.getCourseList();
});