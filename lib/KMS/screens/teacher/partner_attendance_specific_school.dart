import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:innovator/KMS/core/constants/app_style.dart';
import 'package:innovator/KMS/core/constants/mediaquery.dart';
import 'package:innovator/KMS/screens/teacher/partner_attendance_specific_grade.dart';

class PartnerAttendanceSpecificSchoolScreen extends ConsumerWidget {
  const PartnerAttendanceSpecificSchoolScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppStyle.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppStyle.primaryColor,
        title: Text(
          'Starlight Academy',
          style: AppStyle.bodyText.copyWith(fontSize: 22),
        ),
        centerTitle: true,
        leading:
            Navigator.canPop(context)
                ? IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.arrow_back_ios),
                )
                : null,
      ),
      body: Padding(
        padding: EdgeInsets.only(
          top: context.screenHeight * 0.02,
          right: context.screenHeight * 0.02,
          left: context.screenHeight * 0.02,
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attendance',
                    style: AppStyle.bodyText.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                      fontSize: 16,
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(
                            Icons.calendar_today_outlined,
                            color: AppStyle.primaryColor,
                            size: 24,
                          ),
                        ),
                        WidgetSpan(child: SizedBox(width: 10)),
                        TextSpan(
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
              SizedBox(height: 20),
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
                child: _partnerAttendance(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _partnerAttendance() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 25,
        headingRowHeight: 70,
        dataRowMaxHeight: 50,
        showBottomBorder: true,
        border: TableBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        headingRowColor: WidgetStatePropertyAll(Color(0xffDDFFE7)),
        columns: [
          DataColumn(
            label: Text(
              'S.N.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
                fontSize: 12,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Class',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
                fontSize: 12,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Total Student',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
                fontSize: 12,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'No. of Present',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
                fontSize: 12,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'No. of Absent',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
                fontSize: 12,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Week',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
                fontSize: 12,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Ongoing Lecture',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
                fontSize: 12,
              ),
            ),
          ),
        ],
        rows: [
          _partnerAttendanceRow(
            '1',
            ' Grade 1',
            '205',
            '200',
            '5',
            '1',
            'First Module Introduction',
          ),
          _partnerAttendanceRow(
            '2',
            'Grade 2',
            '301',
            '300',
            '1',
            '2',
            'Components of IoT',
          ),
          _partnerAttendanceRow(
            '3',
            'Grade 3',
            '405',
            '400',
            '5',
            '3',
            'Worked on Small Project',
          ),
          _partnerAttendanceRow(
            '4',
            'Grade 4',
            '280',
            '277',
            '5',
            '1',
            'Presentation of Project',
          ),
          _partnerAttendanceRow(
            '5',
            'Grade 5',
            '77',
            '75',
            '2',
            '5',
            'Grading of the Project',
          ),
        ],
      ),
    );
  }

  DataRow _partnerAttendanceRow(
    String sn,
    String classes,
    String totalStudent,
    String presentNumber,
    String absentNumber,
    String week,
    String ongoingLecture,
  ) {
    return DataRow(
      cells: [
        DataCell(
          onTap: () => _navigateToSchoolDetails(),
          Text(sn, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400)),
        ),
        DataCell(
          onTap: () => _navigateToSchoolDetails(),
          Text(
            classes,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
          ),
        ),

        DataCell(
          onTap: () => _navigateToSchoolDetails(),
          Text(
            totalStudent,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
          ),
        ),
        DataCell(
          onTap: () => _navigateToSchoolDetails(),
          Text(
            presentNumber,

            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
          ),
        ),
        DataCell(
          onTap: () => _navigateToSchoolDetails(),
          Text(
            absentNumber,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
          ),
        ),
        DataCell(
          onTap: () => _navigateToSchoolDetails(),
          Text(
            week,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
          ),
        ),
        DataCell(
          onTap: () => _navigateToSchoolDetails(),
          Text(
            ongoingLecture,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
          ),
        ),
      ],
    );
  }

  void _navigateToSchoolDetails() {
    Get.to(
      () => PartnerAttendanceSpecificGradeScreen(),
      transition: Transition.leftToRight,
    );
  }
}
