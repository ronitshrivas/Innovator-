class CourseContent {
  final String id;
  final String title;
  final String videoUrl;
  final String? documentUrl;
  final String courseLevel;
  final int order;
  final DateTime createdAt;
  final String course;

  CourseContent({
    required this.id,
    required this.title,
    required this.videoUrl,
    this.documentUrl,
    required this.courseLevel,
    required this.order,
    required this.createdAt,
    required this.course,
  });

  factory CourseContent.fromJson(Map<String, dynamic> json) {
    return CourseContent(
      id: json['id'] as String,
      title: json['title'] as String,
      videoUrl: json['video_url'] as String,
      documentUrl: json['document_url'] as String?,
      courseLevel: json['course_level'] as String,
      order: json['order'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      course: json['course'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'video_url': videoUrl,
      'document_url': documentUrl,
      'course_level': courseLevel,
      'order': order,
      'created_at': createdAt.toIso8601String(),
      'course': course,
    };
  }

  @override
  String toString() {
    return 'CourseContent(id: $id, title: $title, courseLevel: $courseLevel, order: $order)';
  }
}

class Course {
  final String id;
  final String vendor;
  final String vendorName;
  final String category;
  final String categoryName;
  final String title;
  final String description;
  final double price;
  final bool isPublished;
  final DateTime createdAt;
  final List<CourseContent> contents;

  Course({
    required this.id,
    required this.vendor,
    required this.vendorName,
    required this.category,
    required this.categoryName,
    required this.title,
    required this.description,
    required this.price,
    required this.isPublished,
    required this.createdAt,
    required this.contents,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      vendor: json['vendor'] as String,
      vendorName: json['vendor_name'] as String,
      category: json['category'] as String,
      categoryName: json['category_name'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      price: double.parse(json['price'] as String),
      isPublished: json['is_published'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      contents: (json['contents'] as List<dynamic>)
          .map((item) => CourseContent.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendor': vendor,
      'vendor_name': vendorName,
      'category': category,
      'category_name': categoryName,
      'title': title,
      'description': description,
      'price': price.toStringAsFixed(2),
      'is_published': isPublished,
      'created_at': createdAt.toIso8601String(),
      'contents': contents.map((c) => c.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'Course(id: $id, title: $title, price: $price, isPublished: $isPublished)';
  }
} 
List<Course> parseCourses(List<dynamic> jsonList) {
  return jsonList
      .map((item) => Course.fromJson(item as Map<String, dynamic>))
      .toList();
}