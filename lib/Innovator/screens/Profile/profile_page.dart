import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/Authorization/Login.dart';
import 'package:innovator/Innovator/constant/api_constants.dart';
import 'package:innovator/Innovator/constant/app_colors.dart';
import 'package:innovator/Innovator/models/Feed_Content_Model.dart';
import 'package:innovator/Innovator/screens/Feed/Inner_Homepage.dart';
import 'package:innovator/Innovator/screens/Feed/Video_Feed.dart';
import 'package:innovator/Innovator/screens/Follow/follow_Button.dart';
import 'package:innovator/Innovator/screens/Profile/Edit_Profile.dart';
import 'package:innovator/Innovator/screens/SHow_Specific_Profile/Show_Specific_Profile.dart';
import 'package:innovator/Innovator/screens/chatrrom/screen/chatlistscreen.dart';
import 'package:innovator/Innovator/utils/Drawer/custom_drawer.dart';
import 'package:innovator/Innovator/widget/Custom_refresh_Indicator.dart';
import 'package:innovator/Innovator/widget/CustomizeFAB.dart';
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';
import 'package:get/get.dart';
import 'package:innovator/Innovator/controllers/user_controller.dart';
 

class UserProfileData {
  final String id;
  final String username;
  final String fullName;
  final String email;
  final String role;
  final String? bio;
  final String? avatar;
  final List<String> interests;
  final int followersCount;
  final int followingCount;
  final List<String> followerUsernames;
  final List<String> followingUsernames;
  final DateTime createdAt;
  final List<FeedContent> posts;

  UserProfileData({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
    this.bio,
    this.avatar,
    required this.interests,
    required this.followersCount,
    required this.followingCount,
    required this.followerUsernames,
    required this.followingUsernames,
    required this.createdAt,
    this.posts = const [],
  });

  factory UserProfileData.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>? ?? {};

    final rawPosts = json['posts'] as List<dynamic>? ?? [];
    final posts =
        rawPosts
            .whereType<Map<String, dynamic>>()
            .map((p) {
              try {
                return FeedContent.fromNewApiPost(p);
              } catch (_) {
                return null;
              }
            })
            .whereType<FeedContent>()
            .toList();

    return UserProfileData(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      bio: profile['bio']?.toString(),
      avatar: profile['avatar']?.toString(),
      interests: List<String>.from(profile['interests'] ?? []),
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
      followerUsernames: List<String>.from(json['follower_usernames'] ?? []),
      followingUsernames: List<String>.from(json['following_usernames'] ?? []),
      createdAt:
          profile['created_at'] != null
              ? DateTime.parse(profile['created_at'])
              : DateTime.now(),
      posts: posts,
    );
  }

  String? get avatarUrl {
    if (avatar == null || avatar!.isEmpty) return null;
    if (avatar!.startsWith('http://') || avatar!.startsWith('https://')) {
      return avatar;
    }
    return '${ApiConstants.userBase}$avatar';
  }
}

class FollowerFollowing {
  final String id;
  final String name;
  final String email;
  final String? picture;
  final String? username;

  FollowerFollowing({
    required this.id,
    required this.name,
    required this.email,
    this.picture,
    this.username,
  });

  factory FollowerFollowing.fromNewApi(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>? ?? {};
    final avatar = profile['avatar']?.toString();
    final fullName = json['full_name']?.toString() ?? '';
    final username = json['username']?.toString() ?? '';

    return FollowerFollowing(
      id: json['id']?.toString() ?? '',
      name: fullName.isNotEmpty ? fullName : username,
      email: json['email']?.toString() ?? '',
      picture: avatar,
      username: username,
    );
  }

  String? get fullPictureUrl {
    if (picture == null || picture!.isEmpty) return null;
    if (picture!.startsWith('http://') || picture!.startsWith('https://')) {
      return picture;
    }
    return '${ApiConstants.userBase}$picture';
  }
}

 

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

 
class UserProfileService {
  static Future<UserProfileData> getUserProfile() async {
    final token = AppData().accessToken;
    if (token == null || token.isEmpty) {
      throw AuthException('No authentication token found');
    }

    final url = Uri.parse(ApiConstants.fetchuserprofile);
    final response = await http.get(url, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return UserProfileData.fromJson(data);
    } else if (response.statusCode == 401) {
      await AppData().clearAuthToken();
      throw AuthException('Authentication token expired or invalid');
    } else {
      throw Exception('Failed to load profile: ${response.statusCode}');
    }
  }

