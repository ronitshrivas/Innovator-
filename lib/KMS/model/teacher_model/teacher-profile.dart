// class TeacherProfileModel {
//   final String id;
//   final String name;
//   final String? email;
//   final String? phoneNumber;
//   final TeacherEarnings earnings;

//   TeacherProfileModel({
//     required this.id,
//     required this.name,
//     this.email,
//     this.phoneNumber,
//     required this.earnings,
//   });

//   factory TeacherProfileModel.fromJson(Map<String, dynamic> json) {
//     return TeacherProfileModel(
//       id: json['id'],
//       name: json['name'],
//       email: json['email'],
//       phoneNumber: json['phone_number'],
//       earnings: TeacherEarnings.fromJson(json['earnings']),
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'id': id,
//       'name': name,
//       'email': email,
//       'phone_number': phoneNumber,
//       'earnings': earnings.toJson(),
//     };
//   }
// }

// class TeacherEarnings {
//   final double totalEarnings;
//   final double totalPaid;
//   final double totalPending;
//   final double projectedEarnings;
//   final List<TeacherSchoolEarning> schools;

//   TeacherEarnings({
//     required this.totalEarnings,
//     required this.totalPaid,
//     required this.totalPending,
//     required this.projectedEarnings,
//     required this.schools,
//   });

//   factory TeacherEarnings.fromJson(Map<String, dynamic> json) {
//     return TeacherEarnings(
//       totalEarnings: (json['total_earnings'] as num).toDouble(),
//       totalPaid: (json['total_paid'] as num).toDouble(),
//       totalPending: (json['total_pending'] as num).toDouble(),
//       projectedEarnings: (json['projected_earnings'] as num).toDouble(),
//       schools: (json['schools'] as List)
//           .map((e) => TeacherSchoolEarning.fromJson(e))
//           .toList(),
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'total_earnings': totalEarnings,
//       'total_paid': totalPaid,
//       'total_pending': totalPending,
//       'projected_earnings': projectedEarnings,
//       'schools': schools.map((e) => e.toJson()).toList(),
//     };
//   }
// }

// class TeacherSchoolEarning {
//   final String schoolId;
//   final String schoolName;
//   final double totalEarnings;
//   final double projectedEarnings;
//   final int classesCount;

//   TeacherSchoolEarning({
//     required this.schoolId,
//     required this.schoolName,
//     required this.totalEarnings,
//     required this.projectedEarnings,
//     required this.classesCount,
//   });

//   factory TeacherSchoolEarning.fromJson(Map<String, dynamic> json) {
//     return TeacherSchoolEarning(
//       schoolId: json['school_id'],
//       schoolName: json['school_name'],
//       totalEarnings: (json['total_earnings'] as num).toDouble(),
//       projectedEarnings: (json['projected_earnings'] as num).toDouble(),
//       classesCount: json['classes_count'],
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'school_id': schoolId,
//       'school_name': schoolName,
//       'total_earnings': totalEarnings,
//       'projected_earnings': projectedEarnings,
//       'classes_count': classesCount,
//     };
//   }
// }

class TeacherClassroom {
  final String id;
  final String name;

  const TeacherClassroom({required this.id, required this.name});

  factory TeacherClassroom.fromJson(Map<String, dynamic> json) =>
      TeacherClassroom(
        id: json['id'] as String,
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class TeacherProfileModel {
  final String id;
  final String name;
  final String? email;
  final String? phoneNumber;
  final TeacherEarnings earnings;

  TeacherProfileModel({
    required this.id,
    required this.name,
    this.email,
    this.phoneNumber,
    required this.earnings,
  });

  factory TeacherProfileModel.fromJson(Map<String, dynamic> json) {
    return TeacherProfileModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phoneNumber: json['phone_number'],
      earnings: TeacherEarnings.fromJson(json['earnings']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone_number': phoneNumber,
      'earnings': earnings.toJson(),
    };
  }
}

class TeacherEarnings {
  final double totalEarnings;
  final double totalPaid;
  final double totalPending;
  final double projectedEarnings;
  final List<TeacherSchoolEarning> schools;

  TeacherEarnings({
    required this.totalEarnings,
    required this.totalPaid,
    required this.totalPending,
    required this.projectedEarnings,
    required this.schools,
  });

  factory TeacherEarnings.fromJson(Map<String, dynamic> json) {
    return TeacherEarnings(
      totalEarnings: (json['total_earnings'] as num).toDouble(),
      totalPaid: (json['total_paid'] as num).toDouble(),
      totalPending: (json['total_pending'] as num).toDouble(),
      projectedEarnings: (json['projected_earnings'] as num).toDouble(),
      schools: (json['schools'] as List)
          .map((e) => TeacherSchoolEarning.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_earnings': totalEarnings,
      'total_paid': totalPaid,
      'total_pending': totalPending,
      'projected_earnings': projectedEarnings,
      'schools': schools.map((e) => e.toJson()).toList(),
    };
  }
}

class TeacherSchoolEarning {
  final String schoolId;
  final String schoolName;
  final List<TeacherClassroom> classrooms;
  final double totalEarnings;
  final double totalCommission;
  final double projectedEarnings;
  final int classesCount;

  TeacherSchoolEarning({
    required this.schoolId,
    required this.schoolName,
    required this.classrooms,
    required this.totalEarnings,
    required this.totalCommission,
    required this.projectedEarnings,
    required this.classesCount,
  });

  factory TeacherSchoolEarning.fromJson(Map<String, dynamic> json) {
    return TeacherSchoolEarning(
      schoolId: json['school_id'] as String,
      schoolName: json['school_name'] as String,
      classrooms: (json['classrooms'] as List? ?? [])
          .map((e) => TeacherClassroom.fromJson(e))
          .toList(),
      totalEarnings: (json['total_earnings'] as num).toDouble(),
      totalCommission: (json['total_commission'] as num).toDouble(),
      projectedEarnings: (json['projected_earnings'] as num).toDouble(),
      classesCount: json['classes_count'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'school_id': schoolId,
      'school_name': schoolName,
      'classrooms': classrooms.map((e) => e.toJson()).toList(),
      'total_earnings': totalEarnings,
      'total_commission': totalCommission,
      'projected_earnings': projectedEarnings,
      'classes_count': classesCount,
    };
  }
}