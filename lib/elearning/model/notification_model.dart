
class NotificationData {
  final String type;
  final String courseId;

  const NotificationData({
    required this.type,
    required this.courseId,
  });

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    return NotificationData(
      type: json['type'] as String,
      courseId: json['course_id'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'course_id': courseId,
  };
}

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String notificationType;
  final bool isRead;
  final DateTime createdAt;
  final NotificationData data;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.notificationType,
    required this.isRead,
    required this.createdAt,
    required this.data,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      notificationType: json['notification_type'] as String,
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      data: NotificationData.fromJson(
        json['data'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'notification_type': notificationType,
    'is_read': isRead,
    'created_at': createdAt.toIso8601String(),
    'data': data.toJson(),
  };

   static List<NotificationModel> fromJsonList(List<dynamic> jsonList) {
    return jsonList
      .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
      .toList();
  }
}


