// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:innovator/Innovator/constant/api_constants.dart';
// import 'package:innovator/Innovator/constant/app_colors.dart';

// class OtpResetPasswordScreen extends StatefulWidget {
//   final String email;

//   const OtpResetPasswordScreen({Key? key, required this.email})
//       : super(key: key);

//   @override
//   State<OtpResetPasswordScreen> createState() =>
//       _OtpResetPasswordScreenState();
// }

// class _OtpResetPasswordScreenState extends State<OtpResetPasswordScreen>
//     with TickerProviderStateMixin {
//   // ─── OTP controllers ──────────────────────────────────────────────────────
//   final List<TextEditingController> _otpControllers =
//       List.generate(6, (_) => TextEditingController());
//   final List<FocusNode> _otpFocusNodes =
//       List.generate(6, (_) => FocusNode());

//   // ─── Password controllers ─────────────────────────────────────────────────
//   final TextEditingController _newPasswordController = TextEditingController();
//   final TextEditingController _confirmPasswordController =
//       TextEditingController();
//   final _formKey = GlobalKey<FormState>();

//   // ─── State ────────────────────────────────────────────────────────────────
//   bool _isLoading = false;
//   bool _isResending = false;
//   bool _showNewPassword = false;
//   bool _showConfirmPassword = false;
//   int _resendSeconds = 60;
//   Timer? _resendTimer;
//   String _otpError = '';

//   // ─── Animations ───────────────────────────────────────────────────────────
//   late AnimationController _shakeController;
//   late AnimationController _successController;
//   late AnimationController _entranceController;
//   late Animation<double> _shakeAnim;
//   late Animation<double> _successScaleAnim;
//   late Animation<double> _successOpacityAnim;
//   late Animation<double> _entranceFadeAnim;
//   late Animation<Offset> _entranceSlideAnim;

//   // ─── Theme ────────────────────────────────────────────────────────────────
//   static const Color _primary = Color.fromRGBO(244, 135, 6, 1);
//   static const Color _primaryLight = Color.fromRGBO(244, 135, 6, 0.10);
//   static const Color _dark = Color(0xFF1A1A2E);

//   @override
//   void initState() {
//     super.initState();
//     _initAnimations();
//     _startResendTimer();
//     _entranceController.forward();
//   }

//   void _initAnimations() {
//     _shakeController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 400),
//     );
//     _shakeAnim = TweenSequence([
//       TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
//       TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
//       TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
//       TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 1),
//     ]).animate(
//       CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
//     );

//     _successController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 600),
//     );
//     _successScaleAnim = CurvedAnimation(
//       parent: _successController,
//       curve: Curves.elasticOut,
//     );
//     _successOpacityAnim = CurvedAnimation(
//       parent: _successController,
//       curve: Curves.easeIn,
//     );

//     _entranceController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 600),
//     );
//     _entranceFadeAnim =
//         CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
//     _entranceSlideAnim = Tween<Offset>(
//       begin: const Offset(0, 0.12),
//       end: Offset.zero,
//     ).animate(
//       CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
//     );
//   }

//   void _startResendTimer() {
//     setState(() => _resendSeconds = 60);
//     _resendTimer?.cancel();
//     _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
//       if (!mounted) {
//         t.cancel();
//         return;
//       }
//       setState(() {
//         if (_resendSeconds > 0) {
//           _resendSeconds--;
//         } else {
//           t.cancel();
//         }
//       });
//     });
//   }

//   @override
//   void dispose() {
//     _resendTimer?.cancel();
//     for (final c in _otpControllers) c.dispose();
//     for (final n in _otpFocusNodes) n.dispose();
//     _newPasswordController.dispose();
//     _confirmPasswordController.dispose();
//     _shakeController.dispose();
//     _successController.dispose();
//     _entranceController.dispose();
//     super.dispose();
//   }

//   String get _otp =>
//       _otpControllers.map((c) => c.text).join();

//   bool get _isOtpComplete => _otp.length == 6;

//   void _onOtpDigitChanged(String value, int index) {
//     setState(() => _otpError = '');

//     if (value.isEmpty) {
//       // Backspace: move focus to previous box
//       if (index > 0) {
//         _otpFocusNodes[index - 1].requestFocus();
//       }
//     } else {
//       // Digit entered: move focus to next box
//       if (index < 5) {
//         _otpFocusNodes[index + 1].requestFocus();
//       } else {
//         _otpFocusNodes[index].unfocus();
//       }
//     }
//   }

