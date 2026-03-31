// import 'package:innovator/ecommerce/core/constants/network/dio_client.dart';
// import 'package:innovator/elearning/core/constants/api_constants.dart';
// import 'package:innovator/elearning/core/constants/network/base_api_service.dart';
// import 'package:innovator/elearning/model/course_list_model.dart';

// class CourseListService extends ElearningBaseApiService {
//   CourseListService() : super(dio: DioClient.instance);

//   Future<List<CourseListModel>> getCourseList() async {
//     final data = await get<List<dynamic>>(ElearningApi.courseList);
//     return data
//         .map((e) => CourseListModel.fromJson(e as Map<String, dynamic>))
//         .toList();
//   }


//     Future<void> enrollCourse(String courseId) async {
//     await post<Map<String, dynamic>>(
//       ElearningApi.studentEnrollment,
//       data: {'course': courseId},
//     );
//   }
// }

import 'package:innovator/ecommerce/core/constants/network/dio_client.dart';
import 'package:innovator/elearning/core/constants/api_constants.dart';
import 'package:innovator/elearning/core/constants/network/base_api_service.dart';
import 'package:innovator/elearning/model/course_list_model.dart';

class CourseListService extends ElearningBaseApiService {
  CourseListService() : super(dio: DioClient.instance);

  /// Fetches the list of all published courses
  Future<List<CourseListModel>> getCourseList() async {
    final data = await get<List<dynamic>>(ElearningApi.courseList);
    return data
        .map((e) => CourseListModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
 
  Future<void> enrollCourse(String courseId) async {
    await post<Map<String, dynamic>>(
      ElearningApi.studentEnrollment,
      data: {'course': courseId},
    );
  }
}