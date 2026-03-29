import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/KMS/core/constants/app_style.dart';
import 'package:innovator/KMS/screens/constant_screen/custom_scroll.dart';

final selectedSchoolProvider = StateProvider<String>((ref) => "All Schools");
final selectedGradeProvider = StateProvider<String>((ref) => "All Grade");

class PartnerAssignmentManagementScreen extends ConsumerWidget {
  const PartnerAssignmentManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSchools = ref.watch(selectedSchoolProvider);
    final selectedGrade = ref.watch(selectedGradeProvider);
    const List<String> allSchools = [
      "All Schools",
      "Nepatronix Institute of Science and Technologysdarsgdshfhgdfgfffgfdg",
      "Patan Multiple Campus",
      "Madan Bhandari Memorial School",
      "Amrit Science School",
    ];

    const List<String> grades = [
      "All Grade",
      "Grade 1",
      "Grade 2",
      "Grade 3",
      "Grade 4",
      "Grade 5",
      "Grade 6",
      "Grade 7",
      "Grade 8",
      "Grade 9",
      "Grade 10",
      "Grade 11",
      "Grade 12",
    ];

    return CustomScrolling(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assignment Management',
            style: TextStyle(
              fontFamily: AppStyle.fontFamilySecondary,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 10),
          assignmentManagementCard(
            'Active assignments',
            '2',
            'assets/kms/active_assignment.png',
            cardColor: Color(0xffbcd8ff).withAlpha(100),
            textColor: Color(0xff2C62EE),
          ),
          assignmentManagementCard(
            'Total Submitted',
            '158/250',
            'assets/kms/total_submitted.png',
            cardColor: Color(0xffb6f7ce).withAlpha(80),
            textColor: Color(0xff0CC740),
          ),
          assignmentManagementCard(
            'Pending Review',
            '40',
            'assets/kms/pending_review.png',
            cardColor: Color(0xfffde4b8).withAlpha(200),
            textColor: Color(0xffFB923C),
          ),
          assignmentManagementCard(
            'Late Submission',
            '158',
            'assets/kms/late_submission.png',
            cardColor: Color(0xfff5c2c2).withAlpha(150),
            textColor: Color(0xffF93333),
          ),
          SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              dropDown(
                value: selectedSchools,
                items: allSchools,
                onChanged: (newValue) {
                  if (newValue != null) {
                    ref.read(selectedSchoolProvider.notifier).state = newValue;
                  }
                },
              ),
              dropDown(
                value: selectedGrade,
                items: grades,
                onChanged: (newValue) {
                  if (newValue != null) {
                    ref.read(selectedGradeProvider.notifier).state = newValue;
                  }
                },
              ),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppStyle.primaryColor,
                ),
                child: Icon(
                  Icons.add,
                  color: AppStyle.backgroundColor,
                  size: 40,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          courseContent(
            'Basic of Electronics',
            'Active',
            'Sunrise Academy',
            'Grade 9,10',
            'Due: 2025-11-29',
            '✓ 48 Submitted',
            '✓ 17Pending',
            '74',
            74,
            26,
            '65',
            textColor: Color(0xff0CC740),
          ),
          courseContent(
            'Basic of Electronics',
            'Active',
            'Sunrise Academy',
            'Grade 9,10',
            'Due: 2025-11-29',
            '✓ 48 Submitted',
            '✓ 17Pending',
            '74',
            74,
            26,
            '65',
            textColor: Color(0xff0CC740),
          ),
        ],
      ),
    );
  }

  Widget assignmentManagementCard(
    String heading,
    String numbers,
    String image, {
    Color? cardColor,
    Color? textColor,
  }) {
    return Column(
      children: [
        Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                top: 10,
                right: 10,
                left: 10,
                bottom: 50,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        heading,
                        style: TextStyle(color: textColor, fontSize: 18),
                      ),
                      Image.asset(image),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 30, top: 10),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: AppStyle.fontFamilySecondary,
                          color: textColor,
                        ),
                        children: [
                          if (numbers.contains('/')) ...[
                            TextSpan(text: numbers.split('/').first),
                            TextSpan(
                              text: '/${numbers.split('/').last}',
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                          ] else
                            TextSpan(text: numbers),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget dropDown<T>({
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    String Function(T)? displayString,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.black87,
                size: 28,
              ),
              iconSize: 28,
              elevation: 4,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              items:
                  items.map((T item) {
                    return DropdownMenuItem<T>(
                      value: item,
                      child: Text(
                        displayString?.call(item) ?? item.toString(),
                        overflow:
                            TextOverflow
                                .ellipsis, // Prevent overflow on long text
                      ),
                    );
                  }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }

  Widget courseContent(
    String topic,
    String status,
    String schoolName,
    String grade,
    String dueDate,
    String submittedNumber,
    String pendingNumber,
    String completionPercentage,
    int completedPercentage,
    int pendingPercentage,
    String numbers, {
    Color? cardColor,
    Color? textColor,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.only(top: 15, right: 15, left: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    topic,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 16),
                  ),
                  SizedBox(width: 10),
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color:
                          status == 'Active'
                              ? Color(0xffb6f7ce).withAlpha(80)
                              : status == 'Pending'
                              ? Color(0xffbcd8ff).withAlpha(100)
                              : Color(0xfff5c2c2).withAlpha(150),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color:
                            status == 'Active'
                                ? Color(0xff0CC740)
                                : status == 'Pending'
                                ? Color(0xff2C62EE)
                                : Color(0xffF93333),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Image.asset('assets/kms/institution.png'),
                        ),
                        WidgetSpan(child: SizedBox(width: 10)),
                        TextSpan(
                          text: schoolName,
                          style: TextStyle(
                            color: Color(0xff999999),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 20),
                  Text.rich(
                    TextSpan(
                      children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Image.asset('assets/kms/grade.png'),
                        ),
                        WidgetSpan(child: SizedBox(width: 10)),
                        TextSpan(
                          text: grade,
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
              SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Image.asset('assets/kms/due.png'),
                    ),
                    WidgetSpan(child: SizedBox(width: 10)),
                    TextSpan(
                      text: dueDate,
                      style: TextStyle(
                        color: Color(0xff999999),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Submission Progress',
                    style: TextStyle(
                      color: Color(0xff999999),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${completionPercentage}%',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 6),

              Builder(
                builder: (context) {
                  final completed = completedPercentage;
                  final pending = pendingPercentage;
                  final total = completed + pending;
                  final double completedRatio =
                      total == 0 ? 0.0 : completed / total;
                  final int completedFlex = (completedRatio * 1000).round();
                  final int pendingFlex = (1000 - completedFlex).round();
                  return ClipRRect(
                    borderRadius: BorderRadiusGeometry.circular(10),
                    child: Container(
                      width: double.infinity,
                      height: 20,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: AppStyle.primaryColor,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: completedFlex,
                            child: Container(color: AppStyle.primaryColor),
                          ),

                          Expanded(
                            flex: pendingFlex,
                            child: Container(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    submittedNumber,
                    style: TextStyle(
                      color: Color(0xff999999),
                      fontFamily: 'InterThin',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    pendingNumber,
                    style: TextStyle(
                      color: Color(0xff999999),
                      fontFamily: 'InterThin',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                children: [
                  card(
                    'Total',
                    numbers,
                    cardColor: Colors.grey.shade100,
                    textColor: Color(0xff6A6A6A),
                  ),
                  card(
                    'On\nTime',
                    numbers,
                    textColor: Color(0xff0CC740),
                    cardColor: Color(0xffb6f7ce).withAlpha(80),
                  ),
                  card(
                    'Late',
                    numbers,
                    textColor: Color(0xffFB923C),
                    cardColor: Color(0xfffde4b8).withAlpha(200),
                  ),
                  card(
                    'Pending',
                    numbers,
                    textColor: Color(0xff2C62EE),
                    cardColor: Color(0xffbcd8ff).withAlpha(100),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget card(
    String heading,
    String numbers, {
    Color? cardColor,
    Color? textColor,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: 7, bottom: 8),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: EdgeInsets.only(right: 5, left: 5, top: 5, bottom: 5),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(15),
          ),
          child: FittedBox(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(heading, style: TextStyle(color: textColor, fontSize: 17)),
                SizedBox(height: 10),
                Text(
                  numbers,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
