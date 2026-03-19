import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:innovator/KMS/core/constants/app_style.dart';
import 'package:innovator/KMS/screens/constant_screen/custom_scroll.dart';
import 'package:innovator/KMS/screens/teacher/partner_attendance_specific_school.dart';

class PartenerAttendanceScreen extends ConsumerWidget {
  const PartenerAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrolling(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Attendance',
                style: AppStyle.bodyText.copyWith(color: Colors.black),
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
              'School Name',
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
        ],
        rows: [
          _partnerAttendanceRow('1', 'Straight Academy', '205', '200', '5'),
          _partnerAttendanceRow('2', 'Green Valley School', '301', '300', '1'),
          _partnerAttendanceRow('3', 'Vidya Niketan', '405', '400', '5'),
          _partnerAttendanceRow('4', 'Silver Oak High', '280', '277', '5'),
          _partnerAttendanceRow('5', 'Christ Academy', '77', '75', '2'),
          _partnerAttendanceRow('6', 'Satyal Institute', '125', '121', '4'),
          _partnerAttendanceRow('7', 'Durbar High School', '199', '197', '2'),
          _partnerAttendanceRow(
            '8',
            'Nepatronix Engineering ',
            '25',
            '25',
            '0',
          ),
          _partnerAttendanceRow(
            '9',
            'Crescent Public School',
            '225',
            '221',
            '4',
          ),
        ],
      ),
    );
  }

  DataRow _partnerAttendanceRow(
    String sn,
    String schoolName,
    String totalStudent,
    String presentNumber,
    String absentNumber,
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
            schoolName,
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
      ],
    );
  }

  void _navigateToSchoolDetails() {
    Get.to(
      () => PartnerAttendanceSpecificSchoolScreen(),
      transition: Transition.leftToRight,
    );
  }
}
