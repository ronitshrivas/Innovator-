class ApiConstants {
  ApiConstants._(); // Private constructor to prevent instantiation

  static const String _host = 'http://182.93.94.220';

  //Base Urls
  static const String studentBase = '$_host:8003/api/student';
  static const String authBase = '$_host:8010/api/auth';
  static const String mediaBase = '$_host:8003';

  //Auth Endpoints
  static const String tokenRefresh = '$authBase/token/refresh/';

  // Student endpoints
  static const String courses = '$studentBase/courses/';
  static const String enrollments = '$studentBase/enrollments/';

  //change password
  static const String changePassword = '$authBase/change-password';

  //Login Endpointts
  static const String login = '$authBase/sso/login/';

  //verify email
  static const String verifyEmail = '$authBase/verify-email';

  // Resend Verification OTP Endpoints
  static const String resendVerificationOTP =
      '$authBase/resend-verification-otp';

  //Forgot password Endpoints
  static const String forgotPassword = '$authBase/forgot-password';

  //Send OTP Endpoints
  static const String sendOTP = '$authBase/send-otp';

  //Register Endponits
  static const String register = '$authBase/register/';
}
