// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:innovator/Innovator/Authorization/OTP_Verification.dart';
// import 'package:innovator/Innovator/constant/api_constants.dart';
// import 'package:innovator/Innovator/constant/app_colors.dart';
// import 'package:innovator/Innovator/helper/dialogs.dart';

// class Forgot_PWD extends StatefulWidget {
//   const Forgot_PWD({super.key});

//   @override
//   State<Forgot_PWD> createState() => _Forgot_PWDState();
// }

// class _Forgot_PWDState extends State<Forgot_PWD> {
//   TextEditingController email = TextEditingController();
//   bool _isLoading = false;

//   Future<void> sendOTP() async {
//     if (email.text.isEmpty) {
//       Dialogs.showSnackbar(context, 'Please enter your email address');
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       // API endpoint
//       final url = Uri.parse(ApiConstants.sendOTP);

//       // Request body
//       final body = jsonEncode({'email': email.text.trim()});

//       // Headers
//       final headers = {'Content-Type': 'application/json'};

//       // Make POST request
//       final response = await http.post(url, headers: headers, body: body);

//       // Process response
//       if (response.statusCode == 200) {
//         final responseData = jsonDecode(response.body);
//         Dialogs.showSnackbar(
//           context,
//           responseData['message'] ?? 'OTP has been sent to your email',
//         );

