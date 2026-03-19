import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/controllers/user_controller.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:innovator/Innovator/screens/show_Specific_Profile/Show_Specific_Profile.dart';

class FollowersFollowingScreen extends StatefulWidget {
  final String userId;

  const FollowersFollowingScreen({Key? key, required this.userId})
    : super(key: key);

  @override
  _FollowersFollowingScreenState createState() =>
      _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final appData = AppData();
  final userController = Get.find<UserController>();

  List<Map<String, dynamic>> followers = [];
  List<Map<String, dynamic>> following = [];

  bool isLoadingFollowers = false;
  bool isLoadingFollowing = false;
  String? errorFollowers;
  String? errorFollowing;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchFollowers();
    _fetchFollowing();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchFollowers() async {
    setState(() {
      isLoadingFollowers = true;
      errorFollowers = null;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'http://182.93.94.210:3067/api/v1/followers/${widget.userId}?page=0',
        ),
        headers: {
          'authorization': 'Bearer ${appData.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      debugPrint(' Followers API Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 200 && data['data'] != null) {
          // Parse as List of Maps - preserving ALL fields including _id
          final List<dynamic> rawData = data['data'] as List<dynamic>;
          final fetchedFollowers =
              rawData.map((item) {
                return Map<String, dynamic>.from(item as Map);
              }).toList();

          // Debug first follower
          if (fetchedFollowers.isNotEmpty) {
            debugPrint('First follower: ${fetchedFollowers[0]}');
            debugPrint('Has _id: ${fetchedFollowers[0].containsKey('_id')}');
          }

          // Cache users
          if (Get.isRegistered<UserController>()) {
            Get.find<UserController>().bulkCacheUsers(fetchedFollowers);
          }

          setState(() {
            followers = fetchedFollowers;
            isLoadingFollowers = false;
          });

          debugPrint('Loaded ${fetchedFollowers.length} followers');
        } else {
          setState(() {
            errorFollowers = data['message'] ?? 'Failed to load followers';
            isLoadingFollowers = false;
          });
        }
      } else {
        setState(() {
          errorFollowers = 'Server error: ${response.statusCode}';
          isLoadingFollowers = false;
        });
      }
    } catch (e) {
      debugPrint(' Error fetching followers: $e');
      setState(() {
        errorFollowers = 'Network error: $e';
        isLoadingFollowers = false;
      });
    }
  }

  Future<void> _fetchFollowing() async {
    setState(() {
      isLoadingFollowing = true;
      errorFollowing = null;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'http://182.93.94.210:3067/api/v1/following/${widget.userId}?page=0',
        ),
        headers: {
          'authorization': 'Bearer ${appData.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      debugPrint(' Following API Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 200 && data['data'] != null) {
          // Parse as List of Maps - preserving ALL fields including _id
          final List<dynamic> rawData = data['data'] as List<dynamic>;
          final fetchedFollowing =
              rawData.map((item) {
                return Map<String, dynamic>.from(item as Map);
              }).toList();

          // Debug first following
          if (fetchedFollowing.isNotEmpty) {
            debugPrint('First following: ${fetchedFollowing[0]}');
            debugPrint('Has _id: ${fetchedFollowing[0].containsKey('_id')}');
          }

          // Cache users
          if (Get.isRegistered<UserController>()) {
            Get.find<UserController>().bulkCacheUsers(fetchedFollowing);
          }

          setState(() {
            following = fetchedFollowing;
            isLoadingFollowing = false;
          });

          debugPrint('Loaded ${fetchedFollowing.length} following');
        } else {
          setState(() {
            errorFollowing = data['message'] ?? 'Failed to load following';
            isLoadingFollowing = false;
          });
        }
      } else {
        setState(() {
          errorFollowing = 'Server error: ${response.statusCode}';
          isLoadingFollowing = false;
        });
      }
    } catch (e) {
      debugPrint(' Error fetching following: $e');
      setState(() {
        errorFollowing = 'Network error: $e';
        isLoadingFollowing = false;
      });
    }
  }

  void _navigateToProfile(Map<String, dynamic> user) {
    debugPrint(' Navigating to profile');
    debugPrint(' User data: $user');
    debugPrint(' Available keys: ${user.keys.toList()}');

    // Check if current user
    final isCurrentUser = appData.isCurrentUserByEmail(user['email'] ?? '');

    if (isCurrentUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This is your profile'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    // Extract user ID with multiple fallbacks
    String? userId;

    if (user['_id'] != null && user['_id'].toString().trim().isNotEmpty) {
      userId = user['_id'].toString().trim();
      debugPrint('Found _id: $userId');
    } else if (user['id'] != null && user['id'].toString().trim().isNotEmpty) {
      userId = user['id'].toString().trim();
      debugPrint('Found id: $userId');
    } else if (user['userId'] != null &&
        user['userId'].toString().trim().isNotEmpty) {
      userId = user['userId'].toString().trim();
      debugPrint('Found userId: $userId');
    }

    // Validate userId
    if (userId == null || userId.isEmpty || userId == 'null') {
      debugPrint(' No valid user ID found');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot open profile: User ID not found'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Validate ObjectId format (24 hex characters)
    final isValidObjectId = RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(userId);
    if (!isValidObjectId) {
      debugPrint(' Warning: Invalid ObjectId format: $userId');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid user ID format'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    debugPrint('🚀 Navigating with userId: $userId');

    try {
      Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SpecificUserProfilePage(userId: userId!),
            ),
          )
          .then((value) {
            debugPrint('🔙 Returned from profile page');
          })
          .catchError((error) {
            debugPrint(' Navigation error: $error');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error opening profile'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          });
    } catch (error) {
      debugPrint(' Exception: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening profile'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildUserProfilePicture(Map<String, dynamic> user) {
    final userId = user['_id'] ?? user['id'] ?? user['userId'] ?? '';
    final pictureUrl = user['picture'];
    final name = user['name'] ?? 'U';

    // Build the full image URL
    String? fullImageUrl;
    if (pictureUrl != null && pictureUrl.toString().isNotEmpty) {
      final picStr = pictureUrl.toString();
      fullImageUrl =
          picStr.startsWith('http')
              ? picStr
              : 'http://182.93.94.210:3067${picStr.startsWith('/') ? picStr : '/$picStr'}';
    }

    return GetBuilder<UserController>(
      builder: (controller) {
        // Try to get cached URL first
        final cachedUrl = controller.getOtherUserFullProfilePicturePath(
          userId.toString(),
        );
        final imageUrl = cachedUrl ?? fullImageUrl;

        return CircleAvatar(
          radius: 25,
          backgroundColor: Colors.grey[300],
          child:
              imageUrl != null && imageUrl.isNotEmpty
                  ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      placeholder:
                          (context, url) => Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey[200],
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.grey[400]!,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      errorWidget:
                          (context, url, error) => Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey[400],
                            child: Center(
                              child: Text(
                                name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      memCacheWidth: 100,
                      memCacheHeight: 100,
                    ),
                  )
                  : Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
        );
      },
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final isCurrentUser = appData.isCurrentUserByEmail(user['email'] ?? '');

    // Debug the user data structure
    debugPrint('🔧 Building tile for user: ${user['name']}');
    debugPrint('🔧 User has _id: ${user.containsKey('_id')}');
    debugPrint('🔧 _id value: ${user['_id']}');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]?.withAlpha(30)
                : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap:
            isCurrentUser
                ? null
                : () {
                  // Pass the ENTIRE user object to _navigateToProfile
                  _navigateToProfile(user);
                },
        leading: _buildUserProfilePicture(user),
        title: Text(
          user['name'] ?? 'Unknown User',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        trailing:
            isCurrentUser
                ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'You',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
                : const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
      ),
    );
  }

  Widget _buildFollowersList() {
    if (isLoadingFollowers) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (errorFollowers != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                errorFollowers!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchFollowers,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (followers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No followers yet',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchFollowers,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: followers.length,
        itemBuilder: (context, index) {
          return _buildUserTile(followers[index]);
        },
      ),
    );
  }

  Widget _buildFollowingList() {
    if (isLoadingFollowing) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (errorFollowing != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                errorFollowing!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchFollowing,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (following.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_add_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Not following anyone yet',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchFollowing,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: following.length,
        itemBuilder: (context, index) {
          return _buildUserTile(following[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF0A0A0A)
              : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Connections'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color.fromRGBO(244, 135, 6, 1),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color.fromRGBO(244, 135, 6, 1),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 18),
                  const SizedBox(width: 8),
                  Text('Followers (${followers.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_add_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text('Following (${following.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildFollowersList(), _buildFollowingList()],
      ),
    );
  }
}

// Dialog function to show followers/following
void showFollowersFollowingDialog(BuildContext context, String userId) {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1A1A1A)
                    : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: FollowersFollowingContent(userId: userId),
        ),
      );
    },
  );
}

// Separate widget for dialog content
class FollowersFollowingContent extends StatefulWidget {
  final String userId;

  const FollowersFollowingContent({Key? key, required this.userId})
    : super(key: key);

  @override
  _FollowersFollowingContentState createState() =>
      _FollowersFollowingContentState();
}

class _FollowersFollowingContentState extends State<FollowersFollowingContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final appData = AppData();

  List<Map<String, dynamic>> followers = [];
  List<Map<String, dynamic>> following = [];

  bool isLoadingFollowers = false;
  bool isLoadingFollowing = false;
  String? errorFollowers;
  String? errorFollowing;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchFollowers();
    _fetchFollowing();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchFollowers() async {
    setState(() {
      isLoadingFollowers = true;
      errorFollowers = null;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'http://182.93.94.210:3067/api/v1/followers/${widget.userId}',
        ),
        headers: {
          'authorization': 'Bearer ${appData.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 200) {
        setState(() {
          followers = List<Map<String, dynamic>>.from(data['data']);
          isLoadingFollowers = false;
        });
      } else {
        setState(() {
          errorFollowers = data['message'] ?? 'Failed to load followers';
          isLoadingFollowers = false;
        });
      }
    } catch (e) {
      setState(() {
        errorFollowers = 'Network error: $e';
        isLoadingFollowers = false;
      });
    }
  }

  Future<void> _fetchFollowing() async {
    setState(() {
      isLoadingFollowing = true;
      errorFollowing = null;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'http://182.93.94.210:3067/api/v1/following/${widget.userId}',
        ),
        headers: {
          'authorization': 'Bearer ${appData.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 200) {
        setState(() {
          following = List<Map<String, dynamic>>.from(data['data']);
          isLoadingFollowing = false;
        });
      } else {
        setState(() {
          errorFollowing = data['message'] ?? 'Failed to load following';
          isLoadingFollowing = false;
        });
      }
    } catch (e) {
      setState(() {
        errorFollowing = 'Network error: $e';
        isLoadingFollowing = false;
      });
    }
  }

  void _navigateToProfile(Map<String, dynamic> user) {
    // Check if this is the current user
    final isCurrentUser = appData.isCurrentUserByEmail(user['email'] ?? '');

    if (isCurrentUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This is your profile'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    // Debug: Print user data to understand the structure
    debugPrint(' Navigating to profile with user data: $user');
    debugPrint(' Available keys: ${user.keys.toList()}');

    // Try different possible ID fields based on your API response
    String? userId;

    // Priority order for finding user ID
    if (user['_id'] != null && user['_id'].toString().trim().isNotEmpty) {
      userId = user['_id'].toString().trim();
      debugPrint('Found userId from _id: $userId');
    } else if (user['id'] != null && user['id'].toString().trim().isNotEmpty) {
      userId = user['id'].toString().trim();
      debugPrint('Found userId from id: $userId');
    } else if (user['userId'] != null &&
        user['userId'].toString().trim().isNotEmpty) {
      userId = user['userId'].toString().trim();
      debugPrint('Found userId from userId: $userId');
    } else if (user['user_id'] != null &&
        user['user_id'].toString().trim().isNotEmpty) {
      userId = user['user_id'].toString().trim();
      debugPrint('Found userId from user_id: $userId');
    }

    // Validate userId before navigation
    if (userId == null || userId.isEmpty || userId == 'null') {
      debugPrint(' No valid user ID found in user data');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot open profile: User ID not found'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Additional validation: Check if userId looks like a valid MongoDB ObjectId (24 hex characters)
    final isValidObjectId = RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(userId);
    if (!isValidObjectId) {
      debugPrint(
        ' Warning: userId "$userId" does not look like a valid ObjectId',
      );
    }

    debugPrint('🚀 Navigating to SpecificUserProfilePage with userId: $userId');

    try {
      // Close the dialog first (if in dialog version)
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Navigate to profile
      Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SpecificUserProfilePage(userId: userId!),
            ),
          )
          .then((value) {
            // Optional: Handle any return value or refresh data
            debugPrint('🔙 Returned from SpecificUserProfilePage');
          })
          .catchError((error) {
            debugPrint(' Navigation error: $error');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error opening profile: $error'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          });
    } catch (error) {
      debugPrint(' Exception during navigation: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening profile: $error'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final isCurrentUser = appData.isCurrentUserByEmail(user['email'] ?? '');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]?.withAlpha(30)
                : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: isCurrentUser ? null : () => _navigateToProfile(user),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.grey[300],
          backgroundImage:
              user['picture'] != null && user['picture'].toString().isNotEmpty
                  ? NetworkImage(
                    user['picture'].toString().startsWith('http://') ||
                            user['picture'].toString().startsWith('https://')
                        ? user['picture']
                        : 'http://182.93.94.210:3067${user['picture']}',
                  )
                  : null,
          child:
              user['picture'] == null || user['picture'].toString().isEmpty
                  ? Text(
                    (user['name'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  )
                  : null,
        ),
        title: Text(
          user['name'] ?? 'Unknown User',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        // subtitle: Text(
        //   user['email'] ?? '',
        //   style: TextStyle(
        //     color: Colors.grey[600],
        //     fontSize: 13,
        //   ),
        // ),
        trailing:
            isCurrentUser
                ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'You',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                )
                : const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey,
                ),
      ),
    );
  }

  Widget _buildFollowersList() {
    if (isLoadingFollowers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorFollowers != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 32, color: Colors.red),
            const SizedBox(height: 8),
            Text(
              errorFollowers!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (followers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 32, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No followers yet',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: followers.length,
      itemBuilder: (context, index) {
        return _buildUserTile(followers[index]);
      },
    );
  }

  Widget _buildFollowingList() {
    if (isLoadingFollowing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorFollowing != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 32, color: Colors.red),
            const SizedBox(height: 8),
            Text(
              errorFollowing!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (following.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add_outlined, size: 32, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'Not following anyone yet',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: following.length,
      itemBuilder: (context, index) {
        return _buildUserTile(following[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Row(
          children: [
            const Expanded(
              child: Text(
                'Connections',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Tab Bar
        TabBar(
          controller: _tabController,
          labelColor: const Color.fromRGBO(244, 135, 6, 1),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color.fromRGBO(244, 135, 6, 1),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 16),
                  const SizedBox(width: 2),
                  Text('Followers (${followers.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_add_outlined, size: 16),
                  const SizedBox(width: 2),
                  Text('Following (${following.length})'),
                ],
              ),
            ),
          ],
        ),

        // Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildFollowersList(), _buildFollowingList()],
          ),
        ),
      ],
    );
  }
}
