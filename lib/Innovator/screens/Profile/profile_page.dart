import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/Authorization/Login.dart';
import 'package:innovator/Innovator/models/Feed_Content_Model.dart';
import 'package:innovator/Innovator/screens/CreatePost/createpost.dart';
import 'package:innovator/Innovator/screens/Feed/Inner_Homepage.dart';
import 'package:innovator/Innovator/screens/Feed/Video_Feed.dart'
    show VideoFeedPage;
import 'package:innovator/Innovator/screens/Follow/follow_Button.dart';
import 'package:innovator/Innovator/screens/Follow/follow-Service.dart';
import 'package:innovator/Innovator/screens/Profile/Edit_Profile.dart';
import 'package:innovator/Innovator/screens/SHow_Specific_Profile/Show_Specific_Profile.dart';
import 'package:innovator/Innovator/screens/Settings/settings.dart';
import 'package:innovator/Innovator/widget/FloatingMenuwidget.dart';
import 'package:lottie/lottie.dart';
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';
import 'package:get/get.dart';
import 'package:innovator/Innovator/controllers/user_controller.dart';

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String phone;
  final DateTime dob;
  final String role;
  final String level;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? picture;
  final String? gender;
  final String? location;
  final String? bio;
  final String? education;
  final String? profession;
  final String? achievements;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.dob,
    required this.role,
    required this.level,
    required this.createdAt,
    required this.updatedAt,
    this.picture,
    this.gender,
    this.location,
    this.bio,
    this.education,
    this.profession,
    this.achievements,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      dob: json['dob'] != null ? DateTime.parse(json['dob']) : DateTime.now(),
      role: json['role'] ?? '',
      level: json['level'] ?? '',
      createdAt:
          json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : DateTime.now(),
      updatedAt:
          json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt'])
              : DateTime.now(),
      picture: json['picture'],
      gender: json['gender'],
      location: json['location'],
      bio: json['bio'],
      education: json['education'],
      profession: json['profession'],
      achievements: json['achievements'],
    );
  }
}

class FollowerFollowing {
  final String id;
  final String name;
  final String email;
  final String? picture;

  FollowerFollowing({
    required this.id,
    required this.name,
    required this.email,
    this.picture,
  });

  factory FollowerFollowing.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('follower')) {
      final follower = json['follower'];
      return FollowerFollowing(
        id: follower['_id'] ?? '',
        name: follower['name'] ?? '',
        email: follower['email'] ?? '',
        picture: follower['picture'],
      );
    } else if (json.containsKey('following')) {
      final following = json['following'];
      return FollowerFollowing(
        id: following['_id'] ?? '',
        name: following['name'] ?? '',
        email: following['email'] ?? '',
        picture: following['picture'],
      );
    } else {
      return FollowerFollowing(
        id: json['_id'] ?? '',
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        picture: json['picture'],
      );
    }
  }
}

class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() {
    return 'AuthException: $message';
  }
}

class UserProfileService {
  static const String baseUrl = 'http://182.93.94.210:3067/api/v1';

