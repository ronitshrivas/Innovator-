import 'package:flutter/material.dart';
import 'package:innovator/KMS/core/constants/app_style.dart';
import 'package:innovator/KMS/core/constants/mediaquery.dart';

class StudentAttendance {
  final String name;
  final int presentDays;
  final int absentDays;
  bool isPresent;

  StudentAttendance({
    required this.name,
    required this.presentDays,
    required this.absentDays,
    this.isPresent = false,
  });
}

class PartnerAttendanceSpecificGradeScreen extends StatefulWidget {
  const PartnerAttendanceSpecificGradeScreen({super.key});

  @override
  State<PartnerAttendanceSpecificGradeScreen> createState() =>
      _PartnerAttendanceSpecificGradeScreenState();
}

class _PartnerAttendanceSpecificGradeScreenState
    extends State<PartnerAttendanceSpecificGradeScreen> {
  // List of students with their attendance data
  final List<StudentAttendance> students = [
    StudentAttendance(name: 'Karthik Sharma', presentDays: 40, absentDays: 5),
    StudentAttendance(name: 'Priya Patel', presentDays: 38, absentDays: 7),
    StudentAttendance(name: 'Rahul Jaiswal', presentDays: 42, absentDays: 3),
    StudentAttendance(name: 'Anita Desai', presentDays: 41, absentDays: 4),
    StudentAttendance(name: 'Karthik Sharma', presentDays: 40, absentDays: 5),
    StudentAttendance(name: 'Pooja Gupta', presentDays: 38, absentDays: 7),
    StudentAttendance(name: 'Rahul Nepal', presentDays: 42, absentDays: 3),
    StudentAttendance(name: 'Sudhir Oli', presentDays: 41, absentDays: 4),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppStyle.primaryColor,
        title: Text(
          'Grade 1 Attendance',
          style: AppStyle.bodyText.copyWith(fontSize: 22),
        ),
        centerTitle: true,
        leading:
            Navigator.canPop(context)
                ? IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios),
                )
                : null,
      ),
      body: Padding(
        padding: EdgeInsets.only(
          top: context.screenHeight * 0.02,
          left: context.screenHeight * 0.02,
          right: context.screenHeight * 0.02,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Icon(
                          Icons.calendar_today_outlined,
                          color: AppStyle.primaryColor,
                          size: 24,
                        ),
                      ),
                      const WidgetSpan(child: SizedBox(width: 10)),
                      const TextSpan(
                        text: '11/11/2025',
                        style: TextStyle(
                          color: Color(0xff999999),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                width: double.infinity,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  color: Colors.white,
                ),
                child: _partnerAttendance(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _partnerAttendance() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 25,
          headingRowHeight: 70,
          dataRowMaxHeight: 70,
          showBottomBorder: true,
          headingRowColor: const WidgetStatePropertyAll(Color(0xffDDFFE7)),
          columns: const [
            DataColumn(
              label: Text(
                'S.N.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            DataColumn(
              label: Text(
                'Name',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            DataColumn(
              label: Text(
                'Status',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            DataColumn(
              label: Text(
                'No. of Present Days',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            DataColumn(
              label: Text(
                'No. of Absent Days',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
          rows: List.generate(
            students.length,
            (index) => _partnerAttendanceRow(
              sn: (index + 1).toString(),
              student: students[index],
              index: index,
            ),
          ),
        ),
      ),
    );
  }

  DataRow _partnerAttendanceRow({
    required String sn,
    required StudentAttendance student,
    required int index,
  }) {
    return DataRow(
      cells: [
        DataCell(Text(sn, style: const TextStyle(fontSize: 13))),
        DataCell(Text(student.name, style: const TextStyle(fontSize: 13))),
        DataCell(
          Checkbox(
            side: BorderSide(color: Colors.black),
            fillColor: WidgetStatePropertyAll(AppStyle.backgroundColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
              side: const BorderSide(color: Colors.black),
            ),
            checkColor: AppStyle.primaryColor,
            value: student.isPresent,
            onChanged: (bool? value) {
              setState(() {
                students[index].isPresent = value ?? false;
              });
            },
          ),
        ),
        DataCell(
          Text(
            student.presentDays.toString(),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        DataCell(
          Text(
            student.absentDays.toString(),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}
