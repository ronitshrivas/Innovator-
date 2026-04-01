import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:innovator/ecommerce/model/check_out_summary_model.dart';
import 'package:innovator/ecommerce/model/payment_model.dart';
import 'package:innovator/ecommerce/provider/payment_provider.dart';
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
    final paint = Paint()
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
 

// Checkout screen

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
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
   late PageController _pageController;
  int _currentStep = 0;
 
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

 
  String _selectedPaymentType = 'cod';
  PaymentModel? _selectedQR;
 
  File? _paymentScreenshot;
  final ImagePicker _picker = ImagePicker();
 
  bool _isProcessing = false;
  String? _orderId;  
 
  final Color _primaryColor = const Color.fromRGBO(244, 135, 6, 1);
  final Color _accentColor = Colors.green;
  final Color _backgroundColor = Colors.grey.shade50;
  final Color _cardColor = Colors.white;
  final Color _textColor = Colors.blueGrey.shade800;
 
  bool get _isCOD => _selectedPaymentType == 'cod';
 
  int get _totalSteps => _isCOD ? 2 : 3;

  List<Widget> get _pages => [
        _buildCustomerInfoTab(),
        _buildPaymentMethodTab(),
        if (!_isCOD) _buildUploadProofTab(),
      ];

  String get _buttonText {
    if (_currentStep < _totalSteps - 1) return 'NEXT';
    return _isCOD ? 'PLACE ORDER' : 'SUBMIT ORDER';
  }
 
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }
 
  Future<void> _nextStep() async { 
    if (_currentStep == 0) {
      if (!_formKey.currentState!.validate()) {
        _showSnackBar('Please fill all required fields', Colors.red);
        return;
      }
      _goToPage(1);
      return;
    }
 
    if (_currentStep == 1) {
      if (!_isCOD && _selectedQR == null) {
        _showSnackBar('Please select a QR payment method', Colors.orange);
        return;
      }
      await _placeOrder();
      return;
    }
 
    if (_currentStep == 2) {
      await _submitOnlineOrder();
    }
  }

  void _previousStep() {
    if (_currentStep == 0) return;
    _goToPage(_currentStep - 1);
  }

  void _goToPage(int page) {
    setState(() => _currentStep = page);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
 

  Future<void> _placeOrder() async {
    setState(() => _isProcessing = true);
    try {
      final service = ref.read(paymentServiceProvider);
      final response = await service.checkout(
        fullName: _nameController.text.trim(),
        address: _addressController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        paymentType: _selectedPaymentType,
      );

      setState(() {
        _isProcessing = false;
        _orderId = response.orderId;
      });

      if (_isCOD) {
        _showOrderSuccessDialog(response);
      } else {
        _goToPage(2);
      }
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> _submitOnlineOrder() async {
    if (_paymentScreenshot == null) {
      _showSnackBar('Please upload your payment screenshot', Colors.orange);
      return;
    }
    if (_orderId == null) {
      _showSnackBar('Order ID missing. Please go back and try again.', Colors.red);
      return;
    }
    if (!await _paymentScreenshot!.exists()) {
      _showSnackBar('File missing. Please re-upload.', Colors.red);
      setState(() => _paymentScreenshot = null);
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final service = ref.read(paymentServiceProvider);
      await service.confirmPayment(
        orderId: _orderId!,
        screenshot: _paymentScreenshot!,
      );
      setState(() => _isProcessing = false);
      _showPaymentConfirmedDialog();
    } catch (e) {
      _handleError(e);
    }
  }

  void _handleError(Object e) {
    setState(() => _isProcessing = false);
    final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    _showSnackBar('Failed: $msg', Colors.red);
  }
 

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    _handlePickedImage(image);
  }

  Future<void> _pickFromCamera() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    _handlePickedImage(image);
  }

  Future<void> _handlePickedImage(XFile? image) async {
    if (image == null) return;
    final ext = path.extension(image.path).toLowerCase();
    if (!['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext)) {
      _showSnackBar('Invalid file type', Colors.red);
      return;
    }
    final file = File(image.path);
    if (await file.length() > 5 * 1024 * 1024) {
      _showSnackBar('File too large. Max 5 MB.', Colors.red);
      return;
    }
    setState(() => _paymentScreenshot = file);
    _showSnackBar('Screenshot uploaded', _accentColor);
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
 

  void _showOrderSuccessDialog(CheckoutSummaryResponse response) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _accentColor.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: Colors.green, size: 60),
            ),
            const SizedBox(height: 20),
            const Text('Order Placed Successfully!',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(response.message),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryColor.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text('Order ID',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    response.orderId,
                    style: TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Grand Total: NPR ${response.grandTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((r) => r.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue Shopping'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentConfirmedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_done,
                  color: Colors.blue, size: 60),
            ),
            const SizedBox(height: 20),
            const Text('Payment Screenshot Submitted!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text(
              'Your order is under review. We will confirm once the payment is verified.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((r) => r.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue Shopping'),
            ),
          ],
        ),
      ),
    );
  }
 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Checkout',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
                onPageChanged: (i) => setState(() => _currentStep = i),
                children: _pages,
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
    if (!_isCOD) labels.add('Upload Proof');

    return Row(
      children: labels.asMap().entries.map((e) {
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
                      color: active
                          ? _primaryColor
                          : (done ? _accentColor : Colors.grey.shade300),
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
                                  ? (_isCOD
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
                      color:
                          active ? _primaryColor : Colors.grey.shade600,
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
 
  // Order summary 

  Widget _buildOrderSummary() {
    return Column(
      children: [
        _buildSummaryRow('Total Items', '${widget.itemCount}'),
        _buildSummaryRow(
            'Sub-Total', 'NPR ${widget.totalAmount.toStringAsFixed(2)}'),
        _buildSummaryRow('Shipping', 'NPR 0.00'),
        SizedBox(
          width: double.infinity,
          height: 10,
          child: const DottedLine(
              height: 2,
              color: Colors.grey,
              dashWidth: 6,
              dashSpace: 10),
        ),
        _buildSummaryRow(
          'Total Amount',
          'NPR ${widget.totalAmount.toStringAsFixed(2)}',
          isTotal: true,
        ),
        const SizedBox(height: 8),
        _buildSummaryRow(
          'Payment Method',
          _isCOD ? 'Cash on Delivery' : (_selectedQR?.name ?? 'QR Payment'),
          isTotal: true,
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {bool isTotal = false}) {
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
 
  // Bottom navigation 

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
            if (_currentStep > 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing ? null : _previousStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryColor,
                    side: BorderSide(color: _primaryColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: _currentStep > 0 ? 2 : 1,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _buttonText,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
 
  // Page 0 — Customer info 

  Widget _buildCustomerInfoTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Customer Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField('Full Name', _nameController,
                    'Full Name *', Icons.person,
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Required' : null),
                const SizedBox(height: 16),
                _buildTextField('Phone Number', _phoneController,
                    'Phone Number *', Icons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        v!.length < 10 ? 'Invalid phone' : null),
                const SizedBox(height: 16),
                _buildTextField('Delivery Address', _addressController,
                    'Delivery Address *', Icons.location_on,
                    maxLines: 3,
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Required' : null),
                const SizedBox(height: 16),
                _buildTextField('Notes (Optional)', _notesController,
                    'Order Notes (Optional)', Icons.note,
                    maxLines: 2),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
    int? maxLines,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines ?? 1,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _primaryColor),
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
 
  // Page 1 — Payment method selection 

  Widget _buildPaymentMethodTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Method',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          //   Payment type dropdown  
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPaymentType,
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                    value: 'cod',
                    child: Row(
                      children: [
                        Icon(Icons.local_shipping,
                            color: _primaryColor, size: 20),
                        const SizedBox(width: 10),
                        const Text('Cash on Delivery (COD)',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'qr',
                    child: Row(
                      children: [
                        Icon(Icons.qr_code,
                            color: _accentColor, size: 20),
                        const SizedBox(width: 10),
                        const Text('QR Payment',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _selectedPaymentType = val;
                    _selectedQR = null;
                    _paymentScreenshot = null;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 20),
 
          if (_isCOD) _buildCodContent() else _buildQRContent(),
        ],
      ),
    );
  }

  // COD info card
  Widget _buildCodContent() {
    return Card(
      color: _cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.local_shipping, size: 72, color: _primaryColor),
            const SizedBox(height: 14),
            const Text('Cash on Delivery',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Pay when you receive your parcel',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No advance payment needed. Pay in cash on delivery.',
                      style:
                          TextStyle(fontSize: 13, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // QR selection + image preview
  Widget _buildQRContent() {
    return Consumer(
      builder: (context, ref, child) {
        final paymentAsync = ref.watch(paymentProvider);
        return paymentAsync.when(
          data: (payments) {
            if (payments.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.qr_code_2,
                          size: 60, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('No QR payment methods available.',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // QR service selector
                const Text('Select QR Service',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<PaymentModel>(
                      value: _selectedQR,
                      isExpanded: true,
                      hint: const Text('Choose a payment service'),
                      items: payments
                          .map(
                            (p) => DropdownMenuItem<PaymentModel>(
                              value: p,
                              child: Row(
                                children: [
                                  Icon(Icons.qr_code_scanner,
                                      color: _accentColor, size: 18),
                                  const SizedBox(width: 10),
                                  Text(p.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedQR = val),
                    ),
                  ),
                ),

                // QR image
                if (_selectedQR != null) ...[
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      width: 230,
                      height: 230,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _primaryColor.withAlpha(80), width: 2),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          _selectedQR!.image,
                          fit: BoxFit.contain,
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                                  ? child
                                  : const Center(
                                      child: CircularProgressIndicator()),
                          errorBuilder: (_, __, ___) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image,
                                  size: 48,
                                  color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              const Text('Image unavailable',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildQRInstructions(),
                ],
              ],
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (_, __) =>
              const Center(child: Text('Failed to load payment methods')),
        );
      },
    );
  }

  Widget _buildQRInstructions() {
    return Card(
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.info, color: Colors.blue, size: 18),
                SizedBox(width: 8),
                Text('How to pay',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '1. Open your banking / wallet app\n'
              '2. Scan the QR code above\n'
              '3. Enter NPR ${widget.totalAmount.toStringAsFixed(2)}\n'
              '4. Complete the payment\n'
              '5. Take a screenshot of the confirmation\n'
              '6. Upload it in the next step',
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
 
  // Page 2 — Upload payment proof (QR only) 

  Widget _buildUploadProofTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Upload Payment Screenshot',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // Screenshot preview / upload area
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
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                const Text('Screenshot uploaded',
                    style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w500)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _paymentScreenshot = null),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Remove',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ] else
            GestureDetector(
              onTap: () => _showImageSourceSheet(),
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _primaryColor.withAlpha(8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _primaryColor.withAlpha(60), width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload,
                        size: 48, color: _primaryColor),
                    const SizedBox(height: 12),
                    const Text('Tap to upload screenshot',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    const Text('PNG, JPG up to 5 MB',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          // Important notes card
          Card(
            color: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Important Notes',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '• Screenshot must show full payment details\n'
                    '• Amount must be: NPR ${widget.totalAmount.toStringAsFixed(2)}\n'
                    '• Must include transaction ID and timestamp\n'
                    '• Order will be processed after verification',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade700,
                        height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImageSourceSheet() {
    showAdaptiveDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Choose Image Source'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _pickFromCamera();
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}