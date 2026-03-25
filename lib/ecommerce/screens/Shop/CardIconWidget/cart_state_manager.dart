import 'package:get/get.dart';
import 'package:innovator/ecommerce/screens/Shop/Cart_List/api_services.dart';
import 'package:innovator/Innovator/models/Shop_cart_model.dart';
import 'dart:developer' as developer;

class CartStateManager extends GetxController {
  static CartStateManager get instance => Get.find<CartStateManager>();

  final ApiService _apiService = ApiService();

  // Reactive variables
  final RxInt _cartItemCount = 0.obs;
  final RxBool _isLoading = false.obs;
  final RxBool _hasError = false.obs;
  final RxString _errorMessage = ''.obs;

  // Getters
  int get cartItemCount => _cartItemCount.value;
  bool get isLoading => _isLoading.value;
  bool get hasError => _hasError.value;
  String get errorMessage => _errorMessage.value;

  // Reactive getters for direct binding
  RxInt get cartItemCountRx => _cartItemCount;
  RxBool get isLoadingRx => _isLoading;
  RxBool get hasErrorRx => _hasError;
  RxString get errorMessageRx => _errorMessage;

  @override
  void onInit() {
    super.onInit();
    loadCartCount();
  }

  // Load cart count from API
  Future<void> loadCartCount() async {
    try {
      developer.log(' Loading cart count from API...');
      _isLoading.value = true;
      _hasError.value = false;
      _errorMessage.value = '';

      final CartListResponse cartResponse = await _apiService.getCartList();

      // Calculate total quantity from all cart items
      int totalCount = 0;
      for (var item in cartResponse.data) {
        totalCount += item.quantity ?? 0;
      }

      _cartItemCount.value = totalCount;
      _isLoading.value = false;

      developer.log('Cart count loaded: $totalCount');

      // Force UI update
      update();
    } catch (e) {
      _isLoading.value = false;
      _hasError.value = true;
      _errorMessage.value = e.toString();
      developer.log(' Error loading cart count: $e');
    }
  }

  // Increment cart count instantly (optimistic update)
  void incrementCartCount([int increment = 1]) {
    final oldCount = _cartItemCount.value;
    _cartItemCount.value += increment;
    _hasError.value = false;

    developer.log(
      '📈 Cart count incremented: $oldCount → ${_cartItemCount.value}',
    );

    // Force immediate UI update
    update();
  }

  // Decrement cart count instantly (optimistic update)
  void decrementCartCount([int decrement = 1]) {
    final oldCount = _cartItemCount.value;
    _cartItemCount.value =
        (_cartItemCount.value - decrement).clamp(0, double.infinity).toInt();
    _hasError.value = false;

    developer.log(
      '📉 Cart count decremented: $oldCount → ${_cartItemCount.value}',
    );

    // Force immediate UI update
    update();
  }

  // Set exact cart count
  void setCartCount(int count) {
    final oldCount = _cartItemCount.value;
    _cartItemCount.value = count.clamp(0, double.infinity).toInt();
    _hasError.value = false;

    developer.log(' Cart count set: $oldCount → ${_cartItemCount.value}');

    // Force immediate UI update
    update();
  }

  // Clear cart count
  void clearCart() {
    final oldCount = _cartItemCount.value;
    _cartItemCount.value = 0;
    _hasError.value = false;

    developer.log('🗑️ Cart cleared: $oldCount → 0');

    // Force immediate UI update
    update();
  }

  // Refresh cart count from server (for sync)
  Future<void> refreshCartCount() async {
    developer.log(' Refreshing cart count from server...');
    await loadCartCount();
  }

  // Reset error state
  void clearError() {
    _hasError.value = false;
    _errorMessage.value = '';
    update();
  }

  // Add method to handle cart add/remove operations
  Future<void> handleCartOperation(
    Future<void> Function() operation,
    int countChange,
  ) async {
    // Optimistic update
    if (countChange > 0) {
      incrementCartCount(countChange);
    } else {
      decrementCartCount(countChange.abs());
    }

    try {
      // Perform the actual operation
      await operation();
      developer.log('Cart operation successful');
    } catch (e) {
      // Revert optimistic update on error
      if (countChange > 0) {
        decrementCartCount(countChange);
      } else {
        incrementCartCount(countChange.abs());
      }
      developer.log(' Cart operation failed, reverted: $e');
      rethrow;
    }
  }
}