//   void _clearOtp() {
//     for (final c in _otpControllers) c.clear();
//     _otpFocusNodes[0].requestFocus();
//   }

//   // ─── Verify OTP → Reset Password ──────────────────────────────────────────
//   Future<void> _submit() async {
//     setState(() => _otpError = '');

//     if (!_isOtpComplete) {
//       setState(() => _otpError = 'Please enter all 6 digits');
//       _triggerShake();
//       return;
//     }

//     if (!_formKey.currentState!.validate()) return;

//     setState(() => _isLoading = true);

//     try {
//       // Step 1: Verify OTP
//       debugPrint('>>> Submitting OTP: "$_otp" (length: ${_otp.length}) for email: "${widget.email}"');
//       final verifyRes = await http.post(
//         Uri.parse(ApiConstants.verifyOtp),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({'email': widget.email, 'otp': _otp}),
//       );
//       debugPrint('>>> verifyOtp status: ${verifyRes.statusCode}, body: ${verifyRes.body}');

//       if (!mounted) return;

//       if (verifyRes.statusCode != 200 && verifyRes.statusCode != 201) {
//         final err = jsonDecode(verifyRes.body);
//         setState(() =>
//             _otpError = err['message'] ?? 'Invalid OTP. Please try again.');
//         _triggerShake();
//         setState(() => _isLoading = false);
//         return;
//       }

//       // Step 2: Reset Password
//       final resetRes = await http.post(
//         Uri.parse(ApiConstants.resetPassword),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({
//           'new_password': _newPasswordController.text,
//           'confirm_password': _confirmPasswordController.text,
//         }),
//       );

//       if (!mounted) return;

//       if (resetRes.statusCode == 200 || resetRes.statusCode == 201) {
//         await _successController.forward();
//         _showSnackbar('Password reset successfully! Please log in.',
//             isError: false);
//         await Future.delayed(const Duration(milliseconds: 1800));
//         if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
//       } else {
//         final err = jsonDecode(resetRes.body);
//         _showSnackbar(err['message'] ?? 'Failed to reset password.',
//             isError: true);
//       }
//     } catch (_) {
//       _showSnackbar('Network error. Please check your connection.',
//           isError: true);
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   // ─── Resend OTP ───────────────────────────────────────────────────────────
//   Future<void> _resendOtp() async {
//     if (_resendSeconds > 0 || _isResending) return;

//     setState(() => _isResending = true);

//     try {
//       final res = await http.post(
//         Uri.parse(ApiConstants.resendOtp),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({
//           'email': widget.email,
//           'type': 'email_verification',
//         }),
//       );

//       if (!mounted) return;

//       if (res.statusCode == 200 || res.statusCode == 201) {
//         _clearOtp();
//         _startResendTimer();
//         HapticFeedback.lightImpact();
//         _showSnackbar('Verification code resent!', isError: false);
//       } else {
//         final err = jsonDecode(res.body);
//         _showSnackbar(err['message'] ?? 'Failed to resend code.', isError: true);
//       }
//     } catch (_) {
//       _showSnackbar('Network error. Please try again.', isError: true);
//     } finally {
//       if (mounted) setState(() => _isResending = false);
//     }
//   }

//   void _triggerShake() {
//     HapticFeedback.vibrate();
//     _shakeController.forward(from: 0);
//   }

//   void _showSnackbar(String message, {required bool isError}) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             Icon(
//               isError ? Icons.error_outline : Icons.check_circle_outline,
//               color: Colors.white,
//               size: 18,
//             ),
//             const SizedBox(width: 8),
//             Expanded(child: Text(message)),
//           ],
//         ),
//         backgroundColor:
//             isError ? const Color(0xFFD32F2F) : const Color(0xFF388E3C),
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         margin: const EdgeInsets.all(16),
//       ),
//     );
//   }

//   // ─── Build ────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF7F8FA),
//       body: Stack(
//         children: [
//           // ── Gradient header strip ──
//           Container(
//             height: 180,
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [Color(0xFFFF9800), _primary],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//             ),
//           ),

