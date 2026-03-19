import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/App_data/App_data.dart';

import 'package:innovator/Innovator/screens/show_Specific_Profile/Show_Specific_Profile.dart';
import 'package:innovator/Innovator/widget/FloatingMenuwidget.dart';
import '../../controllers/user_controller.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final AppData _appData = AppData();
  final UserController userController = Get.find<UserController>();

  List<dynamic> _searchResults = [];
  List<dynamic> _suggestedUsers = [];
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isSuggestedUsersExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchSuggestedUsers();
  }

  List<dynamic> _filterUniqueUsers(List<dynamic> users) {
    final uniqueEmails = <String>{};
    return users.where((user) {
      final email = user['email'] ?? '';
      if (email.isEmpty || uniqueEmails.contains(email)) {
        return false;
      }
      uniqueEmails.add(email);
      return true;
    }).toList();
  }

  Future<void> _fetchSuggestedUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('http://182.93.94.210:3067/api/v1/users'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'authorization': 'Bearer ${_appData.accessToken}',
        },
      );

      if (response.statusCode == 200) {
        final data = _filterUniqueUsers(json.decode(response.body)['data']);

        setState(() {
          _suggestedUsers = data.take(10).toList();
          _isLoading = false;
        });

        // ENHANCED: Cache and preload with user data
        await _cacheAndPreloadUsers(_suggestedUsers);
      } else {
        throw Exception('Failed to load suggestions');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorMessage('Error loading suggestions');
      debugPrint('Error fetching suggested users: $e');
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('http://182.93.94.210:3067/api/v1/users'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'authorization': 'Bearer ${_appData.accessToken}',
        },
      );

      if (response.statusCode == 200) {
        final data = _filterUniqueUsers(json.decode(response.body)['data']);

        final filteredResults =
            data
                .where(
                  (user) =>
                      user['name']?.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ??
                      false,
                )
                .toList();

        setState(() {
          _searchResults = filteredResults;
          _isLoading = false;
        });

        // ENHANCED: Cache and preload search results
        await _cacheAndPreloadUsers(filteredResults);
      } else {
        throw Exception('Failed to search users');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorMessage('Error searching users');
      debugPrint('Error searching users: $e');
    }
  }

  // NEW: Enhanced caching and preloading method
  Future<void> _cacheAndPreloadUsers(List<dynamic> users) async {
    if (users.isEmpty) return;

    try {
      // Cache all users first using existing bulkCacheUsers method
      final usersToCache = users.cast<Map<String, dynamic>>();
      userController.bulkCacheUsers(usersToCache);
      debugPrint('Cached ${users.length} users in search');

      // Preload images using existing preloadVisibleUsers method
      final userIds = users.map((user) => user['_id'] as String).toList();
      await userController.preloadVisibleUsers(userIds, context);

      debugPrint('Preloaded ${userIds.length} user images in search');

      // Force UI refresh to ensure cached images are displayed
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error caching/preloading users: $e');
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.grey[50],
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(right: 10, left: 10),
          child: Column(
            children: [
              _buildSimpleHeader(),
              _buildSimpleSearchBar(),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
      //floatingActionButton: FloatingMenuWidget(),
    );
  }

  Widget _buildSimpleHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.search, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Find People',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Discover and connect with others',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleSearchBar() {
    return SearchBar(
      elevation: WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(Colors.grey[100]!),
      hintText: 'Search for people...',
      onChanged: (value) {
        _searchUsers(value);
      },
      controller: _searchController,
      onTap: () {
        _searchController.clear();
        _searchUsers('');
        setState(() {});
      },
      leading: const Icon(Icons.search, color: Colors.grey),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 16),
            Text('Loading...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Container(
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  _isSearching ? 'Search Results' : 'Suggested People',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                if (!_isSearching) // Show button only when not searching
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSuggestedUsersExpanded = !_isSuggestedUsersExpanded;
                      });
                    },
                    child: Text(
                      _isSuggestedUsersExpanded ? 'Show Less' : 'See All',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildUserList()),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    final users =
        _isSearching
            ? _searchResults
            : _isSuggestedUsersExpanded
            ? _suggestedUsers
            : _suggestedUsers.take(3).toList();

    // If searching and no results, show "No results found"
    if (_isSearching && users.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Show the user list (either search results or limited/full suggested users)
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final userId = user['_id'] ?? '';
    final userName = user['name'] ?? 'Unknown';
    final userPicture = user['picture'] ?? '';

    // Debug logging for problematic users
    if (userName.toLowerCase().contains('nepatronix')) {
      debugPrint('DEBUG NepaTronix in search:');
      debugPrint('  - User ID: $userId');
      debugPrint('  - Name: $userName');
      debugPrint('  - Picture: $userPicture');
      debugPrint('  - Is cached: ${userController.isUserCached(userId)}');
      debugPrint(
        '  - Cached URL: ${userController.getOtherUserFullProfilePicturePath(userId)}',
      );
    }

    // Force cache the user if not already cached
    if (userId.isNotEmpty && !userController.isUserCached(userId)) {
      debugPrint('Force caching user in search: $userName ($userId)');
      userController.cacheUserProfilePicture(
        userId,
        userPicture.isNotEmpty ? userPicture : null,
        userName,
      );
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SpecificUserProfilePage(userId: userId),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Row(
            children: [
              // Enhanced avatar with better fallback handling
              _buildSearchAvatar(userId, userName, userPicture),

              const SizedBox(width: 12),

              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(thickness: 2, color: Colors.grey[300], height: 20),
        ],
      ),
    );
  }

  Widget _buildSearchAvatar(
    String userId,
    String userName,
    String userPicture,
  ) {
    // Try to get cached URL first
    String? imageUrl = userController.getOtherUserFullProfilePicturePath(
      userId,
    );

    // If no cached URL, build direct URL from user data
    if (imageUrl == null && userPicture.isNotEmpty) {
      imageUrl =
          userPicture.startsWith('http')
              ? userPicture
              : 'http://182.93.94.210:3067${userPicture.startsWith('/') ? userPicture : '/$userPicture'}';
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.grey[300],
      backgroundImage:
          imageUrl != null && imageUrl.isNotEmpty
              ? NetworkImage(imageUrl)
              : null,
      onBackgroundImageError:
          imageUrl != null
              ? (error, stackTrace) {
                debugPrint('Avatar image error for $userName: $error');
              }
              : null,
      child:
          imageUrl == null || imageUrl.isEmpty
              ? Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              )
              : null,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
