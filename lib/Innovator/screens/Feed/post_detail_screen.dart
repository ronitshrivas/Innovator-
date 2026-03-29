import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/Authorization/Login.dart';
import 'package:innovator/Innovator/constant/app_colors.dart';
import 'package:innovator/Innovator/controllers/user_controller.dart';
import 'package:innovator/Innovator/screens/Feed/Inner_Homepage.dart';
import 'package:innovator/Innovator/screens/Feed/Optimize%20Media/OptimizeMediaScreen.dart';
import 'package:innovator/Innovator/screens/Feed/VideoPlayer/videoplayerpackage.dart';
import 'package:innovator/Innovator/screens/Follow/follow-Service.dart';
import 'package:innovator/Innovator/screens/Follow/follow_Button.dart';
import 'package:innovator/Innovator/screens/Likes/Content-Like-Service.dart';
import 'package:innovator/Innovator/screens/Likes/content-Like-Button.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:innovator/Innovator/screens/SHow_Specific_Profile/Show_Specific_Profile.dart';
import 'package:innovator/Innovator/screens/chatrrom/sound/soundplayer.dart';
import 'package:innovator/Innovator/screens/comment/JWT_Helper.dart';
import 'package:innovator/Innovator/screens/comment/comment_section.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';

class SpecificPostScreen extends StatefulWidget {
  final String contentId;
  final String? highlightAction;

  const SpecificPostScreen({
    Key? key,
    required this.contentId,
    this.highlightAction,
  }) : super(key: key);

  @override
  State<SpecificPostScreen> createState() => _SpecificPostScreenState();
}

