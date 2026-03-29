import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:innovator/Innovator/constant/app_colors.dart';
import 'cart_state_manager.dart';
import 'dart:developer' as developer;

class ShoppingCartBadge extends StatelessWidget {
  final VoidCallback onPressed;
  final Color? badgeColor;
  final Color? iconColor;

  const ShoppingCartBadge({
    Key? key,
    required this.onPressed,
    this.badgeColor = Colors.green,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CartStateManager>(
      init: CartStateManager(), // Ensure it's initialized
      builder: (cartManager) {
        developer.log(
          ' ShoppingCartBadge rebuilding with count: ${cartManager.cartItemCount}',
        );

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                Icons.shopping_cart,
                color: iconColor ?? AppColors.whitecolor,
              ),
              onPressed: () {
                developer.log('🛒 Cart button pressed');
                onPressed();
              },
            ),

            // Cart item count badge with GetBuilder for immediate updates
            GetBuilder<CartStateManager>(
              id: 'cart_count', // Specific ID for targeted updates
              builder: (controller) {
                final count = controller.cartItemCount;
                developer.log('🏷️ Badge rendering with count: $count');

                if (count > 0) {
                  return Positioned(
                    top: 4,
                    right: 4,
                    child: AnimatedScale(
                      scale: count > 0 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: badgeColor ?? Colors.red,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(20),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          count > 99 ? '99+' : count.toString(),
                          style: const TextStyle(
                            color: AppColors.whitecolor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // Loading indicator
            Obx(() {
              if (cartManager.isLoading) {
                return Positioned(
                  top: 8,
                  right: 8,
                  child: SizedBox(
                    width: 8,
                    height: 8,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        badgeColor ?? Colors.red,
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        );
      },
    );
  }
}
