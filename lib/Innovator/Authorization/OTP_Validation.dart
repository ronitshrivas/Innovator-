import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/constant/api_constants.dart';
import 'package:innovator/Innovator/constant/app_colors.dart';

class OtpValidationScreen extends StatefulWidget {
  final String email;

  const OtpValidationScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<OtpValidationScreen> createState() => _OtpValidationScreenState();
}

class _OtpValidationScreenState extends State<OtpValidationScreen>
    with TickerProviderStateMixin {
  // Controllers for OTP input fields
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );

  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  // UI State
  bool _isLoading = false;
  bool _isResending = false;
  String _errorMessage = '';
  int _resendCountdown = 0;

  // Animations
  late AnimationController _shakeController;
  late AnimationController _successController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _successAnimation;

  // Theme color
  static const Color primaryColor = Color.fromRGBO(244, 135, 6, 1);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startResendTimer();
  }

  void _initializeAnimations() {
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _successController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _successAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.bounceOut),
    );
  }

  void _startResendTimer() {
    setState(() {
      _resendCountdown = 60;
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (_resendCountdown > 0 && mounted) {
        setState(() {
          _resendCountdown--;
        });
        _startResendTimer();
      }
    });
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _shakeController.dispose();
    _successController.dispose();
    super.dispose();
  }

  String get _otpCode {
    return _otpControllers.map((controller) => controller.text).join();
  }

  bool get _isOtpComplete {
    return _otpCode.length == 6;
  }

  void _onOtpChanged(String value, int index) {
    setState(() {
      _errorMessage = '';
    });

    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_isOtpComplete) {
          _verifyOtp();
        }
      }
    }
  }

  void _onBackspace(int index) {
    if (index > 0 && _otpControllers[index].text.isEmpty) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOtp() async {
    if (!_isOtpComplete) {
      _showError('Please enter complete OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      developer.log('Verifying OTP for email: ${widget.email}');

      final url = Uri.parse(ApiConstants.verifyEmail);
      final body = jsonEncode({'email': widget.email, 'otp': _otpCode});

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      developer.log('Sending OTP verification request');

      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      developer.log('OTP verification response: ${response.statusCode}');
      developer.log('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        developer.log('OTP verification successful');

        // Play success animation
        await _successController.forward();

        // Show success message
        _showSuccessSnackbar('Email verified successfully!');

        // Navigate back or to next screen after delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop(true); // Return success
          }
        });
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 'OTP verification failed';
        _showError(errorMessage);
        _shakeController.forward().then((_) => _shakeController.reset());
      }
    } catch (e) {
      developer.log(' Error verifying OTP: $e');
      _showError('Network error. Please try again.');
      _shakeController.forward().then((_) => _shakeController.reset());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0) return;

    setState(() {
      _isResending = true;
      _errorMessage = '';
    });

    try {
      developer.log(' Resending OTP to: ${widget.email}');

      final url = Uri.parse(ApiConstants.resendVerificationOTP);
      final body = jsonEncode({'email': widget.email});

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      developer.log(' Sending resend OTP request');

      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      developer.log(' Resend OTP response: ${response.statusCode}');
      developer.log(' Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        developer.log('OTP resent successfully');

        // Show success message
        _showSuccessSnackbar('Verification code sent successfully!');

        // Clear existing OTP fields
        _clearOtpFields();

        // Restart the countdown timer
        _startResendTimer();

        // Add haptic feedback for success
        HapticFeedback.lightImpact();
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 'Invalid email address';
        _showError(errorMessage);
      } else if (response.statusCode == 429) {
        _showError('Too many requests. Please wait before requesting again.');
      } else if (response.statusCode == 500) {
        _showError('Server error. Please try again later.');
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 'Failed to resend OTP';
        _showError(errorMessage);
      }
    } catch (e) {
      developer.log(' Error resending OTP: $e');

      if (e.toString().contains('TimeoutException')) {
        _showError(
          'Request timeout. Please check your connection and try again.',
        );
      } else if (e.toString().contains('SocketException')) {
        _showError('Network error. Please check your internet connection.');
      } else {
        _showError('Failed to resend OTP. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  void _clearOtpFields() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });

    HapticFeedback.vibrate();
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.whitecolor),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
            return;
          },
        ),
        title: const Text(
          'Verify Email',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Header Section
              _buildHeader(),

              const SizedBox(height: 40),

              // OTP Input Section
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: _buildOtpInput(),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Error Message
              if (_errorMessage.isNotEmpty) _buildErrorMessage(),

              const SizedBox(height: 32),

              // Verify Button
              _buildVerifyButton(),

              const SizedBox(height: 24),

              // Resend Section
              _buildResendSection(),

              const Spacer(),

              // Success Animation
              AnimatedBuilder(
                animation: _successAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _successAnimation.value,
                    child:
                        _successAnimation.value > 0
                            ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 80,
                            )
                            : const SizedBox.shrink(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: primaryColor.withAlpha(1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.email_outlined,
            size: 40,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Email Verification',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ve sent a verification code to',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          widget.email,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildOtpInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 45,
          height: 55,
          child: TextFormField(
            controller: _otpControllers[index],
            focusNode: _focusNodes[index],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            keyboardType: TextInputType.number,
            maxLength: 1,
            onChanged: (value) => _onOtpChanged(value, index),
            onTap: () {
              _otpControllers[index].selection = TextSelection.fromPosition(
                TextPosition(offset: _otpControllers[index].text.length),
              );
            },
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: AppColors.whitecolor,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        );
      }),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage,
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _verifyOtp,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: AppColors.whitecolor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child:
            _isLoading
                ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.whitecolor,
                    ),
                  ),
                )
                : const Text(
                  'Verify OTP',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
      ),
    );
  }

  Widget _buildResendSection() {
    return Column(
      children: [
        Text(
          'Didn\'t receive the code?',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 8),
        _isResending
            ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
            : _resendCountdown > 0
            ? Text(
              'Resend in ${_resendCountdown}s',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            )
            : GestureDetector(
              onTap: _resendOtp,
              child: const Text(
                'Resend Code',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
      ],
    );
  }
}