class _SpecificPostScreenState extends State<SpecificPostScreen>
    with SingleTickerProviderStateMixin {
  SpecificPostContent? content;
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  bool _showComments = false;

  late AnimationController _highlightController;
  late Animation<Color?> _highlightAnimation;

  final ContentLikeService likeService = ContentLikeService(
    baseUrl: 'http://182.93.94.210:3067',
  );

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _highlightAnimation = ColorTween(
      begin: Colors.blue.withAlpha(30),
      end: Colors.transparent,
    ).animate(
      CurvedAnimation(parent: _highlightController, curve: Curves.easeOut),
    );

    fetchSpecificPost();

    // If there's a highlight action, show comments section and highlight
    if (widget.highlightAction != null) {
      Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _showComments = true;
          });
          _highlightController.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

  Future<void> fetchSpecificPost() async {
    try {
      setState(() {
        isLoading = true;
        hasError = false;
      });

      final String? authToken = AppData().accessToken;
      if (authToken == null || authToken.isEmpty) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LoginPage()),
          (route) => false,
        );
        return;
      }

      final response = await http
          .get(
            Uri.parse(
              'http://182.93.94.210:3067/api/v1/content/${widget.contentId}',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
          )
          .timeout(const Duration(seconds: 30));

      debugPrint(' Specific Post Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 200 && data['data'] != null) {
          Map<String, dynamic> contentData;

          if (data['data'] is String) {
            contentData = json.decode(data['data']) as Map<String, dynamic>;
          } else if (data['data'] is Map<String, dynamic>) {
            contentData = data['data'] as Map<String, dynamic>;
          } else if (data['data'] is Map) {
            contentData = Map<String, dynamic>.from(data['data'] as Map);
          } else {
            throw Exception(
              'Unexpected data format: ${data['data'].runtimeType}',
            );
          }

          // NEW: Check if author is just a string (incomplete data)
          final authorData = contentData['author'];
          bool needsAuthorFetch = false;
          String? authorId;

          if (authorData is String) {
            debugPrint(
              ' Author is just a name string, need to fetch full author data',
            );
            needsAuthorFetch = true;
            // Try to get author ID from the content's creator field or other source
            authorId = contentData['userId'] ?? contentData['createdBy'];
          } else if (authorData is Map) {
            final authorMap = Map<String, dynamic>.from(authorData as Map);
            // Check if author object is incomplete (missing picture)
            if (authorMap['picture'] == null ||
                authorMap['picture'].toString().isEmpty) {
              debugPrint(' Author object missing picture field');
              needsAuthorFetch = true;
              authorId = authorMap['_id'] ?? authorMap['id'];
            }
          }

          setState(() {
            content = SpecificPostContent.fromJson(contentData);
            isLoading = false;
          });

          // NEW: Fetch complete author data if needed
          if (needsAuthorFetch && authorId != null && authorId.isNotEmpty) {
            await _fetchAuthorData(authorId);
          }

          debugPrint('Content loaded successfully: ${content?.id}');
        } else {
          throw Exception(data['message'] ?? 'Failed to load post');
        }
      } else if (response.statusCode == 401) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LoginPage()),
          (route) => false,
        );
      } else if (response.statusCode == 404) {
        setState(() {
          hasError = true;
          errorMessage = 'Post not found';
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load post: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      debugPrint(' Error loading post: $e');
      debugPrint(' Stack trace: $stackTrace');

      setState(() {
        hasError = true;
        errorMessage = 'Error loading post: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchAuthorData(String authorId) async {
    try {
      final String? authToken = AppData().accessToken;
      if (authToken == null || authToken.isEmpty) return;

      debugPrint(' Fetching author data for: $authorId');

      final response = await http
          .get(
            Uri.parse('http://182.93.94.210:3067/api/v1/user/$authorId'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        debugPrint(' Author API Response: ${response.body}');

        if (data['status'] == 200 && data['data'] != null) {
          final userData = data['data'];

          debugPrint('👤 User data received:');
          debugPrint('   - ID: ${userData['_id'] ?? userData['id']}');
          debugPrint('   - Name: ${userData['name']}');
          debugPrint('   - Picture: ${userData['picture']}');

          // Update the content's author with complete data
          if (mounted && content != null) {
            setState(() {
              content!.author.id =
                  userData['_id'] ?? userData['id'] ?? authorId;
              content!.author.name = userData['name'] ?? content!.author.name;
              content!.author.email = userData['email'] ?? '';
              content!.author.picture = userData['picture'] ?? '';
            });

            debugPrint('Author data updated in state');
            debugPrint('   - New picture path: ${content!.author.picture}');
          }
        }
      } else {
        debugPrint(' Author API returned status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint(' Error fetching author data: $e');
      // Don't throw error, just continue with partial data
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Post',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.whitecolor,
          ),
        ),
        backgroundColor: const Color.fromRGBO(244, 135, 6, 1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.whitecolor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (content != null)
            IconButton(
              icon: const Icon(Icons.share, color: AppColors.whitecolor),
              onPressed: () => _showShareOptions(context),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading post...'),
          ],
        ),
      );
    }

    if (hasError || content == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              errorMessage.isNotEmpty ? errorMessage : 'Failed to load post',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: fetchSpecificPost,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _highlightAnimation,
            builder: (context, child) {
              return Container(
                color: _highlightAnimation.value,
                child: _buildPostCard(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.whitecolor,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 20.0,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        // crossAxisAlignment: CrossAxisAlignment.,
        children: [
          _buildHeader(),
          if (content!.status.isNotEmpty) _buildStatusSection(),
          if (content!.hasMedia) _buildMediaSection(),
          _buildActionButtons(),
          _buildEngagementInfo(),
          if (_showComments) _buildCommentsSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          _buildAuthorAvatar(),
          const SizedBox(width: 16.0),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            SpecificUserProfilePage(userId: content!.author.id),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          content!.author.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16.0,
                            color: Color(0xFF1A1A1A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!_isAuthorCurrentUser()) ...[
                        const SizedBox(width: 8.0),
                        Container(
                          width: 4.0,
                          height: 4.0,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        if (_isAuthorCurrentUser() == true)
                          FollowButton(
                            targetUserEmail: content!.author.email,
                            initialFollowStatus: content!.engagement.following,
                            onFollowSuccess: () {
                              setState(() {
                                content!.engagement.following = true;
                              });
                            },
                            onUnfollowSuccess: () {
                              setState(() {
                                content!.engagement.following = false;
                              });
                            },
                            targetUserId: content!.author.id,
                          ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4.0),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: _getTypeColor(content!.type).withAlpha(50),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Text(
                          content!.type.toUpperCase(),
                          style: TextStyle(
                            color: _getTypeColor(content!.type),
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        _formatTimeAgo(content!.createdAt),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _buildMenuButton(),
        ],
      ),
    );
  }

  // Replace the _buildAuthorAvatar method in SpecificPostScreen with this:

  Widget _buildAuthorAvatar() {
    final userController = Get.find<UserController>();

    // For current user - use reactive profile picture
    if (_isAuthorCurrentUser()) {
      return Obx(() {
        final picturePath = userController.getFullProfilePicturePath();
        final version = userController.profilePictureVersion.value;

        return CircleAvatar(
          key: ValueKey('specific_post_avatar_${content!.author.id}_$version'),
          radius: 24,
          backgroundColor: Colors.grey[300],
          backgroundImage:
              picturePath != null && picturePath.isNotEmpty
                  ? CachedNetworkImageProvider('$picturePath?v=$version')
                  : null,
          child:
              picturePath == null || picturePath.isEmpty
                  ? Text(
                    content!.author.name.isNotEmpty
                        ? content!.author.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.whitecolor,
                    ),
                  )
                  : null,
        );
      });
    }

    // For other users - directly use the URL from content
    final authorPicture = content!.author.picture;

    // Format the image URL
    String? imageUrl;
    if (authorPicture.isNotEmpty) {
      if (authorPicture.startsWith('http')) {
        imageUrl = authorPicture;
      } else {
        imageUrl = 'http://182.93.94.210:3067$authorPicture';
      }
    }

    debugPrint('🖼️ Loading avatar for ${content!.author.name}');
    debugPrint('   Picture path: $authorPicture');
    debugPrint('   Full URL: $imageUrl');

    // If no image URL, show initials
    if (imageUrl == null || imageUrl.isEmpty) {
      debugPrint('    No image URL, showing initials');
      return CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey[400],
        child: Text(
          content!.author.name.isNotEmpty
              ? content!.author.name[0].toUpperCase()
              : '?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.whitecolor,
          ),
        ),
      );
    }

    // Show image with caching
    return CachedNetworkImage(
      imageUrl: imageUrl,
      imageBuilder: (context, imageProvider) {
        debugPrint('   Image loaded successfully');
        return CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[300],
          backgroundImage: imageProvider,
        );
      },
      placeholder: (context, url) {
        debugPrint('   ⏳ Loading image...');
        return CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[300],
          child: Container(
            width: 20,
            height: 20,
            child: Image.asset('animation/IdeaBulb.gif', fit: BoxFit.contain),
          ),
        );
      },
      errorWidget: (context, url, error) {
        debugPrint('    Error loading image: $error');
        debugPrint('    Failed URL: $url');
        return CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[400],
          child: Text(
            content!.author.name.isNotEmpty
                ? content!.author.name[0].toUpperCase()
                : '?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.whitecolor,
            ),
          ),
        );
      },
      memCacheWidth: 96,
      memCacheHeight: 96,
    );
  }

  Widget _buildStatusSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: _LinkifyText(
        text: content!.status,
        style: const TextStyle(
          fontSize: 16.0,
          height: 1.5,
          letterSpacing: 1.2,
          color: Color(0xFF2D2D2D),
          fontWeight: FontWeight.w500,
          fontFamily: 'InterThin',
        ),
      ),
    );
  }

  Widget _buildMediaSection() {
    if (!content!.hasMedia) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: _buildMediaPreview(),
      ),
    );
  }

  Widget _buildMediaPreview() {
    if (!content!.hasMedia) return const SizedBox.shrink();

    // Check for optimized video files first
    final hasOptimizedVideo = content!.optimizedFiles.any(
      (file) => file.type == 'video',
    );

    final hasOptimizedImages = content!.optimizedFiles.any(
      (file) => file.type == 'image',
    );

    // Handle optimized video
    if (hasOptimizedVideo) {
      final videoFile = content!.optimizedFiles.firstWhere(
        (file) => file.type == 'video',
      );

      final videoUrl = videoFile.url;
      final thumbnailUrl = videoFile.thumbnail;

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: _buildVideoPlayer(
            _formatMediaUrl(videoUrl),
            thumbnailUrl != null ? _formatMediaUrl(thumbnailUrl) : null,
          ),
        ),
      );
    }

    // Handle optimized images
    if (hasOptimizedImages) {
      final imageUrls =
          content!.optimizedFiles
              .where((file) => file.type == 'image')
              .map((file) => _formatMediaUrl(file.url))
              .toList();

      if (imageUrls.isNotEmpty) {
        return _buildImageGallery(imageUrls);
      }
    }

    // Fallback to original files
    if (content!.files.isNotEmpty) {
      final firstFile = content!.files.first;
      final formattedUrl = _formatMediaUrl(firstFile);

      // Check if it's a video
      if (FileTypeHelper.isVideo(formattedUrl)) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: _buildVideoPlayer(formattedUrl, null),
          ),
        );
      }

      // Otherwise show image
      return GestureDetector(
        onTap: () => _showMediaGallery(content!.files, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: CachedNetworkImage(
            imageUrl: formattedUrl,
            fit: BoxFit.cover,
            placeholder:
                (context, url) => Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      child: Image.asset(
                        'animation/IdeaBulb.gif',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
            errorWidget:
                (context, url, error) => Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: const Center(child: Icon(Icons.error)),
                ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildVideoPlayer(String videoUrl, String? thumbnailUrl) {
    return Container(
      color: Colors.black,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: AutoPlayVideoWidget(url: videoUrl, thumbnailUrl: thumbnailUrl),
      ),
    );
  }

  bool _isVideoFile(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.endsWith('.mp4') ||
        lowerUrl.endsWith('.mov') ||
        lowerUrl.endsWith('.avi') ||
        lowerUrl.endsWith('.m3u8') ||
        lowerUrl.contains('video');
  }

  Widget _buildImageGallery(List<String> imageUrls) {
    if (imageUrls.length == 1) {
      return GestureDetector(
        onTap: () => _showMediaGallery(imageUrls, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: CachedNetworkImage(
            imageUrl: imageUrls.first,
            fit: BoxFit.cover,
            placeholder:
                (context, url) => Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      child: Image.asset(
                        'animation/IdeaBulb.gif',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
            errorWidget:
                (context, url, error) => Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: const Center(child: Icon(Icons.error)),
                ),
          ),
        ),
      );
    }

    // For multiple images, use a grid
    return Container(
      constraints: BoxConstraints(maxHeight: 400),
      child: GridView.builder(
        physics: NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 4.0,
          mainAxisSpacing: 4.0,
          childAspectRatio: 1.0,
        ),
        itemCount: imageUrls.length > 4 ? 4 : imageUrls.length,
        itemBuilder: (context, index) {
          if (index == 3 && imageUrls.length > 4) {
            return GestureDetector(
              onTap: () => _showMediaGallery(imageUrls, index),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: imageUrls[index],
                      fit: BoxFit.cover,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '+${imageUrls.length - 4}',
                        style: TextStyle(
                          color: AppColors.whitecolor,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return GestureDetector(
            onTap: () => _showMediaGallery(imageUrls, index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: imageUrls[index],
                fit: BoxFit.cover,
                placeholder:
                    (context, url) => Container(
                      color: Colors.grey[300],
                      child: Center(
                        child: Container(
                          width: 30,
                          height: 30,
                          child: Image.asset(
                            'animation/IdeaBulb.gif',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                errorWidget:
                    (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: Icon(Icons.error, color: AppColors.whitecolor),
                    ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Widget _buildImageGridItem(List<String> urls, int index) {
  //   return GestureDetector(
  //     onTap: () => _showMediaGallery(urls, index),
  //     child: ClipRRect(
  //       borderRadius: BorderRadius.circular(8),
  //       child: CachedNetworkImage(
  //         imageUrl: urls[index],
  //         fit: BoxFit.cover,
  //         placeholder: (context, url) => Container(
  //           color: Colors.grey[300],
  //           child: Center(
  //             child: Container(
  //               width: 30,
  //               height: 30,
  //               child: Image.asset('animation/IdeaBulb.gif', fit: BoxFit.contain),
  //             ),
  //           ),
  //         ),
  //         errorWidget: (context, url, error) => Container(
  //           color: Colors.grey[300],
  //           child: Icon(Icons.error, color: AppColors.whitecolor),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildImageGridItemWithOverlay(List<String> urls, int index) {
  //   return GestureDetector(
  //     onTap: () => _showMediaGallery(urls, index),
  //     child: Stack(
  //       fit: StackFit.expand,
  //       children: [
  //         ClipRRect(
  //           borderRadius: BorderRadius.circular(8),
  //           child: CachedNetworkImage(
  //             imageUrl: urls[index],
  //             fit: BoxFit.cover,
  //           ),
  //         ),
  //         Container(
  //           decoration: BoxDecoration(
  //             color: Colors.black.withOpacity(0.6),
  //             borderRadius: BorderRadius.circular(8),
  //           ),
  //           child: Center(
  //             child: Text(
  //               '+${urls.length - 4}',
  //               style: TextStyle(
  //                 color: AppColors.whitecolor,
  //                 fontSize: 28,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionButton(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LikeButton(
                  contentId: content!.id,
                  initialLikeStatus: content!.engagement.liked,
                  likeService: likeService,
                  onLikeToggled: (isLiked) {
                    setState(() {
                      content!.engagement.liked = isLiked;
                      content!.engagement.likes += isLiked ? 1 : -1;
                    });
                    SoundPlayer().playlikeSound();
                  },
                ),
                const SizedBox(width: 8.0),
                Text(
                  '${content!.engagement.likes}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                    fontSize: 14.0,
                  ),
                ),
              ],
            ),
            onTap: () {},
          ),
          _buildActionButton(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _showComments ? Icons.chat_bubble : Icons.chat_bubble_outline,
                  color:
                      _showComments
                          ? Colors.blue.shade600
                          : Colors.grey.shade600,
                  size: 20.0,
                ),
                const SizedBox(width: 8.0),
                Text(
                  '${content!.engagement.comments}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color:
                        _showComments
                            ? Colors.blue.shade600
                            : Colors.grey.shade700,
                    fontSize: 14.0,
                  ),
                ),
              ],
            ),
            onTap: () {
              setState(() {
                _showComments = !_showComments;
              });
            },
          ),
          _buildActionButton(
            child: Icon(
              Icons.share_outlined,
              color: Colors.grey.shade600,
              size: 20.0,
            ),
            onTap: () => _showShareOptions(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: child,
        ),
      ),
    );
  }

  Widget _buildEngagementInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Icon(Icons.visibility, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            '${content!.views} views',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12.0),
          ),
          if (content!.engagement.engagementRate > 0) ...[
            const SizedBox(width: 16),
            Icon(Icons.trending_up, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              '${content!.engagement.engagementRate.toStringAsFixed(1)}% engagement',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.0),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20.0),
          bottomRight: Radius.circular(20.0),
        ),
      ),
      padding: const EdgeInsets.all(16.0),
      child: CommentSection(
        contentId: content!.id,
        onCommentAdded: () {
          setState(() {
            content!.engagement.comments++;
          });
        },
      ),
    );
  }

  Widget _buildMenuButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: () => _showMenuOptions(context),
        child: Container(
          padding: const EdgeInsets.all(8.0),
          child: Icon(
            Icons.more_horiz_rounded,
            color: Colors.grey.shade600,
            size: 20.0,
          ),
        ),
      ),
    );
  }

  void _showMenuOptions(BuildContext context) {
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.whitecolor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.blue),
                title: const Text('Copy content'),
                onTap: () => Navigator.pop(context, 'copy'),
              ),
              if (!_isAuthorCurrentUser()) ...[
                ListTile(
                  leading: const Icon(Icons.flag, color: Colors.orange),
                  title: const Text('Report'),
                  onTap: () => Navigator.pop(context, 'report'),
                ),
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.red),
                  title: const Text('Block'),
                  onTap: () => Navigator.pop(context, 'block'),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    ).then((value) {
      if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: content!.status));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content copied to clipboard')),
        );
      }
      // Add handlers for report and block if needed
    });
  }

  void _showShareOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: AppColors.whitecolor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Share Post',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: const Icon(Icons.share, color: Colors.blue),
                    title: const Text('Share via Apps'),
                    subtitle: const Text('Share using other apps'),
                    onTap: () {
                      Navigator.pop(context);
                      _shareViaApps();
                    },
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _shareViaApps() async {
    try {
      final shareText =
          'Check out this post by ${content!.author.name}: ${content!.status}';
      await Share.share(shareText);
    } catch (e) {
      debugPrint('Error sharing via apps: $e');
    }
  }

  String _formatMediaUrl(String url) {
    if (url.startsWith('http')) return url;
    return 'http://182.93.94.210:3067$url';
  }

  void _showMediaGallery(List<String> mediaUrls, int initialIndex) {
    final selectedUrl = mediaUrls[initialIndex];

    // If selected item is a video, open fullscreen video player
    if (_isVideoFile(selectedUrl)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) =>
                  FullscreenVideoPage(url: selectedUrl, thumbnail: null),
        ),
      );
      return;
    }

    // For images, open the gallery screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => OptimizedMediaGalleryScreen(
              mediaUrls: mediaUrls,
              initialIndex: initialIndex,
            ),
      ),
    );
  }

  bool _isAuthorCurrentUser() {
    if (AppData().isCurrentUser(content!.author.id)) {
      return true;
    }

    final String? token = AppData().accessToken;
    if (token != null && token.isNotEmpty) {
      try {
        final String? currentUserId = JwtHelper.extractUserId(token);
        if (currentUserId != null) {
          return currentUserId == content!.author.id;
        }
      } catch (e) {
        debugPrint('Error parsing JWT token: $e');
      }
    }
    return false;
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'innovation':
        return Colors.blue.shade600;
      case 'post':
        return Colors.green.shade600;
      case 'photo':
        return Colors.purple.shade600;
      case 'video':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year(s) ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month(s) ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day(s) ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour(s) ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute(s) ago';
    } else {
      return 'Just now';
    }
  }
}

