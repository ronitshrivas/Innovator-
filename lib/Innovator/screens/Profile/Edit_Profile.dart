import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/screens/Profile/profile_page.dart';
import 'package:innovator/Innovator/widget/FloatingMenuwidget.dart';
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

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  //late Future<UserProfile> profile;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;
  late TextEditingController _educationController;
  late TextEditingController _professionController;
  late TextEditingController _achievementsController;
  late TextEditingController _locationController;

  String? _selectedGender;
  DateTime? _selectedDob;
  bool _isLoading = false;
  bool _isUploading = false;
  String? _errorMessage;
  bool _isFromGoogleSignup = false;
  File? _selectedImage;
  String? _currentProfilePicture;
  final UserController _userController = Get.put(UserController());

  // Theme colors
  static const Color primaryColor = Color.fromRGBO(244, 135, 6, 1);
  static const Color primaryColorLight = Color.fromRGBO(235, 111, 70, 0.1);
  static const Color cardColor = Colors.white;
  static const Color backgroundColor = Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    // profile = UserProfileService.getUserProfile();
    _initializeControllers();
    _loadUserData();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _bioController = TextEditingController();
    _educationController = TextEditingController();
    _professionController = TextEditingController();
    _achievementsController = TextEditingController();
    _locationController = TextEditingController();
  }

  Future<void> _loadUserData() async {
    final appData = AppData();
    await appData.initialize();

    setState(() {
      _nameController.text = appData.currentUser?['name'] ?? '';
      _emailController.text = appData.currentUser?['email'] ?? '';
      _phoneController.text = appData.currentUser?['phone'] ?? '';
      _bioController.text = appData.currentUser?['bio'] ?? '';
      _educationController.text = appData.currentUser?['education'] ?? '';
      _professionController.text = appData.currentUser?['profession'] ?? '';
      _achievementsController.text = appData.currentUser?['achievements'] ?? '';
      _locationController.text = appData.currentUser?['location'] ?? '';
      _selectedGender = appData.currentUser?['gender'];

      if (appData.currentUser?['dob'] != null) {
        try {
          _selectedDob = DateTime.parse(appData.currentUser!['dob']);
        } catch (e) {
          developer.log('Error parsing DOB: $e');
        }
      }

      _currentProfilePicture =
          appData.currentUser?['photoURL'] ?? appData.currentUser?['picture'];

      _isFromGoogleSignup = _isProfileIncomplete();

      developer.log('═══════════════════════════════════════');
      developer.log('PROFILE DATA LOADED:');
      developer.log('Current profile picture: $_currentProfilePicture');
      developer.log('Is from Google signup: $_isFromGoogleSignup');
      developer.log('═══════════════════════════════════════');
    });
  }

  bool _isProfileIncomplete() {
    final appData = AppData();

    final hasProfilePicture =
        (appData.currentUser?['photoURL'] != null &&
            appData.currentUser!['photoURL'].toString().isNotEmpty) ||
        (appData.currentUser?['picture'] != null &&
            appData.currentUser!['picture'].toString().isNotEmpty);

    final hasPhone =
        appData.currentUser?['phone'] != null &&
        appData.currentUser!['phone'].toString().trim().isNotEmpty;
    final hasGender =
        appData.currentUser?['gender'] != null &&
        appData.currentUser!['gender'].toString().trim().isNotEmpty;
    final hasDob =
        appData.currentUser?['dob'] != null &&
        appData.currentUser!['dob'].toString().trim().isNotEmpty;
    final hasLocation =
        appData.currentUser?['location'] != null &&
        appData.currentUser!['location'].toString().trim().isNotEmpty;

    developer.log('════════════ PROFILE COMPLETENESS CHECK ════════════');
    developer.log('  Has Picture: $hasProfilePicture');
    developer.log('  Has Phone: $hasPhone');
    developer.log('  Has Gender: $hasGender');
    developer.log('  Has DOB: $hasDob');
    developer.log('  Has Location: $hasLocation');
    developer.log(
      '  Profile Incomplete: ${!hasProfilePicture || !hasPhone || !hasGender || !hasDob || !hasLocation}',
    );
    developer.log('════════════════════════════════════════════════════');

    return !hasProfilePicture ||
        !hasPhone ||
        !hasGender ||
        !hasDob ||
        !hasLocation;
  }

  Future<void> _pickImage() async {
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
        _selectedImage = File(image.path);
      });

      developer.log('Image selected: ${image.path}');
    } catch (e) {
      developer.log(' Error picking image: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(_buildErrorSnackBar('Failed to pick image: $e'));
    }
  }

  Future<String?> _uploadProfilePicture(File imageFile) async {
    final token = AppData().accessToken;

    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found');
    }

    final filename = path.basename(imageFile.path);
    final url = Uri.parse(
      'http://182.93.94.210:3067/api/v1/set-avatar?filename=avatar.png',
    );

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

      developer.log('📤 Uploading profile picture...');
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      developer.log(
        'Avatar upload response: ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 200 && data['data'] != null) {
          final picturePath = data['data']['picture'] ?? '';
          developer.log('Picture uploaded successfully: $picturePath');
          return picturePath;
        } else {
          throw Exception('Failed to get picture URL from response');
        }
      } else {
        throw Exception('Failed to upload avatar: ${response.statusCode}');
      }
    } catch (e) {
      developer.log(' Error uploading avatar: $e');
      throw Exception('Avatar upload failed: $e');
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isFromGoogleSignup) {
      if (_selectedImage == null &&
          (_currentProfilePicture == null || _currentProfilePicture!.isEmpty)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(_buildErrorSnackBar('Profile picture is required'));
        return;
      }
      if (_phoneController.text.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(_buildErrorSnackBar('Phone number is required'));
        return;
      }
      if (_selectedGender == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(_buildErrorSnackBar('Gender is required'));
        return;
      }
      if (_selectedDob == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(_buildErrorSnackBar('Date of birth is required'));
        return;
      }
      if (_locationController.text.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(_buildErrorSnackBar('Location is required'));
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final appData = AppData();
      String? uploadedPicturePath = _currentProfilePicture;

      if (_selectedImage != null) {
        setState(() {
          _isUploading = true;
        });

        try {
          if (_currentProfilePicture != null) {
            imageCache.evict(NetworkImage(_currentProfilePicture!));
            final fullPath =
                _currentProfilePicture!.startsWith('http')
                    ? _currentProfilePicture!
                    : 'http://182.93.94.210:3067$_currentProfilePicture';
            imageCache.evict(NetworkImage(fullPath));
          }

          uploadedPicturePath = await _uploadProfilePicture(_selectedImage!);
          developer.log('Profile picture uploaded: $uploadedPicturePath');

          _userController.updateProfilePicture(uploadedPicturePath!);
          await appData.updateProfilePicture(uploadedPicturePath);
          _userController.profilePictureVersion.value++;
        } catch (e) {
          developer.log(' Error uploading profile picture: $e');
          setState(() {
            _errorMessage = 'Failed to upload profile picture: $e';
            _isLoading = false;
            _isUploading = false;
          });
          return;
        } finally {
          setState(() {
            _isUploading = false;
          });
        }
      }

      final url = Uri.parse('http://182.93.94.210:3067/api/v1/set-details');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${appData.accessToken}',
      };

      final body = jsonEncode({
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'bio': _bioController.text,
        'education': _educationController.text,
        'profession': _professionController.text,
        'achievements': _achievementsController.text,
        'location': _locationController.text,
        'gender': _selectedGender,
        'dob': _selectedDob?.toIso8601String(),
      });

      developer.log('📤 Updating profile with data: $body');

      final response = await http.post(url, headers: headers, body: body);

      developer.log(
        'Profile update response: ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await appData.setCurrentUser({
          ...?appData.currentUser,
          'name': _nameController.text,
          'email': _emailController.text,
          'phone': _phoneController.text,
          'bio': _bioController.text,
          'education': _educationController.text,
          'profession': _professionController.text,
          'achievements': _achievementsController.text,
          'location': _locationController.text,
          'gender': _selectedGender,
          'dob': _selectedDob?.toIso8601String(),
          if (uploadedPicturePath != null) 'picture': uploadedPicturePath,
          if (uploadedPicturePath != null) 'photoURL': uploadedPicturePath,
        });

        developer.log('Profile updated successfully');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Profile updated successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        if (_isFromGoogleSignup) {
          developer.log(
            '🏠 Navigating to Homepage after completing Google signup profile',
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => Homepage()),
            (route) => false,
          );
        } else {
          developer.log('⬅️ Navigating back after profile update');
          Navigator.pop(context);
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to update profile: ${response.body}';
        });
      }
    } catch (e) {
      developer.log(' Error updating profile: $e');
      setState(() {
        _errorMessage = 'Error updating profile: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  SnackBar _buildErrorSnackBar(String message) {
    return SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Future<void> _selectDob(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDob) {
      setState(() {
        _selectedDob = picked;
      });
    }
  }

  Widget _buildProfilePictureSection() {
    String? displayImagePath;
    if (_currentProfilePicture != null && _currentProfilePicture!.isNotEmpty) {
      displayImagePath =
          _currentProfilePicture!.startsWith('http')
              ? _currentProfilePicture
              : 'http://182.93.94.210:3067$_currentProfilePicture';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: primaryColorLight,
                  backgroundImage:
                      _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : (displayImagePath != null
                              ? NetworkImage(displayImagePath)
                              : null),
                  child:
                      (_selectedImage == null && displayImagePath == null)
                          ? const Icon(
                            Icons.person,
                            size: 60,
                            color: primaryColor,
                          )
                          : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUploading ? null : _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child:
                        _isUploading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isFromGoogleSignup
                ? 'Profile Picture *'
                : 'Tap camera icon to change profile picture',
            style: TextStyle(
              fontSize: 14,
              color:
                  _isFromGoogleSignup
                      ? Colors.red.shade700
                      : Colors.grey.shade600,
              fontWeight:
                  _isFromGoogleSignup ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (_isFromGoogleSignup &&
              _selectedImage == null &&
              (displayImagePath == null))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Profile picture is required',
                style: TextStyle(fontSize: 12, color: Colors.red.shade600),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _educationController.dispose();
    _professionController.dispose();
    _achievementsController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hintText,
    bool isRequired = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          hintText: hintText,
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColorLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: primaryColor, size: 20),
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
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: isRequired ? FontWeight.w600 : FontWeight.normal,
          ),
          hintStyle: TextStyle(color: Colors.grey.shade400),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildProfilePictureSection(),
          const SizedBox(height: 16),
          Text(
            _isFromGoogleSignup ? 'Complete Your Profile' : 'Edit Your Profile',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isFromGoogleSignup
                ? 'Please fill in all required fields (marked with *) to continue'
                : 'Update your information to keep your profile current',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isFromGoogleSignup) {
          ScaffoldMessenger.of(context).showSnackBar(
            _buildErrorSnackBar('Please complete your profile to continue'),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: backgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading:
              _isFromGoogleSignup
                  ? null
                  : IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back, color: primaryColor),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
          title: const Text(
            'Edit Profile',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            if (_isLoading)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: primaryColor),
                          SizedBox(height: 16),
                          Text('Updating profile...'),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildProfileHeader(),

                        if (_errorMessage != null)
                          Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade600,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                _buildFormSection('Personal Information', [
                                  _buildCustomTextField(
                                    controller: _nameController,
                                    label: 'Full Name',
                                    icon: Icons.person,
                                    isRequired: true,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your name';
                                      }
                                      return null;
                                    },
                                  ),
                                  _buildCustomTextField(
                                    controller: _emailController,
                                    label: 'Email Address',
                                    icon: Icons.email,
                                    keyboardType: TextInputType.emailAddress,
                                    isRequired: true,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your email';
                                      }
                                      if (!RegExp(
                                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                      ).hasMatch(value)) {
                                        return 'Please enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                  _buildCustomTextField(
                                    controller: _phoneController,
                                    label: 'Phone Number',
                                    icon: Icons.phone,
                                    keyboardType: TextInputType.phone,
                                    isRequired: _isFromGoogleSignup,
                                    validator:
                                        _isFromGoogleSignup
                                            ? (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'Please enter your phone number';
                                              }
                                              return null;
                                            }
                                            : null,
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 20),
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedGender,
                                      decoration: InputDecoration(
                                        labelText:
                                            _isFromGoogleSignup
                                                ? 'Gender *'
                                                : 'Gender',
                                        hintText: 'Select your gender',
                                        prefixIcon: Container(
                                          margin: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: primaryColorLight,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.person_outline,
                                            color: primaryColor,
                                            size: 20,
                                          ),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: primaryColor,
                                            width: 2,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                      ),
                                      items:
                                          ['Male', 'Female', 'Other']
                                              .map(
                                                (gender) => DropdownMenuItem(
                                                  value: gender,
                                                  child: Text(gender),
                                                ),
                                              )
                                              .toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedGender = value;
                                        });
                                      },
                                      validator:
                                          _isFromGoogleSignup
                                              ? (value) {
                                                if (value == null) {
                                                  return 'Please select your gender';
                                                }
                                                return null;
                                              }
                                              : null,
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 20),
                                    child: InkWell(
                                      onTap: () => _selectDob(context),
                                      child: InputDecorator(
                                        decoration: InputDecoration(
                                          labelText:
                                              _isFromGoogleSignup
                                                  ? 'Date of Birth *'
                                                  : 'Date of Birth',
                                          hintText: 'Select your date of birth',
                                          prefixIcon: Container(
                                            margin: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: primaryColorLight,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.calendar_today,
                                              color: primaryColor,
                                              size: 20,
                                            ),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: primaryColor,
                                              width: 2,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                        ),
                                        child: Text(
                                          _selectedDob != null
                                              ? DateFormat(
                                                'MMM dd, yyyy',
                                              ).format(_selectedDob!)
                                              : 'Select Date of Birth',
                                          style: TextStyle(
                                            color:
                                                _selectedDob != null
                                                    ? Colors.black87
                                                    : Colors.grey.shade400,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  _buildCustomTextField(
                                    controller: _locationController,
                                    label: 'Location',
                                    icon: Icons.location_on,
                                    hintText: 'City, Country',
                                    isRequired: _isFromGoogleSignup,
                                    validator:
                                        _isFromGoogleSignup
                                            ? (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'Please enter your location';
                                              }
                                              return null;
                                            }
                                            : null,
                                  ),
                                ]),

                                _buildFormSection('Professional Information', [
                                  _buildCustomTextField(
                                    controller: _educationController,
                                    label: 'Education',
                                    icon: Icons.school,
                                    hintText: 'Your educational background',
                                  ),
                                  _buildCustomTextField(
                                    controller: _professionController,
                                    label: 'Profession',
                                    icon: Icons.work,
                                    hintText: 'Your current profession',
                                  ),
                                  _buildCustomTextField(
                                    controller: _achievementsController,
                                    label: 'Achievements',
                                    icon: Icons.star,
                                    maxLines: 3,
                                    hintText:
                                        'Share your notable achievements...',
                                  ),
                                ]),

                                _buildFormSection('About You', [
                                  _buildCustomTextField(
                                    controller: _bioController,
                                    label: 'Bio',
                                    icon: Icons.edit,
                                    maxLines: 4,
                                    hintText: 'Tell us about yourself...',
                                  ),
                                ]),

                                const SizedBox(height: 20),

                                Container(
                                  width: double.infinity,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: const LinearGradient(
                                      colors: [
                                        primaryColor,
                                        Color.fromRGBO(255, 131, 90, 1),
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryColor.withOpacity(0.3),
                                        blurRadius: 15,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed:
                                        _isLoading ? null : _updateProfile,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.save,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _isFromGoogleSignup
                                              ? 'Complete Profile'
                                              : 'Save Changes',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // if (!_isFromGoogleSignup) FloatingMenuWidget(),
          ],
        ),
      ),
    );
  }
}