//         // Navigate to OTP verification screen
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (_) => OTPVerificationScreen(email: email.text),
//           ),
//         );
//       } else {
//         final responseData = jsonDecode(response.body);
//         Dialogs.showSnackbar(
//           context,
//           responseData['message'] ?? 'Failed to send OTP. Please try again.',
//         );
//       }
//     } catch (e) {
//       Dialogs.showSnackbar(
//         context,
//         'Network error. Please check your connection.',
//       );
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           Container(
//             width: MediaQuery.of(context).size.width,
//             height: MediaQuery.of(context).size.height / 2.0,
//             decoration: const BoxDecoration(
//               color: Color.fromRGBO(244, 135, 6, 1),
//               borderRadius: BorderRadius.only(bottomRight: Radius.circular(70)),
//             ),
//             // child: Padding(
//             //   padding: EdgeInsets.only(bottom: mq.height * 0.15),
//             //   child: Center(
//             //     child: Lottie.asset(
//             //       'animation/forgot_password.json',  // Add a suitable animation asset
//             //       width: mq.width * .6,
//             //     ),
//             //   ),
//             // ),
//           ),
//           Align(
//             alignment: Alignment.bottomCenter,
//             child: Container(
//               width: MediaQuery.of(context).size.width,
//               height: MediaQuery.of(context).size.height / 2.0,
//               decoration: const BoxDecoration(
//                 color: AppColors.whitecolor,
//                 borderRadius: BorderRadius.only(topLeft: Radius.circular(70)),
//               ),
//               child: Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Text(
//                       'Forgot Password',
//                       style: TextStyle(
//                         fontSize: 24,
//                         fontWeight: FontWeight.bold,
//                         color: Color.fromRGBO(244, 135, 6, 1),
//                       ),
//                     ),
//                     SizedBox(height: 20),
//                     Text(
//                       'Enter your email to receive a verification code',
//                       style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//                       textAlign: TextAlign.center,
//                     ),
//                     SizedBox(height: 20),
//                     TextField(
//                       controller: email,
//                       keyboardType: TextInputType.emailAddress,
//                       decoration: InputDecoration(
//                         hintText: 'Enter Email',
//                         prefixIcon: Icon(
//                           Icons.email,
//                           color: Color.fromRGBO(244, 135, 6, 1),
//                         ),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(20),
//                           borderSide: BorderSide(
//                             color: Color.fromRGBO(244, 135, 6, 1),
//                           ),
//                         ),
//                         focusedBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(20),
//                           borderSide: BorderSide(
//                             color: Color.fromRGBO(244, 135, 6, 1),
//                             width: 2,
//                           ),
//                         ),
//                         labelText: 'Email',
//                         labelStyle: TextStyle(
//                           color: Color.fromRGBO(244, 135, 6, 1),
//                         ),
//                       ),
//                     ),
//                     SizedBox(height: 30),
//                     ElevatedButton.icon(
//                       onPressed: _isLoading ? null : sendOTP,
//                       label:
//                           _isLoading
//                               ? SizedBox(
//                                 width: 20,
//                                 height: 20,
//                                 child: CircularProgressIndicator(
//                                   color: AppColors.whitecolor,
//                                   strokeWidth: 2,
//                                 ),
//                               )
//                               : Text(
//                                 'Send Verification Code',
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   color: AppColors.whitecolor,
//                                 ),
//                               ),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Color.fromRGBO(244, 135, 6, 1),
//                         padding: EdgeInsets.symmetric(
//                           horizontal: 20,
//                           vertical: 12,
//                         ),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(20),
//                         ),
//                         minimumSize: Size(double.infinity, 50),
//                       ),
//                       icon: Icon(Icons.send, color: AppColors.whitecolor),
//                     ),
//                     SizedBox(height: 15),
//                     TextButton.icon(
//                       onPressed: () {
//                         Navigator.pop(context);
//                       },
//                       icon: Icon(
//                         Icons.arrow_back,
//                         color: Color.fromRGBO(244, 135, 6, 1),
//                       ),
//                       label: Text(
//                         'Back to Login',
//                         style: TextStyle(
//                           color: Color.fromRGBO(244, 135, 6, 1),
//                           fontSize: 14,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }




import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/Authorization/otp.dart';
import 'package:innovator/Innovator/constant/api_constants.dart'; 
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static const Color _primary = Color.fromRGBO(244, 135, 6, 1);
  static const Color _primaryLight = Color.fromRGBO(244, 135, 6, 0.12);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.forgotPassword),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text.trim()}),
      );

      if (!mounted) return;

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackbar(
          data['message'] ?? 'OTP sent to your email!',
          isError: false,
        );
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, animation, __) => OtpResetPasswordScreen(
              email: _emailController.text.trim(),
            ),
            transitionsBuilder: (_, animation, __, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                ),
                child: child,
              );
            },
          ),
        );
      } else {
        _showSnackbar(
          data['message'] ?? 'Failed to send OTP. Please try again.',
          isError: true,
        );
      }
    } catch (_) {
      _showSnackbar('Network error. Please check your connection.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFD32F2F) : const Color(0xFF388E3C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Stack(
        children: [
          // ─── Orange top blob ───────────────────────────────────────
          ClipPath(
            clipper: _TopBlobClipper(),
            child: Container(
              height: size.height * 0.42,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF9800), _primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          // ─── Back button ───────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ),

          // ─── Lock icon ─────────────────────────────────────────────
          Positioned(
            top: size.height * 0.10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  size: 46,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // ─── Card ──────────────────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Container(
                  height: size.height * 0.64,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(36)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 32,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A2E),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter your registered email and we\'ll send\nyou a verification code.',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 36),

                          // ── Email label ──
                          const Text(
                            'Email Address',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // ── Email field ──
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF1A1A2E),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Email is required';
                              }
                              if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w]{2,}$')
                                  .hasMatch(v.trim())) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              hintText: 'you@example.com',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Icon(Icons.alternate_email_rounded,
                                    color: _primary, size: 22),
                              ),
                              filled: true,
                              fillColor: _primaryLight,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: _primary, width: 1.8),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: Color(0xFFD32F2F), width: 1.5),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: Color(0xFFD32F2F), width: 1.5),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // ── Send OTP button ──
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _sendOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    _primary.withOpacity(0.6),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation(Colors.white),
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Send Verification Code',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_forward_rounded,
                                            size: 20),
                                      ],
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Back to login ──
                          Center(
                            child: TextButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back_rounded,
                                  size: 16, color: _primary),
                              label: const Text(
                                'Back to Login',
                                style: TextStyle(
                                  color: _primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom top blob shape ──────────────────────────────────────────────────
class _TopBlobClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 60);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height,
      size.width * 0.55,
      size.height - 30,
    );
    path.quadraticBezierTo(
      size.width * 0.8,
      size.height - 60,
      size.width,
      size.height - 20,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_TopBlobClipper _) => false;
}