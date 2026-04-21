import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/constant/api_constants.dart';
import 'package:innovator/Innovator/constant/app_colors.dart';
import 'package:innovator/Innovator/screens/show_Specific_Profile/Show_Specific_Profile.dart';

class reeactionsheet extends StatefulWidget {
  final String postId;
  const reeactionsheet({required this.postId});

  @override
  State<reeactionsheet> createState() => _reeactionsheetState();
}

class _reeactionsheetState extends State<reeactionsheet> {
  List<Map<String, dynamic>> _reactions = [];
  String _activeTab = 'all';
  bool _isLoading = true;

  final Map<String, String> _emojiMap = {
    'like': '👍',
    'love': '❤️',
    'haha': '😂',
    'wow': '😮',
    'sad': '😢',
    'angry': '😡',
    'celebrate': '🎉',
    'dislike': '👎',
  };

  @override
  void initState() {
    super.initState();
    _fetchReactions();
  }

  Future<void> _fetchReactions() async {
    try {
      final token = AppData().accessToken ?? '';
      final res = await http.get(
        Uri.parse(
          '${ApiConstants.fetchreactions}${widget.postId}/reactions-list/',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (res.statusCode == 200) {
        final list = json.decode(res.body) as List;
        if (mounted)
          setState(() {
            _reactions = list.cast<Map<String, dynamic>>();
            _isLoading = false;
          });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered =>
      _activeTab == 'all'
          ? _reactions
          : _reactions.where((r) => r['type'] == _activeTab).toList();

  Map<String, int> get _counts {
    final m = <String, int>{};
    for (final r in _reactions) {
      final t = r['type'] as String? ?? 'like';
      m[t] = (m[t] ?? 0) + 1;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final counts = _counts;
    final tabs = ['all', ...counts.keys.toList()];

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: AppColors.whitecolor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Reactions',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          // Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children:
                  tabs.map((tab) {
                    final isActive = _activeTab == tab;
                    final count =
                        tab == 'all' ? _reactions.length : (counts[tab] ?? 0);
                    return GestureDetector(
                      onTap: () => setState(() => _activeTab = tab),
                      child: Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color:
                                  isActive
                                      ? Colors.blue.shade700
                                      : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (tab != 'all')
                              Text(
                                _emojiMap[tab] ?? '👍',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.red,
                                ),
                              ),
                            if (tab != 'all') const SizedBox(width: 4),
                            Text(
                              tab == 'all' ? 'All' : '',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    isActive
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                color:
                                    isActive
                                        ? Colors.blue.shade700
                                        : Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFF48706),
                        strokeWidth: 2,
                      ),
                    )
                    : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final r = _filtered[i];
                        final name =
                            r['full_name']?.toString() ?? r['username'] ?? '';
                        final username = r['username']?.toString() ?? '';
                        final avatar = r['avatar']?.toString() ?? '';
                        final type = r['type']?.toString() ?? 'like';
                        final initial =
                            name.isNotEmpty ? name[0].toUpperCase() : '?';
                        final avatarUrl =
                            avatar.isNotEmpty
                                ? (avatar.startsWith('http')
                                    ? avatar
                                    : '${ApiConstants.userBase}$avatar')
                                : null;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 4,
                          ),
                          leading: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => SpecificUserProfilePage(
                                            userId: r['user']?.toString() ?? '',
                                          ),
                                    ),
                                  );
                                },
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage:
                                      avatarUrl != null
                                          ? NetworkImage(avatarUrl)
                                          : null,
                                  child:
                                      avatarUrl == null
                                          ? Text(
                                            initial,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                          : null,
                                ),
                              ),
                              Positioned(
                                bottom: -3,
                                right: -3,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.whitecolor,
                                    border: Border.all(
                                      color: AppColors.whitecolor,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _emojiMap[type] ?? '👍',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            '@$username',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          // trailing:
                          //     r['user']?.toString() == AppData().currentUserId
                          //         ? null
                          //         : OutlinedButton(
                          //           onPressed: () {},
                          //           style: OutlinedButton.styleFrom(
                          //             side: BorderSide(
                          //               color: Colors.blue.shade700,
                          //             ),
                          //             shape: RoundedRectangleBorder(
                          //               borderRadius: BorderRadius.circular(20),
                          //             ),
                          //             padding: const EdgeInsets.symmetric(
                          //               horizontal: 14,
                          //               vertical: 6,
                          //             ),
                          //             minimumSize: Size.zero,
                          //           ),
                          //           child: Text(
                          //             '+ Follow',
                          //             style: TextStyle(
                          //               fontSize: 13,
                          //               color: Colors.blue.shade700,
                          //             ),
                          //           ),
                          //         ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