//           SafeArea(
//             child: Column(
//               children: [
//                 // ── App bar ──
//                 Padding(
//                   padding:
//                       const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                   child: Row(
//                     children: [
//                       IconButton(
//                         onPressed: () => Navigator.pop(context),
//                         icon: const Icon(Icons.arrow_back_ios_new_rounded,
//                             color: Colors.white, size: 20),
//                       ),
//                       const Expanded(
//                         child: Text(
//                           'Reset Password',
//                           textAlign: TextAlign.center,
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 18,
//                             fontWeight: FontWeight.w700,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 48), // balance
//                     ],
//                   ),
//                 ),

//                 // ── Body ──
//                 Expanded(
//                   child: FadeTransition(
//                     opacity: _entranceFadeAnim,
//                     child: SlideTransition(
//                       position: _entranceSlideAnim,
//                       child: Container(
//                         margin: const EdgeInsets.only(top: 12),
//                         decoration: const BoxDecoration(
//                           color: Colors.white,
//                           borderRadius:
//                               BorderRadius.vertical(top: Radius.circular(32)),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Color(0x10000000),
//                               blurRadius: 24,
//                               offset: Offset(0, -2),
//                             ),
//                           ],
//                         ),
//                         child: SingleChildScrollView(
//                           padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
//                           child: Form(
//                             key: _formKey,
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 _buildEmailBadge(),
//                                 const SizedBox(height: 28),
//                                 _buildSectionLabel('Verification Code'),
//                                 const SizedBox(height: 12),
//                                 _buildOtpRow(),
//                                 if (_otpError.isNotEmpty) ...[
//                                   const SizedBox(height: 10),
//                                   _buildErrorBanner(_otpError),
//                                 ],
//                                 const SizedBox(height: 10),
//                                 _buildResendRow(),
//                                 const SizedBox(height: 28),
//                                 const Divider(height: 1, color: Color(0xFFEEEEEE)),
//                                 const SizedBox(height: 28),
//                                 _buildSectionLabel('New Password'),
//                                 const SizedBox(height: 12),
//                                 _buildPasswordField(
//                                   controller: _newPasswordController,
//                                   hint: 'Enter new password',
//                                   isVisible: _showNewPassword,
//                                   onToggle: () => setState(() =>
//                                       _showNewPassword = !_showNewPassword),
//                                   validator: (v) {
//                                     if (v == null || v.isEmpty) {
//                                       return 'Password is required';
//                                     }
//                                     if (v.length < 6) {
//                                       return 'At least 6 characters';
//                                     }
//                                     return null;
//                                   },
//                                 ),
//                                 const SizedBox(height: 16),
//                                 _buildSectionLabel('Confirm Password'),
//                                 const SizedBox(height: 12),
//                                 _buildPasswordField(
//                                   controller: _confirmPasswordController,
//                                   hint: 'Re-enter new password',
//                                   isVisible: _showConfirmPassword,
//                                   onToggle: () => setState(() =>
//                                       _showConfirmPassword =
//                                           !_showConfirmPassword),
//                                   validator: (v) {
//                                     if (v == null || v.isEmpty) {
//                                       return 'Please confirm your password';
//                                     }
//                                     if (v != _newPasswordController.text) {
//                                       return 'Passwords do not match';
//                                     }
//                                     return null;
//                                   },
//                                 ),
//                                 const SizedBox(height: 36),
//                                 _buildSubmitButton(),
//                                 const SizedBox(height: 16),

//                                 // ── Success overlay ──
//                                 AnimatedBuilder(
//                                   animation: _successController,
//                                   builder: (_, __) {
//                                     if (_successController.value == 0) {
//                                       return const SizedBox.shrink();
//                                     }
//                                     return Center(
//                                       child: FadeTransition(
//                                         opacity: _successOpacityAnim,
//                                         child: ScaleTransition(
//                                           scale: _successScaleAnim,
//                                           child: Container(
//                                             padding: const EdgeInsets.all(16),
//                                             decoration: BoxDecoration(
//                                               color: const Color(0xFFE8F5E9),
//                                               shape: BoxShape.circle,
//                                             ),
//                                             child: const Icon(
//                                               Icons.check_rounded,
//                                               color: Color(0xFF388E3C),
//                                               size: 56,
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                     );
//                                   },
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ─── Sub-widgets ──────────────────────────────────────────────────────────