// Data Models
class SpecificPostContent {
  final String id;
  final String status;
  final List<String> files;
  final String type;
  final SpecificPostAuthor author;
  final DateTime createdAt;
  final int views;
  final bool isShared;
  final List<OptimizedFile> optimizedFiles;
  final String contentType;
  final SpecificPostEngagement engagement;
  final SpecificPostMetadata metadata;

  SpecificPostContent({
    required this.id,
    required this.status,
    required this.files,
    required this.type,
    required this.author,
    required this.createdAt,
    required this.views,
    required this.isShared,
    required this.optimizedFiles,
    required this.contentType,
    required this.engagement,
    required this.metadata,
  });

  bool get hasMedia => files.isNotEmpty || optimizedFiles.isNotEmpty;

  factory SpecificPostContent.fromJson(Map<String, dynamic> json) {
    try {
      debugPrint(' Parsing SpecificPostContent');
      debugPrint('   - author type: ${json['author']?.runtimeType}');
      debugPrint('   - engagement type: ${json['engagement']?.runtimeType}');
      debugPrint('   - metadata type: ${json['metadata']?.runtimeType}');

      // CRITICAL FIX: Parse nested objects that might be Strings
      Map<String, dynamic> authorData = _parseNestedJson(
        json['author'],
        'author',
      );
      Map<String, dynamic> engagementData = _parseNestedJson(
        json['engagement'],
        'engagement',
      );
      Map<String, dynamic> metadataData = _parseNestedJson(
        json['metadata'],
        'metadata',
      );

      // Parse optimizedFiles array
      List<OptimizedFile> optimizedFilesList = [];
      if (json['optimizedFiles'] != null) {
        final optimizedFilesRaw = json['optimizedFiles'];
        if (optimizedFilesRaw is String) {
          // If it's a string, parse it
          try {
            final parsed = jsonDecode(optimizedFilesRaw) as List<dynamic>;
            optimizedFilesList =
                parsed
                    .map(
                      (file) =>
                          OptimizedFile.fromJson(file as Map<String, dynamic>),
                    )
                    .toList();
          } catch (e) {
            debugPrint(' Failed to parse optimizedFiles string: $e');
          }
        } else if (optimizedFilesRaw is List) {
          optimizedFilesList =
              (optimizedFilesRaw as List<dynamic>)
                  .map((file) {
                    if (file is String) {
                      try {
                        final parsed = jsonDecode(file) as Map<String, dynamic>;
                        return OptimizedFile.fromJson(parsed);
                      } catch (e) {
                        debugPrint(' Failed to parse optimized file: $e');
                        return null;
                      }
                    } else if (file is Map<String, dynamic>) {
                      return OptimizedFile.fromJson(file);
                    } else if (file is Map) {
                      return OptimizedFile.fromJson(
                        Map<String, dynamic>.from(file as Map),
                      );
                    }
                    return null;
                  })
                  .where((file) => file != null)
                  .cast<OptimizedFile>()
                  .toList();
        }
      }

      return SpecificPostContent(
        id: json['_id'] ?? '',
        status: json['status'] ?? '',
        files: List<String>.from(json['files'] ?? []),
        type: json['type'] ?? '',
        author: SpecificPostAuthor.fromJson(authorData),
        createdAt: DateTime.parse(
          json['createdAt'] ?? DateTime.now().toIso8601String(),
        ),
        views: json['views'] ?? 0,
        isShared: json['isShared'] ?? false,
        optimizedFiles: optimizedFilesList,
        contentType: json['contentType'] ?? '',
        engagement: SpecificPostEngagement.fromJson(engagementData),
        metadata: SpecificPostMetadata.fromJson(metadataData),
      );
    } catch (e, stackTrace) {
      debugPrint(' Error in SpecificPostContent.fromJson: $e');
      debugPrint(' Stack trace: $stackTrace');
      debugPrint('📄 JSON keys: ${json.keys.toList()}');
      rethrow;
    }
  }

