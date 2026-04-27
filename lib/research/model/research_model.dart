class ResearchPaperModel {
  final int id;
  final String email;
  final String title;
  final String description;
  final String fileUrl;
  final String type;
  final double price;
  final String status;
  final String paymentStatus;
  final String? khaltiPidx;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ResearchPaperModel({
    required this.id,
    required this.email,
    required this.title,
    required this.description,
    required this.fileUrl,
    required this.type,
    required this.price,
    required this.status,
    required this.paymentStatus,
    this.khaltiPidx,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPaid => type == 'paid';
  bool get isActive => status == 'active';
  bool get isPaymentCompleted => paymentStatus == 'completed';

  factory ResearchPaperModel.fromJson(Map<String, dynamic> json) {
    return ResearchPaperModel(
      id: json['id'] as int,
      email: json['email'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      fileUrl: json['file_url'] as String,
      type: json['type'] as String,
      price: (json['price'] as num).toDouble(),
      status: json['status'] as String,
      paymentStatus: json['payment_status'] as String,
      khaltiPidx: json['khalti_pidx'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'title': title,
        'description': description,
        'file_url': fileUrl,
        'type': type,
        'price': price,
        'status': status,
        'payment_status': paymentStatus,
        'khalti_pidx': khaltiPidx,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class ResearchPaperResponseModel {
  final List<ResearchPaperModel> data;
  final int page;
  final int limit;

  const ResearchPaperResponseModel({
    required this.data,
    required this.page,
    required this.limit,
  });

  factory ResearchPaperResponseModel.fromJson(Map<String, dynamic> json) {
    return ResearchPaperResponseModel(
      data: (json['data'] as List<dynamic>)
          .map((e) => ResearchPaperModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int,
      limit: json['limit'] as int,
    );
  }
}