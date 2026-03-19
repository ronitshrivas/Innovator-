class Report {
  final String id;
  final User reporter;
  final User reportedUser;
  final String reason;
  final String description;
  final String status;
  final String createdAt;

  Report({
    required this.id,
    required this.reporter,
    required this.reportedUser,
    required this.reason,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['_id'],
      reporter: User.fromJson(json['reporter']),
      reportedUser: User.fromJson(json['reportedUser']),
      reason: json['reason'],
      description: json['description'],
      status: json['status'],
      createdAt: json['createdAt'],
    );
  }
}

class User {
  final String id;
  final String email;
  final String name;

  User({required this.id, required this.email, required this.name});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(id: json['_id'], email: json['email'], name: json['name']);
  }
}