  static Future<String> uploadProfilePicture(File imageFile) async {
    final token = AppData().accessToken;
    if (token == null || token.isEmpty) {
      throw AuthException('No authentication token found');
    }

    final filename = path.basename(imageFile.path);
    final url = Uri.parse(ApiConstants.updateuserprofilepicture);
    final mimeType =
        filename.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

    var request =
        http.MultipartRequest('POST', url)
          ..headers['authorization'] = 'Bearer $token'
          ..files.add(
            http.MultipartFile(
              'avatar',
              http.ByteStream(imageFile.openRead()),
              await imageFile.length(),
              filename: filename,
              contentType: MediaType.parse(mimeType),
            ),
          );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    log('Avatar upload response [${response.statusCode}]: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final avatarPath =
          data['avatar']?.toString() ??
          data['data']?['avatar']?.toString() ??
          data['data']?['picture']?.toString() ??
          '';
      if (avatarPath.isEmpty) throw Exception('No avatar URL in response');
      return avatarPath;
    } else if (response.statusCode == 401) {
      await AppData().clearAuthToken();
      throw AuthException('Authentication token expired or invalid');
    } else {
      throw Exception('Failed to upload avatar: ${response.statusCode}');
    }
  }

  static Future<List<FollowerFollowing>> getFollowers() async {
    final token = AppData().accessToken;
    if (token == null || token.isEmpty) throw AuthException('No token');

    final response = await http.get(
      Uri.parse(ApiConstants.getfollowers),
      headers: _authHeaders(token),
    );

    log('Followers API [${response.statusCode}]: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final list = data['followers'] as List<dynamic>? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(FollowerFollowing.fromNewApi)
          .toList();
    } else if (response.statusCode == 401) {
      await AppData().clearAuthToken();
      throw AuthException('Authentication token expired or invalid');
    } else {
      throw Exception('Failed to load followers: ${response.statusCode}');
    }
  }

  static Future<List<FollowerFollowing>> getFollowing() async {
    final token = AppData().accessToken;
    if (token == null || token.isEmpty) throw AuthException('No token');

    final response = await http.get(
      Uri.parse(ApiConstants.getfollowing),
      headers: _authHeaders(token),
    );

    log('Following API [${response.statusCode}]: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final list = data['following'] as List<dynamic>? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(FollowerFollowing.fromNewApi)
          .toList();
    } else if (response.statusCode == 401) {
      await AppData().clearAuthToken();
      throw AuthException('Authentication token expired or invalid');
    } else {
      throw Exception('Failed to load following: ${response.statusCode}');
    }
  }

  static Map<String, String> _authHeaders(String token) => {
    'Content-Type': 'application/json',
    'authorization': 'Bearer $token',
  };
}

 
class _SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder:
          (_, __) => Opacity(
            opacity: _animation.value,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: widget.borderRadius,
              ),
            ),
          ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar + name row
              Row(
                children: [
                  const _SkeletonBox(
                    width: 120,
                    height: 120,
                    borderRadius: BorderRadius.all(Radius.circular(60)),
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SkeletonBox(width: 140, height: 20),
                      const SizedBox(height: 8),
                      const _SkeletonBox(width: 180, height: 14),
                      const SizedBox(height: 12),
                      _SkeletonBox(
                        width: 80,
                        height: 26,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(thickness: 0.8, color: Colors.grey[300]),
              // Followers / Following / More row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Column(
                          children: const [
                            _SkeletonBox(width: 30, height: 18),
                            SizedBox(height: 4),
                            _SkeletonBox(width: 60, height: 12),
                          ],
                        ),
                        const SizedBox(width: 40),
                        Column(
                          children: const [
                            _SkeletonBox(width: 30, height: 18),
                            SizedBox(height: 4),
                            _SkeletonBox(width: 60, height: 12),
                          ],
                        ),
                      ],
                    ),
                    _SkeletonBox(
                      width: 35,
                      height: 35,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Posts header skeleton
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SkeletonBox(width: 60, height: 20),
              _SkeletonBox(
                width: 90,
                height: 36,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
        ),
        Divider(thickness: 0.8, color: Colors.grey[300]),
        const SizedBox(height: 12),
        // Post card skeletons
        ...List.generate(3, (_) => const _PostCardSkeleton()),
      ],
    );
  }
}