  // Helper method to parse nested JSON that might be a String
  static Map<String, dynamic> _parseNestedJson(dynamic data, String fieldName) {
    if (data == null) {
      debugPrint(' $fieldName is null, returning empty map');
      return {};
    }

    if (data is String) {
      debugPrint('🔧 $fieldName is String: "$data"');

      // Special case for author: if it's just a plain string (author name), create a basic author object
      if (fieldName == 'author') {
        debugPrint('Creating basic author object from name string');
        return {'_id': '', 'name': data, 'email': '', 'picture': ''};
      }

      // For other fields, try to parse as JSON
      try {
        final parsed = jsonDecode(data);
        if (parsed is Map<String, dynamic>) {
          return parsed;
        } else if (parsed is Map) {
          return Map<String, dynamic>.from(parsed as Map);
        } else {
          debugPrint(
            ' $fieldName parsed to unexpected type: ${parsed.runtimeType}',
          );
          return {};
        }
      } catch (e) {
        debugPrint(' Failed to parse $fieldName as JSON: $e');
        debugPrint(
          '   Content: ${data.toString().substring(0, math.min(200, data.toString().length))}',
        );
        // Return empty map for non-author fields, or basic author for author field
        return {};
      }
    } else if (data is Map<String, dynamic>) {
      debugPrint('$fieldName is already Map<String, dynamic>');
      return data;
    } else if (data is Map) {
      debugPrint('🔧 $fieldName is generic Map, converting...');
      return Map<String, dynamic>.from(data as Map);
    } else {
      debugPrint(' $fieldName has unexpected type: ${data.runtimeType}');
      return {};
    }
  }
}

