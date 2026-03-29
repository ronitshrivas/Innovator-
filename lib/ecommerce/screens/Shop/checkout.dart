import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:path/path.dart' as path;

class DottedLine extends StatelessWidget {
  final double height;
  final Color color;
  final double dashWidth;
  final double dashSpace;

  const DottedLine({
    Key? key,
    required this.height,
    required this.color,
    required this.dashWidth,
    required this.dashSpace,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedLinePainter(
        height: height,
        color: color,
        dashWidth: dashWidth,
        dashSpace: dashSpace,
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  final double height;
  final Color color;
  final double dashWidth;
  final double dashSpace;

  _DottedLinePainter({
    required this.height,
    required this.color,
    required this.dashWidth,
    required this.dashSpace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = height
          ..style = PaintingStyle.stroke;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CheckoutScreen extends ConsumerStatefulWidget {
  final double totalAmount;
  final int itemCount;
  final List<dynamic> cartItems;

  const CheckoutScreen({
    Key? key,
    required this.totalAmount,
    required this.itemCount,
    required this.cartItems,
  }) : super(key: key);

  @override
  // _CheckoutScreenState createState() => _CheckoutScreenState();
  ConsumerState<ConsumerStatefulWidget> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentStep = 0;

  late TabController _qrTabController;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  File? _paymentScreenshot;
  final ImagePicker _picker = ImagePicker();

  bool _isProcessing = false;
  bool isCOD = false;
  final double codFee = 120.0;

  String _selectedPaymentMethod = '';

  final String _merchantName = "Innovator Store";
  final String _merchantUPI = "Innovator@esewa";
  final String _merchantPhone = "+977-9803661701";

  final Color _primaryColor = const Color.fromRGBO(244, 135, 6, 1);
  final Color _accentColor = Colors.green;
  final Color _backgroundColor = Colors.grey.shade50;
  final Color _cardColor = Colors.white;
  final Color _textColor = Colors.blueGrey.shade800;

  // List<PaymentModel> _onlinePayments = [];
  bool _hasOnlinePayments = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // ref.refresh(paymentProvider);

    _qrTabController = TabController(length: 1, vsync: this);
    _qrTabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _qrTabController.removeListener(_handleTabChange);
    _qrTabController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_qrTabController.indexIsChanging) {
      final int idx = _qrTabController.index;
      final bool newCod = idx == _qrTabController.length - 1;

      late String method;
      if (newCod) {
        method = 'COD';
      } else {
        // method = _onlinePayments[idx].name;
      }

      if (newCod != isCOD || _selectedPaymentMethod != method) {
        setState(() {
          isCOD = newCod;
          _selectedPaymentMethod = method;
          if (isCOD) _paymentScreenshot = null;
        });
      }
    }
  }

  int get _totalSteps {
    return isCOD ? 2 : (_hasOnlinePayments ? 3 : 2);
  }

  // List<Widget> get _pageViewChildren {
  //   // final pages = <Widget>[_buildCustomerInfoTab(), _buildQRPaymentTab()];
  //   if (!isCOD && _hasOnlinePayments) {
  //     pages.add(_buildUploadProofTab());
  //   }
  //   return pages;
  // }

  double get _finalTotal {
    return isCOD ? widget.totalAmount + codFee : widget.totalAmount;
  }

  // CustomerInfo get _customerInfo => CustomerInfo(
  //   name: _nameController.text.trim(),
  //   phone: _phoneController.text.trim(),
  //   address: _addressController.text.trim(),
  // );

  void _nextStep() {
    // ref.refresh(paymentProvider);
    if (_currentStep == 0 && !_formKey.currentState!.validate()) {
      _showSnackBar('Please fill all required fields', Colors.red);
      return;
    }

    if (_currentStep == _totalSteps - 1) {
      if (isCOD) {
        _placeCodOrder();
      } else {
        _submitOnlineOrder();
      }
      return;
    }

    setState(() => _currentStep++);
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousStep() {
    // ref.refresh(paymentProvider);
    if (_currentStep == 0) return;
    setState(() => _currentStep--);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // COD ORDER
  Future<void> _placeCodOrder() async {
    setState(() => _isProcessing = true);
    try {
      // final response = await _apiService.checkout(
      //   customerInfo: _customerInfo,
      //   paidAmount: _finalTotal,
      //   paymentProof: null,
      //   notes:
      //       _notesController.text.trim().isEmpty
      //           ? null
      //           : _notesController.text.trim(),
      //   isCod: true,
      //   paymentMethod: _selectedPaymentMethod,
      // );
      // _finishSuccess(response);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> _submitOnlineOrder() async {
    if (_paymentScreenshot == null) {
      _showSnackBar('Please upload payment proof', Colors.orange);
      return;
    }

    if (!await _paymentScreenshot!.exists()) {
      _showSnackBar('File missing. Re-upload.', Colors.red);
      setState(() => _paymentScreenshot = null);
      return;
    }

    setState(() => _isProcessing = true);
    try {
      // final response = await _apiService.checkout(
      //   customerInfo: _customerInfo,
      //   paidAmount: widget.totalAmount,
      //   paymentProof: _paymentScreenshot!,
      //   notes:
      //       _notesController.text.trim().isEmpty
      //           ? null
      //           : _notesController.text.trim(),
      //   isCod: false,
      //   paymentMethod: _selectedPaymentMethod,
      // );
      // _finishSuccess(response);
    } catch (e) {
      _handleError(e);
    }
  }

  // void _finishSuccess(CheckoutResponse response) {
  //   setState(() => _isProcessing = false);
  //   _showOrderSuccessDialog(response);
  // }

  void _handleError(Object e) {
    setState(() => _isProcessing = false);
    final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    _showSnackBar('Order failed: $msg', Colors.red);
  }

  Future<void> _pickPaymentScreenshot() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final ext = path.extension(image.path).toLowerCase();
        if (!['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext)) {
          _showSnackBar('Invalid file type', Colors.red);
          return;
        }
        final file = File(image.path);
        if (await file.length() > 5 * 1024 * 1024) {
          _showSnackBar('File too large. Max 5MB.', Colors.red);
          return;
        }
        setState(() => _paymentScreenshot = file);
        _showSnackBar('Screenshot uploaded', _accentColor);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  Future<void> _takePaymentScreenshot() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final ext = path.extension(image.path).toLowerCase();
        if (!['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext)) {
          _showSnackBar('Invalid image format', Colors.red);
          return;
        }
        final file = File(image.path);
        if (await file.length() > 5 * 1024 * 1024) {
          _showSnackBar('Image too large', Colors.red);
          return;
        }
        setState(() => _paymentScreenshot = file);
        _showSnackBar('Screenshot captured', _accentColor);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('Copied to clipboard', _primaryColor);
  }

  void _showSnackBar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // void _showOrderSuccessDialog(CheckoutResponse response) {
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder:
  //         (_) => AlertDialog(
  //           shape: RoundedRectangleBorder(
  //             borderRadius: BorderRadius.circular(20),
  //           ),
  //           content: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               Container(
  //                 padding: const EdgeInsets.all(20),
  //                 decoration: BoxDecoration(
  //                   color: _accentColor.withAlpha(10),
  //                   shape: BoxShape.circle,
  //                 ),
  //                 child: const Icon(
  //                   Icons.check_circle,
  //                   color: Colors.green,
  //                   size: 60,
  //                 ),
  //               ),
  //               const SizedBox(height: 20),
  //               const Text(
  //                 'Order Placed Successfully!',
  //                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
  //               ),
  //               const SizedBox(height: 10),
  //               Text(
  //                 response.data?.message ?? 'Your order is being processed.',
  //               ),
  //               if (response.data?.orders.isNotEmpty == true) ...[
  //                 const SizedBox(height: 16),
  //                 Container(
  //                   padding: const EdgeInsets.all(12),
  //                   decoration: BoxDecoration(
  //                     color: _primaryColor.withAlpha(10),
  //                     borderRadius: BorderRadius.circular(8),
  //                   ),
  //                   child: Column(
  //                     children: [
  //                       const Text(
  //                         'Order Numbers:',
  //                         style: TextStyle(fontWeight: FontWeight.bold),
  //                       ),
  //                       const SizedBox(height: 8),
  //                       ...response.data!.orders.map(
  //                         (o) => Text(
  //                           o.orderNumber,
  //                           style: const TextStyle(
  //                             color: Colors.orange,
  //                             fontWeight: FontWeight.w500,
  //                           ),
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ],
  //               const SizedBox(height: 20),
  //               ElevatedButton(
  //                 onPressed:
  //                     () => Navigator.of(
  //                       context,
  //                     ).popUntil((route) => route.isFirst),
  //                 style: ElevatedButton.styleFrom(
  //                   backgroundColor: _primaryColor,
  //                   foregroundColor: Colors.white,
  //                 ),
  //                 child: const Text('Continue Shopping'),
  //               ),
  //             ],
  //           ),
  //         ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: const Text(
          'Checkout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildOrderSummary(),
            const SizedBox(height: 16),
            _buildStepper(),
            const SizedBox(height: 16),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                // children: _pageViewChildren,
                onPageChanged: (i) => setState(() => _currentStep = i),
              ),
            ),
            const SizedBox(height: 10),
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepper() {
    final labels = ['Customer Info', 'Payment Method'];
    if (!isCOD && _hasOnlinePayments) labels.add('Upload Proof');

    return Row(
      children:
          labels.asMap().entries.map((e) {
            final i = e.key;
            final label = e.value;
            final active = i == _currentStep;
            final done = i < _currentStep;

            return Expanded(
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              active
                                  ? _primaryColor
                                  : (done
                                      ? _accentColor
                                      : Colors.grey.shade300),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(20),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          done
                              ? Icons.check
                              : (i == 0
                                  ? Icons.person
                                  : (i == 1
                                      ? (isCOD
                                          ? Icons.local_shipping
                                          : Icons.qr_code)
                                      : Icons.upload_file)),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              active ? FontWeight.bold : FontWeight.w500,
                          color: active ? _primaryColor : Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  if (i < labels.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: done ? _accentColor : Colors.grey.shade300,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildOrderSummary() {
    return Column(
      children: [
        _buildSummaryRow('Total Items', '${widget.itemCount}'),
        _buildSummaryRow(
          'Sub-Total',
          'NPR ${widget.totalAmount.toStringAsFixed(2)}',
        ),
        _buildSummaryRow('Shipping', 'NPR 0.00'),
        if (isCOD)
          _buildSummaryRow('COD Charge', 'NPR ${codFee.toStringAsFixed(2)}'),
        Container(
          width: double.infinity,
          height: 10,
          child: const DottedLine(
            height: 2,
            color: Colors.grey,
            dashWidth: 6,
            dashSpace: 10,
          ),
        ),
        _buildSummaryRow(
          'Total Amount',
          'NPR ${_finalTotal.toStringAsFixed(2)}',
          isTotal: true,
        ),
        const SizedBox(height: 8),
        _buildSummaryRow(
          'Payment Method',
          _selectedPaymentMethod,
          isTotal: true,
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: isTotal ? _textColor : Colors.grey.shade600,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isTotal ? _primaryColor : _textColor,
            ),
          ),
        ],
      ),
    );
  }

  String get _buttonText {
    final last = _currentStep == _totalSteps - 1;
    if (last) return isCOD ? 'PLACE ORDER' : 'SUBMIT ORDER';
    return 'NEXT';
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryColor,
                    side: BorderSide(color: _primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: _currentStep > 0 ? 2 : 1,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isProcessing
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : Text(
                          _buttonText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfoTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(
                  'Full Name',
                  _nameController,
                  'Full Name *',
                  Icons.person,
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Phone Number',
                  _phoneController,
                  'Phone Number *',
                  Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.length < 10 ? 'Invalid phone' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Delivery Address',
                  _addressController,
                  'Delivery Address *',
                  Icons.location_on,
                  maxLines: 3,
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Notes (Optional)',
                  _notesController,
                  'Order Notes (Optional)',
                  Icons.note,
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String info,
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int? maxLines,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          info,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines ?? 1,
          decoration: InputDecoration(
            hintText: label,
            hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color.fromRGBO(244, 135, 6, 1),
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  // Widget _buildQRPaymentTab() {
  //   return SingleChildScrollView(
  //     child: Column(
  //       children: [
  //         Consumer(
  //           builder: (context, ref, child) {
  //             // final paymentAsync = ref.watch(paymentProvider);
  //             const baseUrlImage = 'http://182.93.94.210:3067';

  //             return paymentAsync.when(
  //               data: (payments) {
  //                 // _onlinePayments =
  //                 //     payments
  //                 //         .where(
  //                 //           (p) => p.active && p.qrImage.isNotEmpty && !p.cod,
  //                 //         )
  //                 //         .toList();
  //                 // _hasOnlinePayments = _onlinePayments.isNotEmpty;
  //                 final totalTabs = _onlinePayments.length + 1;

  //                 if (_qrTabController.length != totalTabs) {
  //                   _qrTabController.dispose();
  //                   _qrTabController = TabController(
  //                     length: totalTabs,
  //                     vsync: this,
  //                   );
  //                   _qrTabController.addListener(_handleTabChange);
  //                 }

  //                 if (!_hasOnlinePayments && _qrTabController.index == 0) {
  //                   _qrTabController.index = totalTabs - 1;
  //                   isCOD = true;
  //                 }

  //                 return Column(
  //                   children: [
  //                     TabBar(
  //                       controller: _qrTabController,
  //                       isScrollable: true,
  //                       tabAlignment: TabAlignment.start,
  //                       dividerColor: Colors.transparent,
  //                       indicatorSize: TabBarIndicatorSize.tab,
  //                       unselectedLabelColor: Colors.grey,
  //                       labelColor: Colors.white,
  //                       labelStyle: const TextStyle(
  //                         fontWeight: FontWeight.bold,
  //                       ),
  //                       unselectedLabelStyle: const TextStyle(
  //                         fontWeight: FontWeight.w500,
  //                       ),
  //                       indicator: BoxDecoration(
  //                         borderRadius: BorderRadius.circular(14),
  //                         color: _primaryColor,
  //                       ),
  //                       tabs: [
  //                         ..._onlinePayments.map(
  //                           (p) => Tab(
  //                             child: Row(
  //                               mainAxisSize: MainAxisSize.min,
  //                               children: [
  //                                 const Icon(Icons.qr_code_scanner, size: 16),
  //                                 const SizedBox(width: 4),
  //                                 Text(p.name),
  //                               ],
  //                             ),
  //                           ),
  //                         ),
  //                         const Tab(
  //                           child: Row(
  //                             mainAxisSize: MainAxisSize.min,
  //                             children: [
  //                               Icon(Icons.payment, size: 16),
  //                               SizedBox(width: 4),
  //                               Text('COD'),
  //                             ],
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                     const SizedBox(height: 16),
  //                     SizedBox(
  //                       height: 300,
  //                       child: TabBarView(
  //                         controller: _qrTabController,
  //                         children: [
  //                           ..._onlinePayments.map(
  //                             (p) => _buildQRCodeTab(p, baseUrlImage),
  //                           ),
  //                           _buildCodTab(),
  //                         ],
  //                       ),
  //                     ),
  //                   ],
  //                 );
  //               },
  //               loading: () => const Center(child: CircularProgressIndicator()),
  //               error:
  //                   (_, __) => const Center(
  //                     child: Text('Failed to load payment methods'),
  //                   ),
  //             );
  //           },
  //         ),
  //         const SizedBox(height: 16),
  //         if (!isCOD && _hasOnlinePayments) ...[
  //           _buildPaymentDetailsCard(),
  //           const SizedBox(height: 16),
  //           _buildInstructionsCard(),
  //         ],
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildQRCodeTab(PaymentModel payment, String baseUrl) {
  //   return Center(
  //     child: Padding(
  //       padding: const EdgeInsets.all(24.0),
  //       child: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           SizedBox(
  //             width: 250,
  //             height: 250,
  //             child: Image.network(
  //               '$baseUrl${payment.qrImage}',
  //               fit: BoxFit.contain,
  //               loadingBuilder:
  //                   (context, child, progress) =>
  //                       progress == null
  //                           ? child
  //                           : const CircularProgressIndicator(),
  //               errorBuilder: (_, __, ___) => const Icon(Icons.error, size: 60),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildCodTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.local_shipping, size: 80, color: Colors.orange),
          SizedBox(height: 16),
          Text(
            'Cash on Delivery',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Pay when you receive the parcel',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manual Payment Details:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Merchant:', _merchantName),
            _buildDetailRow('UPI ID:', _merchantUPI),
            _buildDetailRow('Phone:', _merchantPhone),
            _buildDetailRow(
              'Amount:',
              'NPR ${widget.totalAmount.toStringAsFixed(2)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: _textColor.withAlpha(70), fontSize: 13),
        ),
        GestureDetector(
          onTap: () => _copyToClipboard(value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _primaryColor.withAlpha(10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.copy, size: 14, color: Colors.orange),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Payment Instructions',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '1. Choose payment method\n2. Scan QR code\n3. Enter NPR ${widget.totalAmount.toStringAsFixed(2)}\n4. Complete payment\n5. Take screenshot\n6. Upload in next step',
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadProofTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const Text(
            'Upload Payment Screenshot',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          if (_paymentScreenshot != null) ...[
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accentColor, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(_paymentScreenshot!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Uploaded',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => setState(() => _paymentScreenshot = null),
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text('Remove', style: TextStyle(color: Colors.red)),
            ),
          ] else
            GestureDetector(
              onTap:
                  () => showAdaptiveDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          backgroundColor: Colors.white,
                          title: const Text('Choose Image Source'),
                          content: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  _pickPaymentScreenshot();
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.photo_library),
                                label: const Text('Gallery'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryColor,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  _takePaymentScreenshot();
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Camera'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                  ),
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _primaryColor.withAlpha(2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _primaryColor.withAlpha(30),
                    width: 2,
                  ),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload, size: 48, color: Colors.orange),
                    SizedBox(height: 16),
                    Text(
                      'Upload Screenshot',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'PNG, JPG up to 5MB',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          Card(
            color: Colors.white,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.warning, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Important Notes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• Screenshot must show full payment details\n'
                    '• Amount must be: NPR ${widget.totalAmount.toStringAsFixed(2)}\n'
                    '• Include transaction ID and time\n'
                    '• Order processed after verification',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange.shade600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