  static Future<UserProfile> getUserProfile() async {
    try {
      final token = AppData().accessToken;
      if (token == null || token.isEmpty) {
        throw AuthException('No authentication token found');
      }

      final url = Uri.parse('$baseUrl/user-profile');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final profile =
            data['data'] != null
                ? UserProfile.fromJson(data['data'])
                : UserProfile.fromJson(data);
        return profile;
      } else if (response.statusCode == 401) {
        await AppData().clearAuthToken();
        throw AuthException('Authentication token expired or invalid');
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<FollowerFollowing>> getFollowers() async {
    final token = AppData().accessToken;
    if (token == null || token.isEmpty) {
      throw AuthException('No authentication token found');
    }

    final url = Uri.parse('$baseUrl/list-followers');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'authorization': 'Bearer $token',
        },
      );

      log('Followers API response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data'] is List) {
          return (data['data'] as List)
              .map((item) => FollowerFollowing.fromJson(item))
              .toList();
        }
        return [];
      } else if (response.statusCode == 401) {
        await AppData().clearAuthToken();
        throw AuthException('Authentication token expired or invalid');
      } else {
        throw Exception('Failed to load followers: ${response.statusCode}');
      }
    } catch (e) {
      log('Error fetching followers: $e');
      if (e is AuthException) {
        rethrow;
      }
      throw Exception('Network error: $e');
    }
  }

  static Future<List<FollowerFollowing>> getFollowing() async {
    final token = AppData().accessToken;
    if (token == null || token.isEmpty) {
      throw AuthException('No authentication token found');
    }

    final url = Uri.parse('$baseUrl/list-followings');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'authorization': 'Bearer $token',
        },
      );

      log('Following API response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data'] is List) {
          return (data['data'] as List)
              .map((item) => FollowerFollowing.fromJson(item))
              .toList();
        }
        return [];
      } else if (response.statusCode == 401) {
        await AppData().clearAuthToken();
        throw AuthException('Authentication token expired or invalid');
      } else {
        throw Exception('Failed to load following: ${response.statusCode}');
      }
    } catch (e) {
      log('Error fetching following: $e');
      if (e is AuthException) {
        rethrow;
      }
      throw Exception('Network error: $e');
    }
  }

  static Future<String> uploadProfilePicture(File imageFile) async {
    final token = AppData().accessToken;

    if (token == null || token.isEmpty) {
      throw AuthException('No authentication token found');
    }

    final filename = path.basename(imageFile.path);
    final url = Uri.parse('http://182.93.94.220:8005/api/users/me/avatar');

    try {
      var request = http.MultipartRequest('POST', url);
      request.headers['authorization'] = 'Bearer $token';

      var fileStream = http.ByteStream(imageFile.openRead());
      var fileLength = await imageFile.length();

      String mimeType = 'image/jpeg';
      if (filename.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (filename.endsWith('.jpg') || filename.endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      }

      var multipartFile = http.MultipartFile(
        'avatar',
        fileStream,
        fileLength,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      );

      request.files.add(multipartFile);

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      log('Avatar upload response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        // Updated to handle new API response format
        if (data['success'] == true && data['data'] != null) {
          return data['data']['avatar'] ?? data['data']['picture'] ?? '';
        } else if (data['data'] != null) {
          return data['data']['avatar'] ?? data['data']['picture'] ?? '';
        } else {
          throw Exception('Failed to get avatar URL from response');
        }
      } else {
        throw Exception('Failed to upload avatar: ${response.statusCode}');
      }
    } catch (e) {
      log('Error uploading avatar: $e');
      throw Exception('Avatar upload failed: $e');
    }
  }
}

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  final AppData _appData = AppData();
  static const _loadTriggerThreshold = 500.0;
  late Future<UserProfile> _profileFuture;
  bool _isUploading = false;
  String? _errorMessage;
  late TabController _tabController;
  int _currentPageFollowers = 1;
  int _currentPageFollowing = 1;
  final int _itemsPerPage = 10;
  final UserController _userController = Get.put(UserController());
  bool _isLoadingFromCache = false;
  final List<FeedContent> _contents = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String? _lastId;
  bool _hasError = false;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfile();
    _initializeFeed();
    _scrollController.addListener(_scrollListener);
  }

  void _initializeFeed() {
    _loadMoreContent();
  }

  void _scrollListener() {
    if (!_isLoading &&
        _hasMoreData &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent -
                _loadTriggerThreshold) {
      _loadMoreContent();
    }
  }

  Future<void> _loadMoreContent() async {
    if (_isLoading || !_hasMoreData) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final String? authToken = _appData.accessToken;
      if (authToken == null || authToken.isEmpty) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Authentication required. Please login.';
        });
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LoginPage()),
          (route) => false,
        );
        return;
      }

      final url =
          _lastId == null
              ? 'http://182.93.94.210:3067/api/v1/getUserContent/${widget.userId}?page=0'
              : 'http://182.93.94.210:3067/api/v1/getUserContent/${widget.userId}?page=${(_contents.length / 10).ceil()}';

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'authorization': 'Bearer $authToken',
            },
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 200 && data['data'] != null) {
          final List<dynamic> contentList = data['data']['contents'] ?? [];
          final List<FeedContent> newContents =
              contentList.map((item) => FeedContent.fromJson(item)).toList();
          final pagination = data['data']['pagination'];

          setState(() {
            _contents.addAll(newContents);
            _lastId = newContents.isNotEmpty ? newContents.last.id : _lastId;
            _hasMoreData = pagination['hasMore'] ?? false;
          });
        } else {
          setState(() {
            _hasError = true;
            _errorMessage = 'Invalid response from server.';
          });
        }
      } else if (response.statusCode == 401) {
        await _handleUnauthorizedError();
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleUnauthorizedError() async {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
      (route) => false,
    );
  }

  Future<void> _refreshFeed() async {
    setState(() {
      _contents.clear();
      _lastId = null;
      _hasError = false;
      _hasMoreData = true;
    });
    await _loadMoreContent();
  }

  void _loadProfile() {
    _profileFuture = UserProfileService.getUserProfile();
  }

  String formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() {
        _isUploading = true;
        _errorMessage = null;
      });

      // Clear existing image cache before upload
      final oldImagePath = _userController.getFullProfilePicturePath();
      if (oldImagePath != null) {
        imageCache.evict(NetworkImage(oldImagePath));
        // Also clear with version parameter
        imageCache.evict(
          NetworkImage(
            '$oldImagePath?v=${_userController.profilePictureVersion.value}',
          ),
        );
      }

      final File imageFile = File(image.path);
      final String newPicturePath =
          await UserProfileService.uploadProfilePicture(imageFile);

      // Update controller with new path and increment version
      _userController.updateProfilePicture(newPicturePath);
      await AppData().updateProfilePicture(newPicturePath);

      // Force image cache clear for new image as well
      imageCache.evict(NetworkImage(newPicturePath));

      // Increment version to force UI rebuild
      _userController.profilePictureVersion.value++;

      setState(() {
        _isUploading = false;
      });

      // Remove _loadProfile() call since controller is already updated
      // _loadProfile();
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errorMessage = 'Failed to upload image: $e';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
    }
  }

  void _showFollowersFollowingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: EdgeInsets.all(16),
          child: Container(
            padding: EdgeInsets.all(16),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                          const SizedBox(width: 4),
                          Text('Followers'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_add_outlined, size: 16),
                          const SizedBox(width: 4),
                          Text('Following '),
                        ],
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildFollowersList(), _buildFollowingList()],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _refreshFollowers() {
    setState(() {
      _currentPageFollowers = 1;
    });
  }

  void _refreshFollowing() {
    setState(() {
      _currentPageFollowing = 1;
    });
  }

  Widget _buildFollowingList() {
    return FutureBuilder<List<FollowerFollowing>>(
      future: UserProfileService.getFollowing(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Text('Error loading following: ${snapshot.error}'),
          );
        } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final following = snapshot.data!;
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: following.length,
                  itemBuilder: (context, index) {
                    final follow = following[index];
                    return FutureBuilder<bool>(
                      future: FollowService.checkFollowStatus(follow.email),
                      builder: (context, followSnapshot) {
                        if (followSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return ListTile(
                            leading: CircularProgressIndicator(),
                            title: Text(follow.name),
                            subtitle: Text(follow.email),
                          );
                        } else if (followSnapshot.hasError) {
                          return ListTile(
                            title: Text(follow.name),
                            subtitle: Text('Error checking follow status'),
                          );
                        }
                        final isFollowing = followSnapshot.data ?? true;
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: Color.fromRGBO(235, 111, 70, 0.2),
                            // backgroundImage:
                            //     follow.picture != null
                            //         ? NetworkImage(
                            //           'http://182.93.94.210:3067${follow.picture}',
                            //         )
                            //         : null,
                            backgroundImage:
                                follow.picture.toString().isNotEmpty
                                    ? NetworkImage(
                                      follow.picture
                                                  .toString()
                                                  .toString()
                                                  .startsWith('http://') ||
                                              follow.picture
                                                  .toString()
                                                  .toString()
                                                  .startsWith('https://')
                                          ? follow.picture.toString()
                                          : 'http://182.93.94.210:3067${follow.picture}',
                                    )
                                    : null,
                            child:
                                follow.picture == null
                                    ? Icon(
                                      Icons.person,
                                      color: Color.fromRGBO(244, 135, 6, 1),
                                    )
                                    : null,
                          ),
                          title: GestureDetector(
                            child: Text(follow.name),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => SpecificUserProfilePage(
                                        userId: follow.id,
                                      ),
                                ),
                              );
                            },
                          ),
                          subtitle: Text(follow.email),
                          trailing: FollowButton(
                            targetUserEmail: follow.email,
                            initialFollowStatus: isFollowing,
                            onFollowSuccess: _refreshFollowing,
                            onUnfollowSuccess: _refreshFollowing,
                            size: 36,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        } else {
          return Center(child: Text('Not following anyone yet'));
        }
      },
    );
  }

  Widget _buildFollowersList() {
    return FutureBuilder<List<FollowerFollowing>>(
      future: UserProfileService.getFollowers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Text('Error loading followers: ${snapshot.error}'),
          );
        } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final followers = snapshot.data!;
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: followers.length,
                  itemBuilder: (context, index) {
                    final follower = followers[index];
                    return FutureBuilder<bool>(
                      future: FollowService.checkFollowStatus(follower.email),
                      builder: (context, followSnapshot) {
                        if (followSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return ListTile(
                            leading: CircularProgressIndicator(),
                            title: Text(follower.name),
                            subtitle: Text(follower.email),
                          );
                        } else if (followSnapshot.hasError) {
                          return ListTile(
                            title: Text(follower.name),
                            subtitle: Text('Error checking follow status'),
                          );
                        }
                        final isFollowing = followSnapshot.data ?? false;
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: Color.fromRGBO(235, 111, 70, 0.2),

                            // backgroundImage:
                            //     follower.picture != null
                            //         ? NetworkImage(
                            //           'http://182.93.94.210:3067${follower.picture}',
                            //         )
                            //         : NetworkImage(''),
                            backgroundImage:
                                follower.picture
                                        .toString()
                                        .toString()
                                        .isNotEmpty
                                    ? NetworkImage(
                                      follower.picture
                                                  .toString()
                                                  .toString()
                                                  .startsWith('http://') ||
                                              follower.picture
                                                  .toString()
                                                  .toString()
                                                  .startsWith('https://')
                                          ? follower.picture.toString()
                                          : 'http://182.93.94.210:3067${follower.picture.toString()}',
                                    )
                                    : null,
                            child:
                                follower.picture == null
                                    ? Icon(
                                      Icons.person,
                                      color: Color.fromRGBO(244, 135, 6, 1),
                                    )
                                    : null,
                          ),
                          title: GestureDetector(
                            child: Text(follower.name),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => SpecificUserProfilePage(
                                        userId: follower.id,
                                      ),
                                ),
                              );
                            },
                          ),
                          subtitle: Text(follower.email),
                          trailing: FollowButton(
                            targetUserEmail: follower.email,
                            initialFollowStatus: isFollowing,
                            onFollowSuccess: _refreshFollowers,
                            onUnfollowSuccess: _refreshFollowers,
                            size: 36,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        } else {
          return Center(child: Text('No followers found'));
        }
      },
    );
  }

  Widget _buildProfileSection(UserProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(right: 10, left: 10),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    children: [
                      Obx(
                        () => CircleAvatar(
                          radius: 60,
                          backgroundColor: Color.fromRGBO(235, 111, 70, 0.2),
                          key: ValueKey(
                            'profile_${_userController.profilePictureVersion.value}',
                          ),
                          backgroundImage:
                              _userController.getFullProfilePicturePath() !=
                                      null
                                  ? NetworkImage(
                                    '${_userController.getFullProfilePicturePath()!}?v=${_userController.profilePictureVersion.value}',
                                  )
                                  : null,
                          child:
                              _userController.profilePicture.value == null ||
                                      _userController.profilePicture.value == ''
                                  ? Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Color.fromRGBO(244, 135, 6, 1),
                                  )
                                  : null,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _isUploading ? null : _pickAndUploadImage,
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(244, 135, 6, 1),
                              shape: BoxShape.circle,
                            ),
                            child:
                                _isUploading
                                    ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Obx(
                        () => Text(
                          _userController.userName.value ?? profile.name,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        profile.email,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(244, 135, 6, 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: EdgeInsets.only(top: 8),
                        child: Text(
                          '${profile.level.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color.fromRGBO(244, 135, 6, 1),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 12),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              // SizedBox(height: 10),
              Divider(thickness: 0.8, color: Colors.grey[300]),
              Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        FutureBuilder<List<FollowerFollowing>>(
                          future: UserProfileService.getFollowers(),
                          builder: (context, snapshot) {
                            int followerCount = 0;
                            if (snapshot.connectionState ==
                                    ConnectionState.done &&
                                snapshot.hasData) {
                              followerCount = snapshot.data!.length;
                            }
                            return GestureDetector(
                              onTap:
                                  () => _showFollowersFollowingDialog(context),
                              child: Column(
                                children: [
                                  Text(
                                    '$followerCount ',
                                    style: TextStyle(
                                      color: Color.fromRGBO(244, 135, 6, 1),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Followers',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        SizedBox(width: 40),
                        FutureBuilder<List<FollowerFollowing>>(
                          future: UserProfileService.getFollowing(),
                          builder: (context, snapshot) {
                            int followingCount = 0;
                            if (snapshot.connectionState ==
                                    ConnectionState.done &&
                                snapshot.hasData) {
                              followingCount = snapshot.data!.length;
                            }
                            return GestureDetector(
                              onTap: () {
                                _tabController.index = 1;
                                _showFollowersFollowingDialog(context);
                              },
                              child: Column(
                                children: [
                                  Text(
                                    '$followingCount',
                                    style: TextStyle(
                                      color: Color.fromRGBO(244, 135, 6, 1),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Following',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    Container(
                      height: 35,
                      width: 35,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.all(0),
                        onPressed: () {
                          showModalBottomSheet(
                            backgroundColor: Colors.white,
                            context: context,
                            builder: (context) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: Icon(Icons.info_outline),
                                    title: Text('My Information'),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      showAdaptiveDialog(
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            backgroundColor: Colors.white,

                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(height: 24),
                                                Padding(
                                                  padding: EdgeInsets.all(12),
                                                  child: Text(
                                                    'Personal Information',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(height: 8),
                                                ProfileInfoCard(
                                                  title: 'Email',
                                                  value: profile.email,
                                                  icon: Icons.email,
                                                ),
                                                ProfileInfoCard(
                                                  title: 'Phone',
                                                  value: profile.phone,
                                                  icon: Icons.phone,
                                                ),
                                                ProfileInfoCard(
                                                  title: 'Date of Birth',
                                                  value: formatDate(
                                                    profile.dob,
                                                  ),
                                                  icon: Icons.calendar_today,
                                                ),
                                                ProfileInfoCard(
                                                  title: 'Member Since',
                                                  value: formatDate(
                                                    profile.createdAt,
                                                  ),
                                                  icon: Icons.access_time,
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(
                                                    context,
                                                  ).pushReplacement(
                                                    MaterialPageRoute(
                                                      builder:
                                                          (_) =>
                                                              EditProfileScreen(),
                                                    ),
                                                  );
                                                },
                                                child: Text(
                                                  'Edit',
                                                  style: TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 14,
                                                    color: Colors.orange,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                                child: Text(
                                                  'Close',
                                                  style: TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 14,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  ),

                                  ListTile(
                                    leading: Icon(Icons.logout),
                                    title: Text('Logout'),
                                    onTap: () async {
                                      await AppData().clearAuthToken();
                                      Get.offAll(() => LoginPage());
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        icon: Icon(
                          Icons.more_vert_outlined,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create New Post',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 10),

            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CreatePostScreen()),
                );
              },
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),

                child: Center(
                  child: Text(
                    'Write Something...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black45,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.only(
            right: 10,
            left: 10,
            top: 2,
            bottom: 2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Posts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => VideoFeedPage()),
                  );
                },
                label: Text('Reels', style: TextStyle(color: Colors.black)),
                icon: Icon(
                  Icons.video_collection,
                  color: Color.fromRGBO(244, 135, 6, 1),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
            ],
          ),
        ),
        // SizedBox(height: 20),
        Divider(thickness: 0.8, color: Colors.grey[300]),
      ],
    );
  }

  Widget _buildContentItem(int index) {
    final content = _contents[index];
    return RepaintBoundary(
      key: ValueKey(content.id),
      child: FeedItem(
        content: content,
        onLikeToggled: (isLiked) {
          setState(() {
            content.isLiked = isLiked;
            content.likes += isLiked ? 1 : -1;
          });
        },
        onFollowToggled: (isFollowed) {
          setState(() {
            content.isFollowed = isFollowed;
          });
        },
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return _isLoading
        ? const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        )
        : const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,

        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: Text('My Profile'),
        backgroundColor: Color.fromRGBO(244, 135, 6, 1),
      ),
      body: Padding(
        padding: const EdgeInsets.only(right: 12, left: 12),
        child: CustomScrollView(
          controller: _scrollController,

          slivers: [
            SliverToBoxAdapter(
              child: FutureBuilder<UserProfile>(
                future: _profileFuture,
                builder: (context, snapshot) {
                  if (_isLoadingFromCache) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading Information'),
                        ],
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Error loading profile',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            // Lottie.asset(
                            //   'animation/No-Content.json',
                            //   fit: BoxFit.cover,
                            // ),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _loadProfile();
                                });
                              },
                              child: Text(
                                'Try Again',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color.fromRGBO(244, 135, 6, 1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else if (snapshot.hasData) {
                    final profile = snapshot.data!;
                    return _buildProfileSection(profile);
                  } else {
                    return Center(child: Text(''));
                  }
                },
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index == _contents.length) {
                  return _buildLoadingIndicator();
                }
                return _buildContentItem(index);
              }, childCount: _contents.length + (_hasMoreData ? 1 : 0)),
            ),
          ],
        ),
      ),
      //floatingActionButton: FloatingMenuWidget(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ProfileInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const ProfileInfoCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Colors.white,
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: Color.fromRGBO(244, 135, 6, 1)),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