class SpecificPostAuthor {
  String id;
  String name;
  String email;
  String picture;

  SpecificPostAuthor({
    required this.id,
    required this.name,
    required this.email,
    required this.picture,
  });

  factory SpecificPostAuthor.fromJson(Map<String, dynamic> json) {
    try {
      return SpecificPostAuthor(
        id: json['_id'] ?? json['id'] ?? '',
        name: json['name'] ?? 'Unknown',
        email: json['email'] ?? '',
        picture: json['picture'] ?? '',
      );
    } catch (e) {
      debugPrint(' Error parsing SpecificPostAuthor: $e');
      return SpecificPostAuthor(
        id: '',
        name: 'Unknown',
        email: '',
        picture: '',
      );
    }
  }
}

class OptimizedFile {
  final String url;
  final String type;
  final String? thumbnail;
  final bool compressed;

  OptimizedFile({
    required this.url,
    required this.type,
    this.thumbnail,
    required this.compressed,
  });

  factory OptimizedFile.fromJson(Map<String, dynamic> json) {
    try {
      return OptimizedFile(
        url: json['url'] ?? '',
        type: json['type'] ?? '',
        thumbnail: json['thumbnail'],
        compressed: json['compressed'] ?? false,
      );
    } catch (e) {
      debugPrint(' Error parsing OptimizedFile: $e');
      // Return default on error
      return OptimizedFile(
        url: '',
        type: '',
        thumbnail: null,
        compressed: false,
      );
    }
  }
}

