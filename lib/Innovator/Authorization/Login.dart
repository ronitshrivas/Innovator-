import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/Authorization/Forget_PWD.dart';
import 'package:innovator/Innovator/Authorization/signup.dart';
import 'package:innovator/Innovator/constant/api_constants.dart';
import 'package:innovator/Innovator/helper/dialogs.dart';
import 'package:innovator/Innovator/screens/Profile/Edit_Profile.dart';
import 'package:innovator/innovator_home.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.clearFields = false});
  final bool clearFields;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final Color _orange = const Color.fromRGBO(244, 135, 6, 1);

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.clearFields) {
      _emailCtrl.clear();
      _passwordCtrl.clear();
    } else {
      _loadSaved();
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ── Saved credentials ────────────────────────────────────────────────────

  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('rememberMe') ?? false;
      if (remember && mounted) {
        setState(() {
          _rememberMe = true;
          _emailCtrl.text = prefs.getString('email') ?? '';
          _passwordCtrl.text = prefs.getString('password') ?? '';
        });
      }
    } catch (e) {
      developer.log('loadSaved error: $e');
    }
  }

  Future<void> _saveCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('email', _emailCtrl.text.trim());
        await prefs.setString('password', _passwordCtrl.text.trim());
        await prefs.setBool('rememberMe', true);
      } else {
        await prefs.remove('email');
        await prefs.remove('password');
        await prefs.setBool('rememberMe', false);
      }
    } catch (e) {
      developer.log('saveCredentials error: $e');
    }
  }

  // ── Login ────────────────────────────────────────────────────────────────

  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      Dialogs.showSnackbar(context, 'Please enter both email and password');
      return;
    }
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailCtrl.text.trim(),
          'password': _passwordCtrl.text.trim(),
        }),
      );

      developer.log(
        'Login ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 200))}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        final accessToken = data['access_token']?.toString() ?? '';
        final refreshToken = data['refresh_token']?.toString() ?? '';
        final user = (data['user'] as Map<String, dynamic>?) ?? {};

        if (accessToken.isEmpty) {
          Dialogs.showSnackbar(context, 'Login failed: no token in response');
          return;
        }

        // ── Save via AppData (single source of truth) ──────────────────────
        // This writes 'access_token', 'refresh_token', 'user_data' to prefs.
        // ApiService reads 'access_token' — so they are always in sync.
        await AppData().saveLoginData(
          accessToken: accessToken,
          refreshToken: refreshToken,
          user: user,
        );

        developer.log(
          'Login saved — access_token: ${accessToken.substring(0, 30)}...',
        );
        developer.log('User: $user');

        await _saveCredentials();
        _navigateAfterLogin(user);
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final msg =
            data?['detail']?.toString() ??
            data?['message']?.toString() ??
            data?['error']?.toString() ??
            'Login failed (${response.statusCode})';
        Dialogs.showSnackbar(context, msg);
      }
    } catch (e) {
      developer.log('Login error: $e');
      Dialogs.showSnackbar(
        context,
        'Network error. Please check your connection.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
      TextInput.finishAutofillContext(shouldSave: false);
    }
  }

  // ── Navigation ───────────────────────────────────────────────────────────

  void _navigateAfterLogin(Map<String, dynamic> user) {
    final appData = AppData();

    // Re-sync AppData user so isProfileComplete works
    // (saveLoginData already set it, but re-check after a tick)
    if (appData.isProfileComplete) {
      developer.log('Profile complete → Homepage');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => Homepage()),
        (_) => false,
      );
    } else {
      developer.log('Profile incomplete → EditProfileScreen');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
        (_) => false,
      );
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Please complete your profile to continue'),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context).size;

    return Theme(
      data: ThemeData(primaryColor: _orange),
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
                      'Welcome\nBack,',
                      style: TextStyle(
                        fontSize: 30,
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

            // White card
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
                  padding: EdgeInsets.only(
                    top: mq.height * 0.05,
                    left: mq.width * 0.05,
                    right: mq.width * 0.05,
                    bottom: mq.height * 0.02,
                  ),
                  child: SingleChildScrollView(
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Email
                            _label('Email'),
                            SizedBox(height: mq.height * 0.004),
                            TextFormField(
                              controller: _emailCtrl,
                              focusNode: _emailFocus,
                              autofillHints: const [
                                AutofillHints.username,
                                AutofillHints.email,
                              ],
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              onEditingComplete:
                                  () => _passwordFocus.requestFocus(),
                              decoration: _dec(
                                hint: 'Enter your email',
                                prefix: Icons.email,
                              ),
                            ),

                            SizedBox(height: mq.height * 0.025),

                            // Password
                            _label('Password'),
                            SizedBox(height: mq.height * 0.004),
                            TextFormField(
                              controller: _passwordCtrl,
                              focusNode: _passwordFocus,
                              obscureText: !_isPasswordVisible,
                              autofillHints: const [AutofillHints.password],
                              onEditingComplete: () {
                                TextInput.finishAutofillContext();
                                _login();
                              },
                              decoration: _dec(
                                hint: 'Enter your password',
                                suffix: IconButton(
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

                            SizedBox(height: mq.height * 0.01),

                            // Remember me + Forgot password
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      activeColor: _orange,
                                      checkColor: Colors.white,
                                      value: _rememberMe,
                                      onChanged:
                                          (v) =>
                                              setState(() => _rememberMe = v!),
                                    ),
                                    InkWell(
                                      onTap:
                                          () => setState(
                                            () => _rememberMe = !_rememberMe,
                                          ),
                                      child: const Text('Remember Me'),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () => Get.to(Forgot_PWD()),
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: mq.height * 0.02),

                            // Login button
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _orange,
                                elevation: 10,
                                minimumSize: const Size(200, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _isLoading ? null : _login,
                              child:
                                  _isLoading
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                            ),

                            SizedBox(height: mq.height * 0.02),

                            // Sign up link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Don't have an account?",
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: mq.width * 0.01),
                                InkWell(
                                  onTap: () {
                                    TextInput.finishAutofillContext(
                                      shouldSave: false,
                                    );
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const Signup(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Sign Up',
                                    style: TextStyle(
                                      decoration: TextDecoration.underline,
                                      decorationColor: Colors.blue,
                                      fontSize: 15,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            if (_isLoading)
              Container(
                color: Colors.black.withAlpha(30),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontFamily: 'InterThin',
        fontWeight: FontWeight.w500,
        color: Colors.black,
      ),
    ),
  );

  InputDecoration _dec({
    required String hint,
    IconData? prefix,
    Widget? suffix,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
    prefixIcon: prefix != null ? Icon(prefix, color: Colors.black54) : null,
    suffixIcon: suffix,
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
