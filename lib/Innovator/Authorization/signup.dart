import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/Authorization/Login.dart';
import 'package:innovator/Innovator/Authorization/OTP_Validation.dart';
import 'package:innovator/Innovator/constant/api_constants.dart';
import 'package:innovator/Innovator/helper/dialogs.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final Color preciseGreen = const Color.fromRGBO(244, 135, 6, 1);

  bool _isPasswordVisible = false;
  bool isLoading = false;
  bool rememberMe = false;

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController genderController = TextEditingController();

  String completePhoneNumber = '';
  DateTime? selectedDate;

  @override
  void dispose() {
    usernameController.dispose();
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    addressController.dispose();
    dobController.dispose();
    genderController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder:
          (context, child) => Theme(
            data: ThemeData.light().copyWith(
              colorScheme: ColorScheme.light(
                primary: preciseGreen,
                onPrimary: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          ),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        dobController.text = _formatDate(picked);
      });
    }
  }

  bool _validateFields() {
    if (usernameController.text.trim().isEmpty) {
      Dialogs.showSnackbar(context, 'Please enter a username');
      return false;
    }
    if (fullNameController.text.trim().isEmpty) {
      Dialogs.showSnackbar(context, 'Please enter your full name');
      return false;
    }
    if (emailController.text.trim().isEmpty) {
      Dialogs.showSnackbar(context, 'Please enter your email');
      return false;
    }
    if (!RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    ).hasMatch(emailController.text.trim())) {
      Dialogs.showSnackbar(context, 'Please enter a valid email');
      return false;
    }
    if (passwordController.text.length < 6) {
      Dialogs.showSnackbar(context, 'Password must be at least 6 characters');
      return false;
    }
    if (completePhoneNumber.isEmpty) {
      Dialogs.showSnackbar(context, 'Please enter your phone number');
      return false;
    }
    if (dobController.text.isEmpty) {
      Dialogs.showSnackbar(context, 'Please enter your date of birth');
      return false;
    }
    if (genderController.text.trim().isEmpty) {
      Dialogs.showSnackbar(context, 'Please enter your gender');
      return false;
    }
    return true;
  }

  Future<void> _saveCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setString('email', emailController.text.trim());
        await prefs.setString('password', passwordController.text.trim());
        await prefs.setBool('rememberMe', true);
      } else {
        await prefs.remove('email');
        await prefs.remove('password');
        await prefs.setBool('rememberMe', false);
      }
    } catch (e) {
      debugPrint('Error saving credentials: $e');
    }
  }

  Future<void> _signUp() async {
    if (!_validateFields()) return;

    setState(() => isLoading = true);

    try {
      final requestBody = {
        'username': usernameController.text.trim(),
        'full_name': fullNameController.text.trim(),
        'email': emailController.text.trim(),
        'password': passwordController.text,
        'phone_number': completePhoneNumber,
        'address': addressController.text.trim(),
        'date_of_birth': dobController.text,
        'gender': genderController.text.trim(),
        // role is nullable — not sent
      };

      developer.log('Signup request: $requestBody');

      final response = await http.post(
        Uri.parse(ApiConstants.register),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      developer.log(
        'Signup response: ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _saveCredentials();
        Navigator.push(context, MaterialPageRoute(builder: (_) => LoginPage()));
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final error =
            data?['message'] ??
            data?['error'] ??
            data?['detail'] ??
            'Registration failed (${response.statusCode})';
        Dialogs.showSnackbar(context, error.toString());
      }
    } catch (e) {
      developer.log('Signup error: $e');
      Dialogs.showSnackbar(
        context,
        'Network error. Please check your connection.',
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context).size;

    return Theme(
      data: ThemeData(
        primaryColor: preciseGreen,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: preciseGreen, width: 2),
          ),
        ),
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // Orange header
            Container(
              width: mq.width,
              height: mq.height / 2.0,
              decoration: const BoxDecoration(
                color: Color.fromRGBO(244, 135, 6, 1),
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(70),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: mq.width * 0.03,
                  top: mq.height * 0.02,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const Text(
                      'CREATE\nACCOUNT',
                      style: TextStyle(
                        fontSize: 28,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: Image.asset(
                        'animation/loginimage.gif',
                        width: mq.width * 0.5,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // White form card
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: mq.width,
                height: mq.height / 1.6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(70)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        _buildField(
                          'Username',
                          usernameController,
                          hint: 'Enter your username',
                        ),
                        SizedBox(height: mq.height * 0.025),

                        _buildField(
                          'Full Name',
                          fullNameController,
                          hint: 'Enter your full name',
                        ),
                        SizedBox(height: mq.height * 0.025),

                        _buildField(
                          'Email',
                          emailController,
                          hint: 'Enter your email',
                          prefixIcon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        SizedBox(height: mq.height * 0.025),

                        // Phone number
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _labelText('Phone Number'),
                            SizedBox(height: mq.height * 0.004),
                            IntlPhoneField(
                              controller: phoneController,
                              initialCountryCode: 'NP',
                              decoration: _inputDecoration(
                                hint: 'Phone Number',
                              ),
                              onChanged: (phone) {
                                completePhoneNumber = phone.completeNumber;
                              },
                            ),
                          ],
                        ),

                        // Date of Birth
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _labelText('Date of Birth'),
                            SizedBox(height: mq.height * 0.004),
                            TextField(
                              controller: dobController,
                              readOnly: true,
                              onTap: () => _selectDate(context),
                              decoration: _inputDecoration(
                                hint: 'YYYY-MM-DD',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.date_range),
                                  onPressed: () => _selectDate(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: mq.height * 0.025),

                        // Gender Dropdown
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _labelText('Gender'),
                            SizedBox(height: mq.height * 0.004),
                            DropdownButtonFormField<String>(
                              value:
                                  genderController.text.isEmpty
                                      ? null
                                      : genderController.text,
                              items:
                                  const ['Male', 'Female', 'Other']
                                      .map(
                                        (gender) => DropdownMenuItem(
                                          value: gender,
                                          child: Text(gender),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  genderController.text = value;
                                }
                              },
                              decoration: _inputDecoration(
                                hint: 'Select your gender',
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: mq.height * 0.025),

                        _buildField(
                          'Address',
                          addressController,
                          hint: 'Enter your address',
                        ),
                        SizedBox(height: mq.height * 0.025),

                        // Password
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _labelText('Password'),
                            SizedBox(height: mq.height * 0.004),
                            TextField(
                              controller: passwordController,
                              obscureText: !_isPasswordVisible,
                              decoration: _inputDecoration(
                                hint: 'Enter your password',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey,
                                  ),
                                  onPressed:
                                      () => setState(
                                        () =>
                                            _isPasswordVisible =
                                                !_isPasswordVisible,
                                      ),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Checkbox(
                                  activeColor: preciseGreen,
                                  checkColor: Colors.white,
                                  value: rememberMe,
                                  onChanged:
                                      (v) => setState(() => rememberMe = v!),
                                ),
                                InkWell(
                                  onTap:
                                      () => setState(
                                        () => rememberMe = !rememberMe,
                                      ),
                                  child: const Text('Remember Me'),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Sign up button
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: preciseGreen,
                            foregroundColor: Colors.white,
                            elevation: 10,
                            minimumSize: const Size(200, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: isLoading ? null : _signUp,
                          icon:
                              isLoading
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.person_add),
                          label: Text(
                            isLoading ? 'Creating Account...' : 'Sign Up',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Back to login
                        TextButton.icon(
                          onPressed:
                              () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginPage(),
                                ),
                              ),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back to Login'),
                          style: TextButton.styleFrom(
                            foregroundColor: preciseGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            if (isLoading)
              Container(
                color: Colors.black.withAlpha(30),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    required String hint,
    IconData? prefixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final mq = MediaQuery.of(context).size;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelText(label),
        SizedBox(height: mq.height * 0.004),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: _inputDecoration(
            hint: hint,
            prefixIcon:
                prefixIcon != null
                    ? Icon(prefixIcon, color: Colors.black54)
                    : null,
          ),
        ),
      ],
    );
  }

  Widget _labelText(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 16,
      fontFamily: 'InterThin',
      fontWeight: FontWeight.w500,
      color: Colors.black,
    ),
  );

  InputDecoration _inputDecoration({
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      fontSize: 14,
      color: Colors.grey,
      fontFamily: 'InterThin',
    ),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color.fromRGBO(244, 135, 6, 1)),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.red),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.red),
    ),
  );
}
