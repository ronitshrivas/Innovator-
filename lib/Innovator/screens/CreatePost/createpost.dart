import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:innovator/Innovator/screens/Profile/profile_page.dart';
import 'package:innovator/innovator_home.dart';
import 'dart:convert';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  _CreatePostScreenState createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  String? _errorMessage;

  // ── Multi-file support (uploaded_media accepts multiple files) ────────────
  List<PlatformFile> _selectedFiles = [];
  List<XFile> _selectedImages = [];

  bool _isUploading = false;
  bool _isCreatingPost = false;
  bool _isProcessingAI = false;
  final TextEditingController _descriptionController = TextEditingController();
  final AppData _appData = AppData();
  late AnimationController _animationController;
  late Animation<double> _animation;
  final ImagePicker _picker = ImagePicker();

  static const String _baseUrl = 'http://182.93.94.220:8005';

  // GROQ API
  static const String _groqApiKey =
      '***REMOVED***';
  static const String _groqApiUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  // Categories
  List<Map<String, dynamic>> _categories = [];
  bool _categoriesLoading = true;
  List<String> _selectedCategoryIds = [];

  // UI colors
  final Color _primaryColor = const Color.fromRGBO(244, 135, 6, 1);
  final Color _facebookBlue = const Color(0xFF1877F2);
  final Color _backgroundColor = const Color(0xFFF0F2F5);
  final Color _cardColor = Colors.white;
  final Color _textColor = const Color(0xFF333333);

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    _fetchUserProfile();
    _fetchCategories();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _descriptionController.addListener(_updateButtonState);
  }

  void _updateButtonState() {
    if (_isPostButtonEnabled) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
    setState(() {});
  }

  void _checkAuthStatus() => debugPrint('Auth: ${_appData.isAuthenticated}');

  @override
  void dispose() {
    _descriptionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  bool get _isPostButtonEnabled =>
      (_descriptionController.text.isNotEmpty || _selectedFiles.isNotEmpty) &&
      !_isCreatingPost &&
      !_isProcessingAI;

  // ── Categories ────────────────────────────────────────────────────────────

  Future<void> _fetchCategories() async {
    try {
      setState(() => _categoriesLoading = true);
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/categories/'),
            headers: {
              'Content-Type': 'application/json',
              if (_appData.accessToken != null)
                'Authorization': 'Bearer ${_appData.accessToken}',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _categories = data.cast<Map<String, dynamic>>();
          _categoriesLoading = false;
        });
        debugPrint('Loaded ${_categories.length} categories');
      } else {
        setState(() => _categoriesLoading = false);
      }
    } catch (e) {
      setState(() => _categoriesLoading = false);
      debugPrint('Categories error: $e');
    }
  }

  // ── Media pickers — now support multiple files (uploaded_media) ───────────

  Future<void> _captureImage() async {
    try {
      final XFile? captured = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (captured != null) {
        setState(() {
          _selectedImages.add(captured);
          _selectedFiles.add(
            PlatformFile(
              name: captured.name,
              path: captured.path,
              size: File(captured.path).lengthSync(),
            ),
          );
        });
        _updateButtonState();
      }
    } catch (e) {
      _showError('Error capturing image: $e');
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile>? picked = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked != null && picked.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(picked);
          _selectedFiles.addAll(
            picked.map(
              (x) => PlatformFile(
                name: x.name,
                path: x.path,
                size: File(x.path).lengthSync(),
              ),
            ),
          );
        });
        _updateButtonState();
      }
    } catch (e) {
      _showError('Error picking images: $e');
    }
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      if (result != null) {
        setState(() => _selectedFiles.addAll(result.files));
        _updateButtonState();
      }
    } catch (e) {
      _showError('Error picking files: $e');
    }
  }

  Future<void> _takeVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );
      if (video != null) {
        setState(() {
          _selectedFiles.add(
            PlatformFile(
              name: video.name,
              path: video.path,
              size: File(video.path).lengthSync(),
            ),
          );
        });
        _updateButtonState();
      }
    } catch (e) {
      _showError('Error recording video: $e');
    }
  }

  // ── GROQ / ELIZA AI ───────────────────────────────────────────────────────

  Future<String> _callGroqAPI(String message) async {
    final response = await http
        .post(
          Uri.parse(_groqApiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_groqApiKey',
          },
          body: jsonEncode({
            'model': 'llama-3.1-8b-instant',
            'messages': [
              {
                'role': 'system',
                'content':
                    'You are ELIZA, an AI assistant created by Innovator. '
                    'Always respond as ELIZA and never mention Groq, Llama, Meta, Google, Gemini, '
                    'or any other AI system. Enhance the user\'s input to create a polished, '
                    'engaging post for an innovation platform. Keep to exactly 50 words or less.',
              },
              {'role': 'user', 'content': message},
            ],
            'temperature': 0.7,
            'max_tokens': 150,
            'top_p': 1,
            'stream': false,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['choices'][0]['message']['content'];
    }
    throw Exception('API Error: ${response.statusCode}');
  }

  String _validateWordCount(String r) {
    final words = r.trim().split(RegExp(r'\s+'));
    if (words.length <= 50) return r;
    final trimmed = words.take(50).join(' ');
    return trimmed.endsWith('.') ||
            trimmed.endsWith('!') ||
            trimmed.endsWith('?')
        ? trimmed
        : '$trimmed...';
  }

  String _processElizaResponse(String r) => _validateWordCount(
    r
        .replaceAllMapped(
          RegExp(r'\bGemini\b', caseSensitive: false),
          (_) => 'ELIZA',
        )
        .replaceAllMapped(
          RegExp(r'\bGoogle\b', caseSensitive: false),
          (_) => 'Innovator',
        )
        .replaceAllMapped(
          RegExp(r'\bBard\b', caseSensitive: false),
          (_) => 'ELIZA',
        )
        .replaceAllMapped(
          RegExp(r'\bGroq\b', caseSensitive: false),
          (_) => 'Innovator',
        )
        .replaceAllMapped(
          RegExp(r'\bLlama\b', caseSensitive: false),
          (_) => 'ELIZA',
        )
        .replaceAllMapped(
          RegExp(r'\bMeta\b', caseSensitive: false),
          (_) => 'Innovator',
        ),
  );

  Future<void> _enhancePostWithAI() async {
    if (_descriptionController.text.trim().isEmpty || _isProcessingAI) {
      _showError('Please enter some text to enhance');
      return;
    }
    setState(() => _isProcessingAI = true);
    try {
      final processed = _processElizaResponse(
        await _callGroqAPI(_descriptionController.text.trim()),
      );
      setState(() {
        _descriptionController.text = processed;
        _isProcessingAI = false;
      });
      _showSuccess(
        'Post enhanced by ELIZA! (${processed.trim().split(RegExp(r"\s+")).length} words)',
      );
      _updateButtonState();
    } catch (e) {
      _showError('Error enhancing post: $e');
      setState(() => _isProcessingAI = false);
    }
  }

  // ── User profile ──────────────────────────────────────────────────────────

  Future<void> _fetchUserProfile() async {
    try {
      if (AppData().accessToken?.isEmpty ?? true) {
        setState(() {
          _errorMessage = 'Authentication token not found';
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _userData = AppData().currentUser;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  // ── Create post ───────────────────────────────────────────────────────────
  // POST http://182.93.94.220:8005/api/posts/   multipart/form-data
  //
  // Fields (from Postman screenshot):
  //   content          — text
  //   uploaded_media   — file (repeated for multiple files)
  //   catagory_ids     — text  ⚠️ typo in API — must match exactly

  Future<void> _createPost() async {
    if (_descriptionController.text.trim().isEmpty && _selectedFiles.isEmpty) {
      _showError('Please enter a description or select a file');
      return;
    }

    setState(() => _isCreatingPost = true);

    try {
      final uri = Uri.parse('$_baseUrl/api/posts/');
      final request = http.MultipartRequest('POST', uri);

      // Auth
      if (_appData.accessToken != null) {
        request.headers['Authorization'] = 'Bearer ${_appData.accessToken}';
      }

      // content
      request.fields['content'] = _descriptionController.text.trim();

      // catagory_ids — NOTE: intentional typo to match API field name
      if (_selectedCategoryIds.isNotEmpty) {
        request.fields['catagory_ids'] = _selectedCategoryIds.join(',');
      }

      // uploaded_media — multiple files, each added with the same field name
      for (final file in _selectedFiles) {
        if (file.path == null) continue;
        final mimeType =
            lookupMimeType(file.path!) ?? 'application/octet-stream';
        request.files.add(
          await http.MultipartFile.fromPath(
            'uploaded_media', // ← new field name (was 'image')
            file.path!,
            contentType: MediaType.parse(mimeType),
            filename: path.basename(file.path!),
          ),
        );
      }

      debugPrint('[Post] → $uri');
      debugPrint('[Post] fields : ${request.fields}');
      debugPrint(
        '[Post] files  : ${request.files.map((f) => f.filename).toList()}',
      );

      final streamed = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamed);

      debugPrint('[Post] ← ${response.statusCode}: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccess('Post published successfully!');
        _clearForm();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => Homepage()),
          (route) => false,
        );
      } else if (response.statusCode == 401) {
        _showError('Authentication failed. Please log in again.');
      } else {
        Map<String, dynamic> body = {};
        try {
          body = json.decode(response.body) as Map<String, dynamic>;
        } catch (_) {}
        final msg =
            body['detail']?.toString() ??
            body['message']?.toString() ??
            'Failed to create post (${response.statusCode})';
        _showError(msg);
      }
    } catch (e) {
      _showError('Error creating post: $e');
    } finally {
      setState(() => _isCreatingPost = false);
    }
  }

  void _clearForm() {
    setState(() {
      _descriptionController.clear();
      _selectedFiles = [];
      _selectedImages = [];
      _selectedCategoryIds = [];
    });
  }

  void _showError(String message) => Get.snackbar(
    'Error',
    message,
    backgroundColor: Colors.red.shade800,
    colorText: Colors.white,
  );

  void _showSuccess(String message) => Get.snackbar(
    'Success',
    message,
    backgroundColor: Colors.green,
    colorText: Colors.white,
  );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final userData = AppData().currentUser ?? _userData;
    final String name =
        userData?['full_name']?.toString() ??
        userData?['username']?.toString() ??
        userData?['name']?.toString() ??
        'User';
    final String? picturePath =
        userData?['photo_url']?.toString() ?? userData?['picture']?.toString();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 15),

                // ── Compose area ───────────────────────────────────────────────
                Container(
                  constraints: const BoxConstraints(minHeight: 400),
                  color: _cardColor,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar
                          GestureDetector(
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => UserProfileScreen(
                                          userId: AppData().currentUserId ?? '',
                                        ),
                                  ),
                                ),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.grey[200],
                              backgroundImage:
                                  picturePath != null && picturePath.isNotEmpty
                                      ? NetworkImage(
                                        picturePath.startsWith('http')
                                            ? picturePath
                                            : '$_baseUrl$picturePath',
                                      )
                                      : null,
                              child:
                                  (picturePath == null || picturePath.isEmpty)
                                      ? const Icon(
                                        Icons.person,
                                        size: 40,
                                        color: Colors.grey,
                                      )
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Name + category selector
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: _textColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _buildCategorySelector(),
                              ],
                            ),
                          ),

                          // ELIZA AI button
                          IconButton(
                            onPressed:
                                _isProcessingAI ? null : _enhancePostWithAI,
                            icon:
                                _isProcessingAI
                                    ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.blue,
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : Image.asset(
                                      'animation/AI.gif',
                                      width: 50,
                                    ),
                            tooltip: 'Enhance with ELIZA AI (50 words max)',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Text field
                      TextField(
                        controller: _descriptionController,
                        style: TextStyle(color: _textColor, fontSize: 18),
                        maxLines: 8,
                        minLines: 3,
                        decoration: InputDecoration(
                          hintText: "What's on your mind?",
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 18,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Media buttons ──────────────────────────────────────────────
                Container(
                  color: _cardColor,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add to your post',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _mediaButton(
                              icon: Icons.camera_alt,
                              color: Colors.purple,
                              label: 'Camera',
                              onTap: _captureImage,
                            ),
                            _mediaButton(
                              icon: Icons.videocam,
                              color: Colors.red,
                              label: 'Video',
                              onTap: _takeVideo,
                            ),
                            _mediaButton(
                              icon: Icons.photo_library,
                              color: Colors.green,
                              label: 'Photos',
                              onTap: _pickImages,
                            ),
                            _mediaButton(
                              icon: Icons.attach_file,
                              color: Colors.blue,
                              label: 'Files',
                              onTap: _pickFiles,
                            ),
                          ],
                        ),
                      ),

                      // Uploading indicator
                      if (_selectedFiles.isNotEmpty && _isUploading) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: _facebookBlue,
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Uploading files...',
                              style: TextStyle(
                                color: _facebookBlue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Selected files preview
                      if (_selectedFiles.isNotEmpty && !_isUploading) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Selected Files (${_selectedFiles.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedFiles.length,
                            itemBuilder: (context, index) {
                              final file = _selectedFiles[index];
                              final isImage =
                                  file.path != null &&
                                  [
                                    'jpg',
                                    'jpeg',
                                    'png',
                                    'gif',
                                    'webp',
                                  ].contains(file.extension?.toLowerCase());
                              return Container(
                                width: 100,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    if (isImage && file.path != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(file.path!),
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    else
                                      Center(
                                        child: Icon(
                                          _getFileIcon(file.extension),
                                          size: 36,
                                          color: _facebookBlue,
                                        ),
                                      ),
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedFiles.removeAt(index);
                                            if (index <
                                                _selectedImages.length) {
                                              _selectedImages.removeAt(index);
                                            }
                                          });
                                          _updateButtonState();
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.5,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isPostButtonEnabled ? _createPost : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _facebookBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade500,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      _isCreatingPost
                          ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Publishing...',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          )
                          : const Text(
                            'Publish',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Category selector ─────────────────────────────────────────────────────

  Widget _buildCategorySelector() {
    if (_categoriesLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Loading categories...', style: TextStyle(fontSize: 12)),
          ],
        ),
      );
    }

    if (_categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('No categories', style: TextStyle(fontSize: 12)),
      );
    }

    // Auto-select first on load
    if (_selectedCategoryIds.isEmpty && _categories.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedCategoryIds.isEmpty) {
          setState(
            () => _selectedCategoryIds = [_categories.first['id'].toString()],
          );
        }
      });
    }

    final displayId =
        _selectedCategoryIds.isNotEmpty
            ? _selectedCategoryIds.first
            : _categories.first['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: displayId.isNotEmpty ? displayId : null,
              icon: const Icon(Icons.arrow_drop_down),
              elevation: 16,
              style: TextStyle(color: _textColor),
              isDense: true,
              isExpanded: false,
              borderRadius: BorderRadius.circular(12),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  if (_selectedCategoryIds.contains(value)) {
                    _selectedCategoryIds.remove(value);
                    if (_selectedCategoryIds.isEmpty &&
                        _categories.isNotEmpty) {
                      _selectedCategoryIds = [
                        _categories.first['id'].toString(),
                      ];
                    }
                  } else {
                    _selectedCategoryIds.add(value);
                  }
                });
              },
              items:
                  _categories.map<DropdownMenuItem<String>>((cat) {
                    final id = cat['id']?.toString() ?? '';
                    final name = cat['name']?.toString() ?? '';
                    final sel = _selectedCategoryIds.contains(id);
                    return DropdownMenuItem<String>(
                      value: id,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            sel
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            size: 18,
                            color: sel ? _primaryColor : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(name),
                        ],
                      ),
                    );
                  }).toList(),
            ),
          ),
          if (_selectedCategoryIds.length > 1) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children:
                  _selectedCategoryIds.map((id) {
                    final cat = _categories.firstWhereOrNull(
                      (c) => c['id']?.toString() == id,
                    );
                    if (cat == null) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _primaryColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _primaryColor.withAlpha(80)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cat['name']?.toString() ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              color: _primaryColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap:
                                () => setState(() {
                                  _selectedCategoryIds.remove(id);
                                  if (_selectedCategoryIds.isEmpty &&
                                      _categories.isNotEmpty) {
                                    _selectedCategoryIds = [
                                      _categories.first['id'].toString(),
                                    ];
                                  }
                                }),
                            child: Icon(
                              Icons.close,
                              size: 12,
                              color: _primaryColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _mediaButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    ),
  );

  IconData _getFileIcon(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'mp3':
      case 'wav':
      case 'ogg':
        return Icons.music_note;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.video_file;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }
}