class SpecificPostEngagement {
  int likes;
  int comments;
  int shares;
  bool liked;
  bool commented;
  bool following;
  double engagementRate;

  SpecificPostEngagement({
    required this.likes,
    required this.comments,
    required this.shares,
    required this.liked,
    required this.commented,
    required this.following,
    required this.engagementRate,
  });

  factory SpecificPostEngagement.fromJson(Map<String, dynamic> json) {
    try {
      return SpecificPostEngagement(
        likes: json['likes'] ?? 0,
        comments: json['comments'] ?? 0,
        shares: json['shares'] ?? 0,
        liked: json['liked'] ?? false,
        commented: json['commented'] ?? false,
        following: json['following'] ?? false,
        engagementRate: (json['engagementRate'] ?? 0.0).toDouble(),
      );
    } catch (e) {
      debugPrint(' Error parsing SpecificPostEngagement: $e');
      // Return default on error
      return SpecificPostEngagement(
        likes: 0,
        comments: 0,
        shares: 0,
        liked: false,
        commented: false,
        following: false,
        engagementRate: 0.0,
      );
    }
  }
}

class SpecificPostMetadata {
  final bool canShare;
  final bool canDownload;
  final String loadPriority;
  final bool isPublic;
  final String processingStatus;

  SpecificPostMetadata({
    required this.canShare,
    required this.canDownload,
    required this.loadPriority,
    required this.isPublic,
    required this.processingStatus,
  });

