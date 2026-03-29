import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/constant/app_colors.dart';
import 'package:innovator/Innovator/screens/Shop/Cart_List/Orders_detail_page.dart';
import 'package:innovator/Innovator/models/Shop_cart_model.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

class OrdersHistoryPage extends StatefulWidget {
  const OrdersHistoryPage({Key? key}) : super(key: key);

  @override
  _OrdersHistoryPageState createState() => _OrdersHistoryPageState();
}

class _OrdersHistoryPageState extends State<OrdersHistoryPage>
    with SingleTickerProviderStateMixin {
  final AppData _appData = AppData();
  final String _baseUrl = 'http://182.93.94.210:3067';
  final String _imageBaseUrl = 'http://182.93.94.210:3067';

  List<Order> _orders = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String? _errorMessage;

  late TabController _tabController;
  String _selectedStatus = 'all';

  final ScrollController _scrollController = ScrollController();

  // Colors
  final Color _primaryColor = Color.fromRGBO(244, 135, 6, 1);
  final Color _accentColor = Colors.green;
  final Color _backgroundColor = Colors.grey.shade50;
  final Color _cardColor = AppColors.whitecolor;
  final Color _textColor = Colors.blueGrey.shade800;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_scrollListener);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedStatus = 'all';
            break;
          case 1:
            _selectedStatus = 'pending';
            break;
          case 2:
            _selectedStatus = 'processing';
            break;
          case 3:
            _selectedStatus = 'completed';
            break;
          case 4:
            _selectedStatus = 'cancelled';
            break;
        }
        _orders.clear();
        _currentPage = 0;
        _hasMore = true;
      });
      _loadOrders();
    }
  }

  void _scrollListener() {
    if (_scrollController.position.extentAfter < 200 &&
        !_isLoading &&
        _hasMore) {
      _loadOrders();
    }
  }

  Future<void> _loadOrders() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final headers = {
        'Content-Type': 'application/json',
        'authorization': 'Bearer ${_appData.accessToken}',
      };

      // Add query parameters for pagination and status filter
      final queryParams = <String, String>{
        'page': _currentPage.toString(),
        'limit': '10',
      };

      if (_selectedStatus != 'all') {
        queryParams['status'] = _selectedStatus;
      }

      final uri = Uri.parse(
        '$_baseUrl/api/v1/my-orders',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final ordersResponse = OrdersResponse.fromJson(
          json.decode(response.body),
        );

        setState(() {
          _orders.addAll(ordersResponse.data?.orders ?? []);
          _hasMore = ordersResponse.data?.pagination.hasMore ?? false;
          _currentPage++;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load orders';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshOrders() async {
    setState(() {
      _orders.clear();
      _currentPage = 0;
      _hasMore = true;
    });
    await _loadOrders();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.access_time;
      case 'processing':
        return Icons.sync;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: AppColors.whitecolor,
        title: Text('My Orders', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.whitecolor,
          indicatorWeight: 3,
          labelColor: AppColors.whitecolor,
          unselectedLabelColor: AppColors.whitecolor,
          tabs: [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Processing'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_orders.isEmpty && _isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
        ),
      );
    }

    if (_errorMessage != null && _orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 16),
            Lottie.asset('animation/No_Internet.json', fit: BoxFit.fill),
            //Text(_errorMessage!),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refreshOrders,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: AppColors.whitecolor,
              ),
              label: Text('Retry'),
              icon: Icon(Icons.refresh),
            ),
          ],
        ),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16),
            Text(
              'No orders found',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            SizedBox(height: 8),
            Text(
              _selectedStatus != 'all'
                  ? 'No ${_selectedStatus} orders'
                  : 'You haven\'t placed any orders yet',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.shopping_cart),
              label: Text('Start Shopping'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: AppColors.whitecolor,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshOrders,
      color: _primaryColor,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.all(16),
        itemCount: _orders.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _orders.length) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                ),
              ),
            );
          }
          return _buildOrderCard(_orders[index]);
        },
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _navigateToOrderDetail(order),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNumber,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        dateFormat.format(order.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withAlpha(10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(order.status),
                          size: 16,
                          color: _getStatusColor(order.status),
                        ),
                        SizedBox(width: 4),
                        Text(
                          order.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(order.status),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Divider(height: 1),
              SizedBox(height: 12),

              // Vendor info
              Row(
                children: [
                  Icon(Icons.store, size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 8),
                  Text(
                    order.vendor.businessName,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                ],
              ),
              SizedBox(height: 12),

              // Order items preview
              Container(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: order.items.length,
                  itemBuilder: (context, index) {
                    final item = order.items[index];
                    final imageUrl =
                        item.product.images.isNotEmpty
                            ? '$_imageBaseUrl${item.product.images[0]}'
                            : '';

                    return Container(
                      margin: EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child:
                                  imageUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        placeholder:
                                            (context, url) => Container(
                                              color: Colors.grey.shade200,
                                              child: Center(
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(_primaryColor),
                                                ),
                                              ),
                                            ),
                                        errorWidget:
                                            (context, url, error) => Container(
                                              color: Colors.grey.shade200,
                                              child: Icon(
                                                Icons.image_not_supported,
                                                color: Colors.grey,
                                                size: 24,
                                              ),
                                            ),
                                      )
                                      : Container(
                                        color: Colors.grey.shade200,
                                        child: Icon(
                                          Icons.image_not_supported,
                                          color: Colors.grey,
                                          size: 24,
                                        ),
                                      ),
                            ),
                          ),
                          if (item.quantity > 1)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: _primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${item.quantity}',
                                  style: TextStyle(
                                    color: AppColors.whitecolor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (order.items.length > 5)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '+${order.items.length - 5} more items',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              SizedBox(height: 12),
              Divider(height: 1),
              SizedBox(height: 12),

              // Order total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.items.length} item${order.items.length > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  Text(
                    'NPR ${order.orderSummary.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _accentColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToOrderDetail(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => OrderDetailPage(
              orderId: order.id,
              baseUrl: _baseUrl,
              imageBaseUrl: _imageBaseUrl,
              authToken: _appData.accessToken,
            ),
      ),
    );
  }
}
