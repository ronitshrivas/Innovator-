class CourseListModel {
  final String id;
  final String vendor;
  final String vendorName;
  final String category;
  final String categoryName;
  final String title;
  final String description;
  final double price;
  final String courseType;
  final bool isPublished;
  final bool isEnrolled;
  final DateTime createdAt;
  final List<CourseContent> contents;

  CourseListModel({
    required this.id,
    required this.vendor,
    required this.vendorName,
    required this.category,
    required this.categoryName,
    required this.title,
    required this.description,
    required this.price,
    required this.courseType,
    required this.isPublished,
    required this.isEnrolled,
    required this.createdAt,
    required this.contents,
  });

  bool get isFree => courseType == 'free';

  factory CourseListModel.fromJson(Map<String, dynamic> json) {
    return CourseListModel(
      id: json['id'] ?? '',
      vendor: json['vendor'] ?? '',
      vendorName: json['vendor_name'] ?? '',
      category: json['category'] ?? '',
      categoryName: json['category_name'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      courseType: json['course_type'] ?? '',
      isPublished: json['is_published'] ?? false,
      isEnrolled: json['is_enrolled'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      contents: (json['contents'] as List?)
              ?.map((e) => CourseContent.fromJson(e))
              .toList() ??
          [],
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
      'course_type': courseType,
      'is_published': isPublished,
      'is_enrolled': isEnrolled,
      'created_at': createdAt.toIso8601String(),
      'contents': contents.map((e) => e.toJson()).toList(),
    };
  }
}

class CourseContent {
  final String id;
  final String course;
  final String title;
  final String instructorName;
  final String? videoUrl;
  final String? videoFile;
  final String? thumbnail;
  final double duration;
  final String? documentUrl;
  final String? documentFile;
  final String courseLevel;
  final int order;
  final DateTime createdAt;

  CourseContent({
    required this.id,
    required this.course,
    required this.title,
    required this.instructorName,
    this.videoUrl,
    this.videoFile,
    this.thumbnail,
    required this.duration,
    this.documentUrl,
    this.documentFile,
    required this.courseLevel,
    required this.order,
    required this.createdAt,
  });

  factory CourseContent.fromJson(Map<String, dynamic> json) {
    return CourseContent(
      id: json['id'] ?? '',
      course: json['course'] ?? '',
      title: json['title'] ?? '',
      instructorName: json['instructor_name'] ?? '',
      videoUrl: json['video_url'],
      videoFile: json['video_file'],
      thumbnail: json['thumbnail'],
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      documentUrl: json['document_url'],
      documentFile: json['document_file'],
      courseLevel: json['course_level'] ?? '',
      order: json['order'] ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course': course,
      'title': title,
      'instructor_name': instructorName,
      'video_url': videoUrl,
      'video_file': videoFile,
      'thumbnail': thumbnail,
      'duration': duration,
      'document_url': documentUrl,
      'document_file': documentFile,
      'course_level': courseLevel,
      'order': order,
      'created_at': createdAt.toIso8601String(),
    };
  }
}