  factory SpecificPostMetadata.fromJson(Map<String, dynamic> json) {
    try {
      return SpecificPostMetadata(
        canShare: json['canShare'] ?? true,
        canDownload: json['canDownload'] ?? false,
        loadPriority: json['loadPriority'] ?? 'normal',
        isPublic: json['isPublic'] ?? true,
        processingStatus: json['processingStatus'] ?? 'completed',
      );
    } catch (e) {
      debugPrint(' Error parsing SpecificPostMetadata: $e');
      // Return default on error
      return SpecificPostMetadata(
        canShare: true,
        canDownload: false,
        loadPriority: 'normal',
        isPublic: true,
        processingStatus: 'completed',
      );
    }
  }
}

// Enhanced LinkifyText widget for handling URLs in post content
class _LinkifyText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const _LinkifyText({
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final RegExp urlRegExp = RegExp(
      r'(https?:\/\/[^\s]+)',
      caseSensitive: false,
    );

    final List<InlineSpan> spans = [];
    final matches = urlRegExp.allMatches(text);

    int lastMatchEnd = 0;
    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: style,
          ),
        );
      }
      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style:
              style?.copyWith(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ) ??
              const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
          recognizer:
              TapGestureRecognizer()
                ..onTap = () async {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not launch $url')),
                    );
                  }
                },
        ),
      );
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd), style: style));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}