class _PostCardSkeleton extends StatelessWidget {
  const _PostCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SkeletonBox(
                width: 40,
                height: 40,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _SkeletonBox(width: 120, height: 14),
                  SizedBox(height: 4),
                  _SkeletonBox(width: 80, height: 11),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SkeletonBox(
            width: double.infinity,
            height: 200,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 10),
          const _SkeletonBox(width: double.infinity, height: 13),
          const SizedBox(height: 6),
          const _SkeletonBox(width: 220, height: 13),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

 
class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late Future<UserProfileData> _profileFuture;
  bool _isUploading = false;
  bool _isPickingImage = false;
  String? _errorMessage;
  bool _postsLoaded = false;

  late TabController _tabController;
  final UserController _userController = Get.put(UserController());

  final List<FeedContent> _contents = [];
  final ScrollController _scrollController = ScrollController();

  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
 
  void _loadProfile({bool showSkeletonImmediately = true}) {
    setState(() {
      if (showSkeletonImmediately) _contents.clear();
      _postsLoaded = false;
      _isLoading = true;  
    });
    _profileFuture = UserProfileService.getUserProfile();
  }
 
  bool _isLoading = false;
 
  Future<void> _refresh() async {
    setState(() {
      _contents.clear();
      _postsLoaded = false;
    });
 
    final newFuture = UserProfileService.getUserProfile();
    setState(() => _profileFuture = newFuture);

    try {
      final freshProfile = await newFuture;
      _populatePostsFromProfile(freshProfile);
    } catch (_) { 
    }
  }
 
  void _populatePostsFromProfile(UserProfileData profile) {
    if (!mounted) return;
    setState(() {
      _contents
        ..clear()
        ..addAll(profile.posts);
      _postsLoaded = true;
    });
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

 
  Future<void> _pickAndUploadImage() async {
    if (_isPickingImage || _isUploading) return;

    setState(() => _isPickingImage = true);
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      setState(() => _isPickingImage = false);
      if (image == null) return;

      setState(() {
        _isUploading = true;
        _errorMessage = null;
      });

      final oldPath = _userController.getFullProfilePicturePath();
      if (oldPath != null) {
        imageCache.evict(NetworkImage(oldPath));
        imageCache.evict(
          NetworkImage(
            '$oldPath?v=${_userController.profilePictureVersion.value}',
          ),
        );
      }

      final newAvatarPath = await UserProfileService.uploadProfilePicture(
        File(image.path),
      );

      _userController.updateProfilePicture(newAvatarPath);
      await AppData().updateProfilePicture(newAvatarPath);

      InstantCache.invalidate();

      imageCache.evict(NetworkImage(newAvatarPath));
      _userController.profilePictureVersion.value++;

      setState(() {
        _isUploading = false; 
        _loadProfile();
      });
    } catch (e) {
      setState(() {
        _isPickingImage = false;
        _isUploading = false;
        _errorMessage = e.toString();
      });
    }
  }
 

  void _showFollowersFollowingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            backgroundColor: AppColors.whitecolor,
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
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
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 16),
                            SizedBox(width: 4),
                            Text('Followers'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_add_outlined, size: 16),
                            SizedBox(width: 4),
                            Text('Following'),
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
          ),
    );
  }

  Widget _buildFollowersList() => _buildFollowList(
    future: UserProfileService.getFollowers(),
    emptyText: 'No followers found',
    onRefresh: () => setState(() {}),
    initialFollowStatus: false,
  );

  Widget _buildFollowingList() => _buildFollowList(
    future: UserProfileService.getFollowing(),
    emptyText: 'Not following anyone yet',
    onRefresh: () => setState(() {}),
    initialFollowStatus: true,
  );

  Widget _buildFollowList({
    required Future<List<FollowerFollowing>> future,
    required String emptyText,
    required VoidCallback onRefresh,
    required bool initialFollowStatus,
  }) {
    return FutureBuilder<List<FollowerFollowing>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) return Center(child: Text(emptyText));

        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final person = list[index];
            final pictureUrl = person.fullPictureUrl;
            final displayName =
                person.name.isNotEmpty
                    ? person.name
                    : '@${person.username ?? ''}';

            return ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: const Color.fromRGBO(235, 111, 70, 0.2),
                backgroundImage:
                    pictureUrl != null ? NetworkImage(pictureUrl) : null,
                child:
                    pictureUrl == null
                        ? const Icon(
                          Icons.person,
                          color: Color.fromRGBO(244, 135, 6, 1),
                        )
                        : null,
              ),
              title: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => SpecificUserProfilePage(userId: person.id),
                    ),
                  );
                },
                child: Text(displayName),
              ),
              subtitle: Text(
                person.username != null ? '@${person.username}' : person.email,
              ),
              trailing: FollowButton(
                targetUserEmail: person.email,
                initialFollowStatus: initialFollowStatus,
                onFollowSuccess: onRefresh,
                onUnfollowSuccess: onRefresh,
                size: 36,
                targetUserId: person.id,
              ),
            );
          },
        );
      },
    );
  }

 
  Widget _buildProfileSection(UserProfileData profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            children: [ 
              Row(
                children: [
                  Stack(
                    children: [
                      Obx(
                        () => CircleAvatar(
                          radius: 60,
                          backgroundColor: const Color.fromRGBO(
                            235,
                            111,
                            70,
                            0.2,
                          ),
                          key: ValueKey(
                            'profile_${_userController.profilePictureVersion.value}',
                          ),
                          backgroundImage: _resolveAvatarImage(profile),
                          child:
                              _shouldShowPlaceholder(profile)
                                  ? const Icon(
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
                          onTap:
                              (_isUploading || _isPickingImage)
                                  ? null
                                  : _pickAndUploadImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color.fromRGBO(244, 135, 6, 1),
                              shape: BoxShape.circle,
                            ),
                            child:
                                _isUploading
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: AppColors.whitecolor,
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(
                                      Icons.camera_alt,
                                      color: AppColors.whitecolor,
                                      size: 16,
                                    ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Obx(
                          () => Text(
                            _userController.userName.value ??
                                (profile.fullName.isNotEmpty
                                    ? profile.fullName
                                    : profile.username),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          profile.email,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (profile.role.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color.fromRGBO(244, 135, 6, 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.only(top: 8),
                            child: Text(
                              profile.role.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color.fromRGBO(244, 135, 6, 1),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),

              Divider(thickness: 0.8, color: Colors.grey[300]),
 
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _showFollowersFollowingDialog(context),
                          child: Column(
                            children: [
                              Text(
                                '${profile.followersCount}',
                                style: const TextStyle(
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
                        ),
                        const SizedBox(width: 40),
                        GestureDetector(
                          onTap: () {
                            _tabController.index = 1;
                            _showFollowersFollowingDialog(context);
                          },
                          child: Column(
                            children: [
                              Text(
                                '${profile.followingCount}',
                                style: const TextStyle(
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
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 35,
                      width: 35,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.more_vert_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () => _showMoreOptions(context, profile),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),

        // Posts header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Posts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ReelsScreen()),
                    ),
                label: const Text(
                  'Reels',
                  style: TextStyle(color: Colors.black),
                ),
                icon: const Icon(
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

        Divider(thickness: 0.8, color: Colors.grey[300]),
      ],
    );
  }

  ImageProvider? _resolveAvatarImage(UserProfileData profile) {
    final controllerPath = _userController.getFullProfilePicturePath();
    if (controllerPath != null && controllerPath.isNotEmpty) {
      return NetworkImage(
        '$controllerPath?v=${_userController.profilePictureVersion.value}',
      );
    }
    final url = profile.avatarUrl;
    if (url != null && url.isNotEmpty) return NetworkImage(url);
    return null;
  }

  bool _shouldShowPlaceholder(UserProfileData profile) {
    final controllerPath = _userController.getFullProfilePicturePath();
    final hasController = controllerPath != null && controllerPath.isNotEmpty;
    final hasApiAvatar =
        profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty;
    return !hasController && !hasApiAvatar;
  }

  void _showMoreOptions(BuildContext context, UserProfileData profile) {
    showModalBottomSheet(
      backgroundColor: AppColors.whitecolor,
      context: context,
      builder:
          (_) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('My Information'),
                onTap: () {
                  Navigator.of(context).pop();
                  showAdaptiveDialog(
                    context: context,
                    builder:
                        (_) => AlertDialog(
                          backgroundColor: AppColors.whitecolor,
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 24),
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text(
                                  'Personal Information',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ProfileInfoCard(
                                title: 'Username',
                                value: profile.username,
                                icon: Icons.person,
                              ),
                              ProfileInfoCard(
                                title: 'Full Name',
                                value:
                                    profile.fullName.isNotEmpty
                                        ? profile.fullName
                                        : '(not set)',
                                icon: Icons.badge,
                              ),
                              ProfileInfoCard(
                                title: 'Email',
                                value: profile.email,
                                icon: Icons.email,
                              ),
                              if (profile.bio != null &&
                                  profile.bio!.isNotEmpty)
                                ProfileInfoCard(
                                  title: 'Bio',
                                  value: profile.bio!,
                                  icon: Icons.description,
                                ),
                              ProfileInfoCard(
                                title: 'Member Since',
                                value: _formatDate(profile.createdAt),
                                icon: Icons.access_time,
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed:
                                  () => Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => EditProfileScreen(),
                                    ),
                                  ),
                              child: const Text(
                                'Edit',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text(
                                'Close',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  await AppData().clearAuthToken();
                  Get.offAll(() => LoginPage());
                },
              ),
            ],
          ),
    );
  }

 
  Widget _buildContentItem(int index) {
    final content = _contents[index];
    return RepaintBoundary(
      key: ValueKey(content.id),
      child: FeedItem(
        content: content,
        onLikeToggled:
            (isLiked) => setState(() {
              content.isLiked = isLiked;
              content.likes += isLiked ? 1 : -1;
            }),
        onFollowToggled:
            (isFollowed) => setState(() => content.isFollowed = isFollowed),
      ),
    );
  }

 
  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(chatUnreadCountProvider);

    return Scaffold(
      backgroundColor: AppColors.whitecolor,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 40),
        child: CustomRefreshIndicator( 
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _scrollController, 
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [ 
              SliverToBoxAdapter(
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => Navigator.pop(context),
                  alignment: Alignment.centerLeft,
                ),
              ),
 
              SliverToBoxAdapter(
                child: FutureBuilder<UserProfileData>(
                  future: _profileFuture,
                  builder: (context, snapshot) { 
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _ProfileSkeleton();
                    }
 
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Error loading profile',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => setState(() => _loadProfile()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromRGBO(
                                  244,
                                  135,
                                  6,
                                  1,
                                ),
                              ),
                              child: const Text(
                                'Try Again',
                                style: TextStyle(color: AppColors.whitecolor),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
 
                    if (snapshot.hasData) { 
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _populatePostsFromProfile(snapshot.data!);
                      });
                      return _buildProfileSection(snapshot.data!);
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),

             
              if (!_postsLoaded)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, __) => const _PostCardSkeleton(),
                    childCount: 3,
                  ),
                )
              else if (_contents.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.article_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No posts yet',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildContentItem(index),
                    childCount: _contents.length,
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: CountBadgeFAB(
        count: unreadCount,
        gifAsset: 'animation/chaticon.gif',
        backgroundColor: Colors.transparent,
        onPressed: () {
          ref.read(mutualFriendsProvider.notifier).refresh();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatListScreen()),
          ).then((_) {
            ref.invalidate(mutualFriendsProvider);
          });
        },
      ),
    );
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
      color: AppColors.whitecolor,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: const Color.fromRGBO(244, 135, 6, 1)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