//   Widget _buildEmailBadge() {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       decoration: BoxDecoration(
//         color: _primaryLight,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: _primary.withOpacity(0.25)),
//       ),
//       child: Row(
//         children: [
//           const Icon(Icons.email_outlined, color: _primary, size: 20),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Code sent to',
//                   style: TextStyle(
//                     fontSize: 11,
//                     color: Colors.grey[500],
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   widget.email,
//                   style: const TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w700,
//                     color: _dark,
//                   ),
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSectionLabel(String label) {
//     return Text(
//       label,
//       style: const TextStyle(
//         fontSize: 13,
//         fontWeight: FontWeight.w700,
//         color: _dark,
//         letterSpacing: 0.2,
//       ),
//     );
//   }

//   Widget _buildOtpRow() {
//     return AnimatedBuilder(
//       animation: _shakeAnim,
//       builder: (_, child) => Transform.translate(
//         offset: Offset(_shakeAnim.value, 0),
//         child: child,
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: List.generate(6, (i) {
//           return SizedBox(
//             width: 48,
//             height: 58,
//             child: TextFormField(
//               controller: _otpControllers[i],
//               focusNode: _otpFocusNodes[i],
//               textAlign: TextAlign.center,
//               keyboardType: TextInputType.number,
//               maxLength: 1,
//               style: const TextStyle(
//                 fontSize: 22,
//                 fontWeight: FontWeight.w800,
//                 color: _dark,
//               ),
//               inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//               onChanged: (v) => _onOtpDigitChanged(v, i),
//               onTap: () {
//                 _otpControllers[i].selection = TextSelection.fromPosition(
//                   TextPosition(offset: _otpControllers[i].text.length),
//                 );
//               },
//               decoration: InputDecoration(
//                 counterText: '',
//                 filled: true,
//                 fillColor: _otpControllers[i].text.isNotEmpty
//                     ? _primaryLight
//                     : const Color(0xFFF5F5F5),
//                 contentPadding: EdgeInsets.zero,
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(14),
//                   borderSide: BorderSide(
//                     color: _otpControllers[i].text.isNotEmpty
//                         ? _primary
//                         : const Color(0xFFE0E0E0),
//                     width: 1.5,
//                   ),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(14),
//                   borderSide: const BorderSide(color: _primary, width: 2),
//                 ),
//                 errorBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(14),
//                   borderSide:
//                       const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
//                 ),
//                 focusedErrorBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(14),
//                   borderSide:
//                       const BorderSide(color: Color(0xFFD32F2F), width: 2),
//                 ),
//               ),
//             ),
//           );
//         }),
//       ),
//     );
//   }

//   Widget _buildResendRow() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Text(
//           "Didn't receive it? ",
//           style: TextStyle(fontSize: 13, color: Colors.grey[500]),
//         ),
//         _isResending
//             ? const SizedBox(
//                 width: 14,
//                 height: 14,
//                 child: CircularProgressIndicator(
//                   strokeWidth: 2,
//                   valueColor: AlwaysStoppedAnimation(_primary),
//                 ),
//               )
//             : _resendSeconds > 0
//                 ? Text(
//                     'Resend in ${_resendSeconds}s',
//                     style: TextStyle(
//                       fontSize: 13,
//                       color: Colors.grey[400],
//                       fontWeight: FontWeight.w600,
//                     ),
//                   )
//                 : GestureDetector(
//                     onTap: _resendOtp,
//                     child: const Text(
//                       'Resend Code',
//                       style: TextStyle(
//                         fontSize: 13,
//                         color: _primary,
//                         fontWeight: FontWeight.w700,
//                         decoration: TextDecoration.underline,
//                         decorationColor: _primary,
//                       ),
//                     ),
//                   ),
//       ],
//     );
//   }

//   Widget _buildErrorBanner(String message) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//       decoration: BoxDecoration(
//         color: const Color(0xFFFFEBEE),
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: const Color(0xFFFFCDD2)),
//       ),
//       child: Row(
//         children: [
//           const Icon(Icons.warning_amber_rounded,
//               color: Color(0xFFD32F2F), size: 18),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               message,
//               style: const TextStyle(
//                 color: Color(0xFFD32F2F),
//                 fontSize: 13,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPasswordField({
//     required TextEditingController controller,
//     required String hint,
//     required bool isVisible,
//     required VoidCallback onToggle,
//     required String? Function(String?) validator,
//   }) {
//     return TextFormField(
//       controller: controller,
//       obscureText: !isVisible,
//       validator: validator,
//       style: const TextStyle(fontSize: 15, color: _dark),
//       decoration: InputDecoration(
//         hintText: hint,
//         hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
//         prefixIcon: Padding(
//           padding: const EdgeInsets.all(14),
//           child: Icon(Icons.lock_outline_rounded, color: _primary, size: 22),
//         ),
//         suffixIcon: IconButton(
//           icon: Icon(
//             isVisible
//                 ? Icons.visibility_off_outlined
//                 : Icons.visibility_outlined,
//             color: Colors.grey[400],
//             size: 20,
//           ),
//           onPressed: onToggle,
//         ),
//         filled: true,
//         fillColor: _primaryLight,
//         contentPadding:
//             const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(16),
//           borderSide: BorderSide.none,
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(16),
//           borderSide: BorderSide.none,
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(16),
//           borderSide: const BorderSide(color: _primary, width: 1.8),
//         ),
//         errorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(16),
//           borderSide:
//               const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
//         ),
//         focusedErrorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(16),
//           borderSide:
//               const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
//         ),
//       ),
//     );
//   }

//   Widget _buildSubmitButton() {
//     return SizedBox(
//       width: double.infinity,
//       height: 56,
//       child: ElevatedButton(
//         onPressed: _isLoading ? null : _submit,
//         style: ElevatedButton.styleFrom(
//           backgroundColor: _primary,
//           foregroundColor: Colors.white,
//           disabledBackgroundColor: _primary.withOpacity(0.55),
//           elevation: 0,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(16),
//           ),
//         ),
//         child: _isLoading
//             ? const SizedBox(
//                 width: 22,
//                 height: 22,
//                 child: CircularProgressIndicator(
//                   strokeWidth: 2.5,
//                   valueColor: AlwaysStoppedAnimation(Colors.white),
//                 ),
//               )
//             : const Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.lock_open_rounded, size: 20),
//                   SizedBox(width: 8),
//                   Text(
//                     'Verify & Reset Password',
//                     style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.w700,
//                       letterSpacing: 0.3,
//                     ),
//                   ),
//                 ],
//               ),
//       ),
//     );
//   }
// }




import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/constant/api_constants.dart';

class OtpResetPasswordScreen extends StatefulWidget {
  final String email;

  const OtpResetPasswordScreen({Key? key, required this.email})
      : super(key: key);

  @override
  State<OtpResetPasswordScreen> createState() =>
      _OtpResetPasswordScreenState();
}

class _OtpResetPasswordScreenState extends State<OtpResetPasswordScreen>
    with TickerProviderStateMixin {
  // ─── OTP controllers ──────────────────────────────────────────────────────
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());

  // ─── Password controllers ─────────────────────────────────────────────────
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ─── State ────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool _isResending = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  // FIX: OTP expires in 10 minutes but resend cooldown is 10 seconds
  int _resendSeconds = 10;

  Timer? _resendTimer;
  String _otpError = '';

  // ─── Animations ───────────────────────────────────────────────────────────
  late AnimationController _shakeController;
  late AnimationController _successController;
  late AnimationController _entranceController;
  late Animation<double> _shakeAnim;
  late Animation<double> _successScaleAnim;
  late Animation<double> _successOpacityAnim;
  late Animation<double> _entranceFadeAnim;
  late Animation<Offset> _entranceSlideAnim;

  // ─── Theme ────────────────────────────────────────────────────────────────
  static const Color _primary = Color.fromRGBO(244, 135, 6, 1);
  static const Color _primaryLight = Color.fromRGBO(244, 135, 6, 0.10);
  static const Color _dark = Color(0xFF1A1A2E);

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startResendTimer();
    _entranceController.forward();
  }

  void _initAnimations() {
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScaleAnim = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );
    _successOpacityAnim = CurvedAnimation(
      parent: _successController,
      curve: Curves.easeIn,
    );

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entranceFadeAnim =
        CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
    _entranceSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );
  }

  void _startResendTimer() {
    // FIX: reset to 10 seconds cooldown (OTP itself is valid for 10 minutes)
    setState(() => _resendSeconds = 10);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_resendSeconds > 0) {
          _resendSeconds--;
        } else {
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _otpControllers) c.dispose();
    for (final n in _otpFocusNodes) n.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _shakeController.dispose();
    _successController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  String get _otp => _otpControllers.map((c) => c.text).join();

  bool get _isOtpComplete => _otp.length == 6;

  void _onOtpDigitChanged(String value, int index) {
    setState(() => _otpError = '');

    if (value.isEmpty) {
      if (index > 0) _otpFocusNodes[index - 1].requestFocus();
    } else {
      if (index < 5) {
        _otpFocusNodes[index + 1].requestFocus();
      } else {
        _otpFocusNodes[index].unfocus();
      }
    }
  }

  void _clearOtp() {
    for (final c in _otpControllers) c.clear();
    _otpFocusNodes[0].requestFocus();
  }

  // ─── Step 1: Verify OTP  ──────────────────────────────────────────────────
  // ─── Step 2: Reset Password ───────────────────────────────────────────────
  Future<void> _submit() async {
    setState(() => _otpError = '');

    if (!_isOtpComplete) {
      setState(() => _otpError = 'Please enter all 6 digits');
      _triggerShake();
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // ── Step 1: Verify OTP ──
      // Endpoint: verifyOtp  |  Body: { email, otp }
      debugPrint('>>> verifyOtp: email=${widget.email}  otp=$_otp');
      final verifyRes = await http.post(
        Uri.parse(ApiConstants.verifyOtp),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': widget.email,
          'otp': _otp,
        }),
      );
      debugPrint('>>> verifyOtp status=${verifyRes.statusCode}  body=${verifyRes.body}');

      if (!mounted) return;

      if (verifyRes.statusCode != 200 && verifyRes.statusCode != 201) {
        final err = jsonDecode(verifyRes.body);
        setState(() =>
            _otpError = err['message'] ?? 'Invalid OTP. Please try again.');
        _triggerShake();
        setState(() => _isLoading = false);
        return;
      }

      // ── Step 2: Reset Password ──
      // Endpoint: resetPassword  |  Body: { new_password, confirm_password }
      debugPrint('>>> resetPassword: sending new password');
      final resetRes = await http.post(
        Uri.parse(ApiConstants.resetPassword),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'new_password': _newPasswordController.text,
          'confirm_password': _confirmPasswordController.text,
        }),
      );
      debugPrint('>>> resetPassword status=${resetRes.statusCode}  body=${resetRes.body}');

      if (!mounted) return;

      if (resetRes.statusCode == 200 || resetRes.statusCode == 201) {
        await _successController.forward();
        _showSnackbar('Password reset successfully! Please log in.',
            isError: false);
        await Future.delayed(const Duration(milliseconds: 1800));
        if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        final err = jsonDecode(resetRes.body);
        _showSnackbar(err['message'] ?? 'Failed to reset password.',
            isError: true);
      }
    } catch (e) {
      // Surface the real error in debug console
      debugPrint('>>> _submit error: $e');
      _showSnackbar('Network error. Please check your connection.',
          isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Resend OTP ───────────────────────────────────────────────────────────
  // FIX: endpoint is resendOtp, body is just { email } — no 'type' field
  Future<void> _resendOtp() async {
    if (_resendSeconds > 0 || _isResending) return;

    setState(() => _isResending = true);

    try {
      debugPrint('>>> resendOtp: email=${widget.email}');
      final res = await http.post(
        Uri.parse(ApiConstants.resendOtp),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': widget.email,
          // FIX: removed the incorrect 'type: email_verification' field
        }),
      );
      debugPrint('>>> resendOtp status=${res.statusCode}  body=${res.body}');

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        _clearOtp();
        _startResendTimer();
        HapticFeedback.lightImpact();
        _showSnackbar('Verification code resent!', isError: false);
      } else {
        final err = jsonDecode(res.body);
        _showSnackbar(err['message'] ?? 'Failed to resend code.', isError: true);
      }
    } catch (e) {
      debugPrint('>>> resendOtp error: $e');
      _showSnackbar('Network error. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _triggerShake() {
    HapticFeedback.vibrate();
    _shakeController.forward(from: 0);
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
        backgroundColor:
            isError ? const Color(0xFFD32F2F) : const Color(0xFF388E3C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Stack(
        children: [
          Container(
            height: 180,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF9800), _primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const Expanded(
                        child: Text(
                          'Reset Password',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: FadeTransition(
                    opacity: _entranceFadeAnim,
                    child: SlideTransition(
                      position: _entranceSlideAnim,
                      child: Container(
                        margin: const EdgeInsets.only(top: 12),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(32)),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x10000000),
                              blurRadius: 24,
                              offset: Offset(0, -2),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildEmailBadge(),
                                const SizedBox(height: 28),
                                _buildSectionLabel('Verification Code'),
                                const SizedBox(height: 12),
                                _buildOtpRow(),
                                if (_otpError.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  _buildErrorBanner(_otpError),
                                ],
                                const SizedBox(height: 10),
                                _buildResendRow(),
                                const SizedBox(height: 28),
                                const Divider(
                                    height: 1, color: Color(0xFFEEEEEE)),
                                const SizedBox(height: 28),
                                _buildSectionLabel('New Password'),
                                const SizedBox(height: 12),
                                _buildPasswordField(
                                  controller: _newPasswordController,
                                  hint: 'Enter new password',
                                  isVisible: _showNewPassword,
                                  onToggle: () => setState(() =>
                                      _showNewPassword = !_showNewPassword),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Password is required';
                                    }
                                    if (v.length < 6) {
                                      return 'At least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildSectionLabel('Confirm Password'),
                                const SizedBox(height: 12),
                                _buildPasswordField(
                                  controller: _confirmPasswordController,
                                  hint: 'Re-enter new password',
                                  isVisible: _showConfirmPassword,
                                  onToggle: () => setState(() =>
                                      _showConfirmPassword =
                                          !_showConfirmPassword),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Please confirm your password';
                                    }
                                    if (v != _newPasswordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 36),
                                _buildSubmitButton(),
                                const SizedBox(height: 16),
                                AnimatedBuilder(
                                  animation: _successController,
                                  builder: (_, __) {
                                    if (_successController.value == 0) {
                                      return const SizedBox.shrink();
                                    }
                                    return Center(
                                      child: FadeTransition(
                                        opacity: _successOpacityAnim,
                                        child: ScaleTransition(
                                          scale: _successScaleAnim,
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFE8F5E9),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check_rounded,
                                              color: Color(0xFF388E3C),
                                              size: 56,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
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
          ),
        ],
      ),
    );
  }

  // ─── Sub-widgets ──────────────────────────────────────────────────────────

  Widget _buildEmailBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primary.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.email_outlined, color: _primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Code sent to',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.email,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: _dark,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildOtpRow() {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (_, child) => Transform.translate(
        offset: Offset(_shakeAnim.value, 0),
        child: child,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (i) {
          return SizedBox(
            width: 48,
            height: 58,
            child: TextFormField(
              controller: _otpControllers[i],
              focusNode: _otpFocusNodes[i],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) => _onOtpDigitChanged(v, i),
              onTap: () {
                _otpControllers[i].selection = TextSelection.fromPosition(
                  TextPosition(offset: _otpControllers[i].text.length),
                );
              },
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: _otpControllers[i].text.isNotEmpty
                    ? _primaryLight
                    : const Color(0xFFF5F5F5),
                contentPadding: EdgeInsets.zero,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _otpControllers[i].text.isNotEmpty
                        ? _primary
                        : const Color(0xFFE0E0E0),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFFD32F2F), width: 2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildResendRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Didn't receive it? ",
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
        _isResending
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(_primary),
                ),
              )
            : _resendSeconds > 0
                ? Text(
                    'Resend in ${_resendSeconds}s',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : GestureDetector(
                    onTap: _resendOtp,
                    child: const Text(
                      'Resend Code',
                      style: TextStyle(
                        fontSize: 13,
                        color: _primary,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: _primary,
                      ),
                    ),
                  ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFD32F2F), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFD32F2F),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool isVisible,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: _dark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(Icons.lock_outline_rounded, color: _primary, size: 22),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.grey[400],
            size: 20,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: _primaryLight,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
          borderSide: const BorderSide(color: _primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _primary.withOpacity(0.55),
          elevation: 0,
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
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_open_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Verify & Reset Password',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}