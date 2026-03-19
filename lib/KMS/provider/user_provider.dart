import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/KMS/api_calling_services.dart/user_details_service.dart';
import 'package:innovator/KMS/model/user_details_model.dart';

final userProvider = Provider<UserDetailsService>(
  (ref) => UserDetailsService(),
);


final userDetailsProvider = FutureProvider<UserDetailsModel>((ref){
  final user = ref.watch(userProvider);
  return user.userData();
});