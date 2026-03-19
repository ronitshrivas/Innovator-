import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/KMS/screens/constant_screen/custom_scroll.dart';

class PartnerAssignedSchoolScreen extends ConsumerWidget {
  const PartnerAssignedSchoolScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Map<String, String>> partnerAssignedData = [
      {
        'schoolDetails': 'Greenwod Academy',
        'grade': 'Grade 1- 10',
        'schedule': 'Mon, Wed, Fri',
        'scheduleHoursPerWeek': '\n15 hrs/ week',
        'student': '500',
        'classes': '10',
        'attendance': '92%',
        'avgScore': '78',
        'pendingTask': '2',
      },
      {
        'schoolDetails': 'Starlight Academy',
        'grade': 'Grade 1- 10',
        'schedule': 'Sun, Tue, Fri',
        'scheduleHoursPerWeek': '\n17 hrs/ week',
        'student': '200',
        'classes': '8',
        'attendance': '100%',
        'avgScore': '99',
        'pendingTask': '0',
      },
      {
        'schoolDetails': 'Nepatronix Engineering Solution Academy',
        'grade': 'Grade 5- 10',
        'schedule': 'Tue, Wed ,Thu',
        'scheduleHoursPerWeek': '\n3 hrs/ week',
        'student': '372',
        'classes': '9',
        'attendance': '12%',
        'avgScore': '44',
        'pendingTask': '9',
      },
      {
        'schoolDetails': 'Patan Multiple Campus',
        'grade': 'Grade 8- 10',
        'schedule': 'Mon, Wed',
        'scheduleHoursPerWeek': '\n8 hrs/ week',
        'student': '70',
        'classes': '3',
        'attendance': '62%',
        'avgScore': '88',
        'pendingTask': '3',
      },
    ];
    return CustomScrolling(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Assigned Schools',
            style: TextStyle(fontFamily: 'Inter', fontSize: 15),
          ),
          Text(
            'Managing 3 schools • 500 total students',
            style: TextStyle(color: Color(0xff999999), fontSize: 12),
          ),
          SizedBox(height: 10),
          GridView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
                  physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.6,
              crossAxisSpacing: 30,
              mainAxisSpacing: 20,
            ),
            children: [
              cardContainer(
                'assets/kms/total_schools.png',
                'Total Schools',
                '3',
                color: Color(0xff2C62EE),
              ),
              cardContainer(
                'assets/kms/total_students.png',
                'Total Students',
                '1500',
                color: Color(0xff0CC740),
              ),
              cardContainer(
                'assets/kms/pending_review.png',
                'Weekly hours',
                '37',
                color: Color(0xffFB923C),
              ),
              cardContainer(
                'assets/kms/assignment.png',
                'Pending Task',
                '6',
                color: Color(0xffF93333),
              ),
            ],
          ),
          SizedBox(height: 30,),
          Container(
            clipBehavior: Clip.antiAlias,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              color: Colors.white,
            ),
            child: partnerAssignedSchool(partnerAssignedData),
          ),
        ],
      ),
    );
  }

  Widget cardContainer(
    String image,
    String title,
    String numbers, {
    Color? color,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      elevation: 3,
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.only(right: 10, left: 10),
        child: FittedBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Image.asset(image, color: color),
                  SizedBox(width: 8),
                  Text(title, style: TextStyle(fontSize: 14, color: color)),
                ],
              ),
              SizedBox(height: 10),
              Text(
                numbers,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget partnerAssignedSchool(List<Map<String, String>> partnerAssignedData) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 25,
        headingRowHeight: 70,
        dataRowMaxHeight: 50,
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontFamily: 'Inter',
          fontSize: 12,
        ),
        showBottomBorder: true,

        border: TableBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        headingRowColor: WidgetStatePropertyAll(Color(0xffDDFFE7)),

        columns: [
          DataColumn(label: Text('School Details')),
          DataColumn(label: Text('Grades')),
          DataColumn(label: Text('Schedule')),
          DataColumn(label: Text('Students')),
          DataColumn(label: Text('Classes')),
          DataColumn(label: Text('Attendance')),
          DataColumn(label: Text('Avg Score')),
          DataColumn(label: Text('Pending Tasks')),
        ],
        rows:
            partnerAssignedData
                .map<DataRow>(
                  (partnerAssignedSchool) => partnerAssignedSchoolRow(
                    partnerAssignedSchool['schoolDetails']!,
                    partnerAssignedSchool['grade']!,
                    partnerAssignedSchool['schedule']!,
                    partnerAssignedSchool['scheduleHoursPerWeek']!,
                    partnerAssignedSchool['student']!,
                    partnerAssignedSchool['classes']!,
                    partnerAssignedSchool['attendance']!,
                    partnerAssignedSchool['avgScore']!,
                    partnerAssignedSchool['pendingTask']!,
                  ),
                )
                .toList(),
      ),
    );
  }

  DataRow partnerAssignedSchoolRow(
    String schoolDetails,
    String grades,
    String schedule,
    String scheduleHoursPerWeek,
    String students,
    String classes,
    String attendance,
    String avgScore,
    String pendingTasks,
  ) {
    return DataRow(
      cells: [
        DataCell(
          Text(
            schoolDetails,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),

        DataCell(
          Text(
            grades,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
          ),
        ),
        DataCell(
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: schedule,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text: scheduleHoursPerWeek,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          Text(
            students,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
          ),
        ),

        DataCell(
          Text(
            classes,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
          ),
        ),
        DataCell(
          Text(
            attendance,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
          ),
        ),
        DataCell(
          Text(
            avgScore,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
          ),
        ),
        DataCell(
          Text(
            pendingTasks,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
          ),
        ),
      ],
    );
  }
}
