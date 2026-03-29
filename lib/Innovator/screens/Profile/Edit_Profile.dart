import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/constant/api_constants.dart';
import 'package:innovator/Innovator/constant/app_colors.dart';
import 'package:innovator/innovator_home.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'package:innovator/Innovator/controllers/user_controller.dart';
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';

// ── API constants ─────────────────────────────────────────────────────────────

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final _formKey = GlobalKey<FormState>();

  // ── Controllers (new API field names) ────────────────────────────────────
  late TextEditingController _fullNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _educationCtrl;
  late TextEditingController _occupationCtrl;
  late TextEditingController _hobbiesCtrl;

  String? _selectedGender;
  DateTime? _selectedDob;
  bool _isLoading = false;
  bool _isUploading = false;
  String? _errorMessage;
  File? _selectedImage;
  String? _currentAvatarUrl; // full URL, ready for NetworkImage

  final UserController _userController = Get.put(UserController());

  // ── Theme ─────────────────────────────────────────────────────────────────
  static const Color _primary = Color.fromRGBO(244, 135, 6, 1);
  static const Color _primaryLight = Color.fromRGBO(235, 111, 70, 0.10);
  static const Color _bg = Color(0xFFF8F9FA);

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadUserData();

    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _bioCtrl.dispose();
    _educationCtrl.dispose();
    _occupationCtrl.dispose();
    _hobbiesCtrl.dispose();
    super.dispose();
  }

  void _initControllers() {
    _fullNameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _bioCtrl = TextEditingController();
    _educationCtrl = TextEditingController();
    _occupationCtrl = TextEditingController();
    _hobbiesCtrl = TextEditingController();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Load cached user data into the form
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadUserData() async {
    final appData = AppData();
    await appData.initialize();
    final u = appData.currentUser ?? {};

    // The new API stores profile fields both at the root ("full_name") and
    // nested under "profile" (after a /api/users/me/ call).
    final profile = u['profile'] as Map<String, dynamic>? ?? {};

    setState(() {
      _fullNameCtrl.text = u['full_name']?.toString() ?? '';
      _phoneCtrl.text =
          profile['phone_number']?.toString() ??
          u['phone_number']?.toString() ??
          '';
      _addressCtrl.text =
          profile['address']?.toString() ?? u['address']?.toString() ?? '';
      _bioCtrl.text = profile['bio']?.toString() ?? u['bio']?.toString() ?? '';
      _educationCtrl.text =
          profile['education']?.toString() ?? u['education']?.toString() ?? '';
      _occupationCtrl.text =
          profile['occupation']?.toString() ??
          u['occupation']?.toString() ??
          '';
      _hobbiesCtrl.text =
          profile['hobbies']?.toString() ?? u['hobbies']?.toString() ?? '';

      _selectedGender =
          profile['gender']?.toString() ?? u['gender']?.toString();

      final dobRaw =
          profile['date_of_birth']?.toString() ??
          u['date_of_birth']?.toString();
      if (dobRaw != null && dobRaw.isNotEmpty) {
        try {
          _selectedDob = DateTime.parse(dobRaw);
        } catch (_) {}
      }

      // Avatar: prefer the post-upload flat field, then nested profile.avatar
      final avatarPath =
          appData.currentUserAvatar ??
          profile['avatar']?.toString() ??
          u['photo_url']?.toString();
      _currentAvatarUrl = _resolveUrl(avatarPath);
    });
  }

  /// Turns a relative path into an absolute URL if needed.
  String? _resolveUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return '${ApiConstants.userBase}$raw';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Image picker
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (image == null) return;
      setState(() => _selectedImage = File(image.path));
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Avatar upload  POST /api/users/me/avatar/
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> _uploadAvatar(File imageFile) async {
    final token = AppData().accessToken ?? '';
    final filename = path.basename(imageFile.path);
    final mimeType =
        filename.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

    final request =
        http.MultipartRequest('POST', Uri.parse(ApiConstants.avatarurl))
          ..headers['Authorization'] = 'Bearer $token'
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
    developer.log(
      '[EditProfile] Avatar upload ${response.statusCode}: ${response.body}',
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // API may return avatar at root or nested under data
      final avatarPath =
          data['avatar']?.toString() ??
          data['data']?['avatar']?.toString() ??
          data['data']?['photo_url']?.toString() ??
          '';
      if (avatarPath.isEmpty) throw Exception('No avatar URL in response');
      return avatarPath;
    }
    throw Exception('Avatar upload failed (${response.statusCode})');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Profile update  PATCH /api/profile/
  // Fields: full_name, phone_number, gender, date_of_birth, address,
  //         bio, education, occupation, hobbies
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final appData = AppData();

      // ── 1. Upload avatar if a new one was picked ─────────────────────────
      if (_selectedImage != null) {
        setState(() => _isUploading = true);
        try {
          final newAvatarPath = await _uploadAvatar(_selectedImage!);
          final fullUrl = _resolveUrl(newAvatarPath)!;

          // Evict old cached image
          if (_currentAvatarUrl != null) {
            imageCache.evict(NetworkImage(_currentAvatarUrl!));
          }

          // Persist + sync controller
          await appData.updateProfilePicture(newAvatarPath);
          _userController.updateProfilePicture(newAvatarPath);
          _userController.profilePictureVersion.value++;

          setState(() => _currentAvatarUrl = fullUrl);
        } finally {
          setState(() => _isUploading = false);
        }
      }

      // ── 2. PATCH /api/profile/ ───────────────────────────────────────────
      // Only include a field if the user actually filled it in.
      // PATCH means "update only what I send" — omitting a field leaves it unchanged.
      String? _valOrNull(String s) => s.isEmpty ? null : s;

      final body = <String, dynamic>{
        'full_name': _fullNameCtrl.text.trim(), // always required
      };

      void _addIfFilled(String key, String value) {
        final v = _valOrNull(value);
        if (v != null) body[key] = v;
      }

      _addIfFilled('phone_number', _phoneCtrl.text.trim());
      _addIfFilled('address', _addressCtrl.text.trim());
      _addIfFilled('bio', _bioCtrl.text.trim());
      _addIfFilled('education', _educationCtrl.text.trim());
      _addIfFilled('occupation', _occupationCtrl.text.trim());
      _addIfFilled('hobbies', _hobbiesCtrl.text.trim());

      if (_selectedGender != null) body['gender'] = _selectedGender;
      if (_selectedDob != null)
        body['date_of_birth'] = DateFormat('yyyy-MM-dd').format(_selectedDob!);

      developer.log('[EditProfile] PATCH ${ApiConstants.profile}  body: $body');

      final response = await http.patch(
        Uri.parse(ApiConstants.profile),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${appData.accessToken}',
        },
        body: jsonEncode(body),
      );

      developer.log(
        '[EditProfile] PATCH response ${response.statusCode}: ${response.body}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // ── 3. Merge updated fields back into AppData ────────────────────
        final updated = jsonDecode(response.body) as Map<String, dynamic>;
        await appData.setCurrentUser({
          ...?appData.currentUser,
          // Keep the flat user-level full_name in sync
          'full_name': _fullNameCtrl.text.trim(),
          // Store the profile response under 'profile' key
          'profile': {
            ...?appData.currentUser?['profile'] as Map<String, dynamic>?,
            ...updated,
          },
        });

        // Sync UserController name
        _userController.updateUserName(_fullNameCtrl.text.trim());

        _showSuccess('Profile updated successfully');
        Navigator.push(context, MaterialPageRoute(builder: (_) => Homepage()));
      } else {
        final errBody = jsonDecode(response.body);
        final msg =
            errBody is Map
                ? (errBody.values.first is List
                    ? (errBody.values.first as List).first.toString()
                    : errBody.values.first.toString())
                : response.body;
        setState(() => _errorMessage = msg);
      }
    } catch (e) {
      developer.log('[EditProfile] Error: $e');
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.whitecolor),
            const SizedBox(width: 8),
            Text(msg),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.whitecolor),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _selectDob(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder:
          (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                primary: _primary,
                onPrimary: AppColors.whitecolor,
              ),
            ),
            child: child!,
          ),
    );
    if (picked != null) setState(() => _selectedDob = picked);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Widgets
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: _bg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.whitecolor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back, color: _primary),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Update Profile',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => Homepage()),
                );
              },
              child: const Text('Skip', style: TextStyle(color: _primary)),
            ),
          ],
        ),
        body: Stack(
          children: [
            FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    children: [
                      // ── Avatar section ─────────────────────────────────
                      _buildAvatarSection(),

                      // ── Error banner ────────────────────────────────────
                      if (_errorMessage != null)
                        _buildErrorBanner(_errorMessage!),

                      // ── Form ────────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _section('Personal Information', [
                                _field(
                                  ctrl: _fullNameCtrl,
                                  label: 'Full Name',
                                  icon: Icons.person,
                                  required: true,
                                  validator:
                                      (v) =>
                                          v == null || v.trim().isEmpty
                                              ? 'Enter your full name'
                                              : null,
                                ),
                                _field(
                                  ctrl: _phoneCtrl,
                                  label: 'Phone Number',
                                  icon: Icons.phone,
                                  keyboard: TextInputType.phone,
                                ),
                                _genderDropdown(),
                                _dobPicker(),
                                _field(
                                  ctrl: _addressCtrl,
                                  label: 'Address',
                                  icon: Icons.location_on,
                                  hint: 'City, Country',
                                ),
                              ]),

                              _section('Professional Information', [
                                _field(
                                  ctrl: _educationCtrl,
                                  label: 'Education',
                                  icon: Icons.school,
                                  hint: 'e.g. Bsc. CSIT',
                                ),
                                _field(
                                  ctrl: _occupationCtrl,
                                  label: 'Occupation',
                                  icon: Icons.work,
                                  hint: 'e.g. Software Engineer',
                                ),
                              ]),

                              _section('About You', [
                                _field(
                                  ctrl: _bioCtrl,
                                  label: 'Bio',
                                  icon: Icons.edit,
                                  hint: 'Tell us about yourself…',
                                  maxLines: 4,
                                ),
                                _field(
                                  ctrl: _hobbiesCtrl,
                                  label: 'Hobbies',
                                  icon: Icons.interests,
                                  hint: 'e.g. Reading, Hiking, Coding',
                                ),
                              ]),

                              const SizedBox(height: 28),

                              // ── Save button ──────────────────────────────
                              _saveButton(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Full-screen loading overlay
            if (_isLoading)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: _primary),
                          SizedBox(height: 16),
                          Text('Saving profile…'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Avatar section ─────────────────────────────────────────────────────────
  Widget _buildAvatarSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: _primaryLight,
                  backgroundImage:
                      _selectedImage != null
                          ? FileImage(_selectedImage!) as ImageProvider
                          : (_currentAvatarUrl != null
                              ? NetworkImage(_currentAvatarUrl!)
                              : null),
                  child:
                      (_selectedImage == null && _currentAvatarUrl == null)
                          ? const Icon(Icons.person, size: 60, color: _primary)
                          : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUploading ? null : _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.whitecolor, width: 3),
                    ),
                    child:
                        _isUploading
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: AppColors.whitecolor,
                                strokeWidth: 2,
                              ),
                            )
                            : const Icon(
                              Icons.camera_alt,
                              color: AppColors.whitecolor,
                              size: 18,
                            ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Tap to change profile picture',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ── Error banner ───────────────────────────────────────────────────────────
  Widget _buildErrorBanner(String msg) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card section ───────────────────────────────────────────────────────────
  Widget _section(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.whitecolor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _primary,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // ── Reusable text field ────────────────────────────────────────────────────
  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    String? hint,
    bool required = false,
    TextInputType? keyboard,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _primary, size: 20),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primary, width: 1.8),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          labelStyle: TextStyle(color: Colors.grey.shade600),
          hintStyle: TextStyle(color: Colors.grey.shade400),
        ),
      ),
    );
  }

  // ── Gender dropdown ────────────────────────────────────────────────────────
  Widget _genderDropdown() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _selectedGender,
        decoration: InputDecoration(
          labelText: 'Gender',
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.person_outline, color: _primary, size: 20),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primary, width: 1.8),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        items:
            [
              'Male',
              'Female',
              'Other',
              'Prefer not to say',
            ].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
        onChanged: (v) => setState(() => _selectedGender = v),
      ),
    );
  }

  // ── DOB picker ─────────────────────────────────────────────────────────────
  Widget _dobPicker() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _selectDob(context),
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Date of Birth',
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.calendar_today,
                color: _primary,
                size: 20,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          child: Text(
            _selectedDob != null
                ? DateFormat('MMM dd, yyyy').format(_selectedDob!)
                : 'Select date of birth',
            style: TextStyle(
              color:
                  _selectedDob != null ? Colors.black87 : Colors.grey.shade400,
            ),
          ),
        ),
      ),
    );
  }

  // ── Save button ────────────────────────────────────────────────────────────
  Widget _saveButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [_primary, Color.fromRGBO(255, 131, 90, 1)],
        ),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _updateProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.save, color: AppColors.whitecolor),
            SizedBox(width: 8),
            Text(
              'Save Changes',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.whitecolor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
