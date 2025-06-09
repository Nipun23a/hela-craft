import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smeapp/models/order_model.dart';
import 'package:smeapp/models/product_model.dart';
import 'package:smeapp/models/user_model.dart';
import 'package:smeapp/services/auth_service.dart';
import 'package:smeapp/services/order_service.dart';
import 'package:smeapp/services/product_service.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Filter state
  String _selectedStatus = 'All';
  String _selectedDateRange = 'Last 7 days';

  // Sorting state
  String _sortBy = 'Date';
  bool _sortAscending = false;

  // Firebase service related state
  final AuthService _authService = AuthService();
  List<OrderModel> _orders = [];
  List<ProductModel> _products = [];
  Map<String, UserModel> _buyers = {};

  bool _isLoading = false;
  String _sellerId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Mock order data
  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userData = await AuthService().getLocalUser();
      _sellerId = userData['uid'] ?? '';

      if (_sellerId.isEmpty) throw Exception("User ID not found");

      final allOrders = await OrderService().getAllOrders();
      final List<OrderModel> sellerOrders = [];

      print('Total Orders Fetched: ${allOrders.length}');

      for (final order in allOrders) {
        final products = await ProductService().getProductsByIds(
          order.productIds,
        );
        final hasSellerProduct = products.any(
          (product) => product.sellerId == _sellerId,
        );

        if (hasSellerProduct) {
          sellerOrders.add(order);
          print(
            'Matched Order: ${order.id}, Buyer: ${order.buyerId}, Products: ${order.productIds}',
          );
        }
      }

      await _loadProductAndBuyerData(sellerOrders);

      setState(() {
        _orders = sellerOrders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error loading orders: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadProductAndBuyerData(List<OrderModel> orders) async {
    final Set<String> productIds = {};
    final Set<String> buyerIds = {};

    for (final order in orders) {
      productIds.addAll(order.productIds);
      buyerIds.add(order.buyerId);
    }

    try {
      // Fetch product info
      final products = await ProductService().getProductsByIds(
        productIds.toList(),
      );
      _products = products;

      // Fetch buyer info
      final users = await AuthService().getUsersByIds(buyerIds.toList());
      _buyers = {for (var user in users) user.uid: user};

      setState(() {}); // If you're in a StatefulWidget and want UI update
    } catch (e) {
      print("Error loading product or buyer data: $e");
    }
  }

  // Filtered orders based on search, tab, and filters
  List<OrderModel> get _filteredOrders {
    // Start with all orders
    List<OrderModel> result = List.from(_orders);

    // Apply search query filter
    if (_searchQuery.isNotEmpty) {
      result =
          result.where((order) {
            final buyerName = _buyers[order.buyerId]?.name ?? '';
            return order.id.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                buyerName.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();
    }

    // Apply tab filter
    if (_tabController.index == 1) {
      result = result.where((order) => order.status == 'processing').toList();
    } else if (_tabController.index == 2) {
      result = result.where((order) => order.status == 'shipped').toList();
    } else if (_tabController.index == 3) {
      result = result.where((order) => order.status == 'completed').toList();
    }

    // Apply status filter
    if (_selectedStatus != 'all') {
      result =
          result.where((order) => order.status == _selectedStatus).toList();
    }

    // Apply sorting
    result.sort((a, b) {
      int comparison;
      if (_sortBy == 'Date') {
        // Assuming we have a createdAt field (would need to be added to OrderModel)
        // comparison = b.createdAt.compareTo(a.createdAt);
        comparison = 0; // Default for now
      } else if (_sortBy == 'Amount') {
        comparison = b.totalPrice.compareTo(a.totalPrice);
      } else {
        comparison = a.id.compareTo(b.id);
      }

      return _sortAscending ? -comparison : comparison;
    });

    return result;
  }

  Future<void> _updateOrderStatus(OrderModel order, String newStatus) async {
    try {
      setState(() {
        final index = _orders.indexWhere((o) => o.id == order.id);
        if (index > 0) {
          _orders[index].status = newStatus;
        }
      });

      await OrderService().updateOrderStatus(order.id, newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order ${order.id} status updated to $newStatus'),
          backgroundColor: const Color(0xFF6A11CB),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        final index = _orders.indexWhere((o) => o.id == order.id);
        if (index > 0) {
          _orders[index].status = order.status; // Revert to old status
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update order status: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            _buildHeader(),
            _buildTabs(),
            _buildFilters(),
            Expanded(
              child:
                  _filteredOrders.isEmpty
                      ? _buildEmptyState()
                      : _buildOrdersList(),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFFFF7B00),
          child: const Icon(Icons.filter_list_rounded, color: Colors.white),
          onPressed: () {
            _showFilterBottomSheet();
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Orders",
            style: GoogleFonts.raleway(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: "Search orders by ID or customer name",
                hintStyle: GoogleFonts.nunito(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          color: Colors.grey.shade500,
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        )
                        : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (index) {
          setState(() {});
        },
        labelColor: const Color(0xFF6A11CB),
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        indicatorColor: const Color(0xFF6A11CB),
        indicatorWeight: 3,
        tabs: const [
          Tab(text: "All Orders"),
          Tab(text: "Processing"),
          Tab(text: "Shipped"),
          Tab(text: "Completed"),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          Text(
            "${_filteredOrders.length} Orders",
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Sort: $_sortBy",
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: Colors.grey.shade700,
                ),
              ],
            ),
            onSelected: (value) {
              setState(() {
                if (_sortBy == value) {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortBy = value;
                  _sortAscending = false;
                }
              });
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(value: 'Date', child: Text('Date')),
                  const PopupMenuItem(value: 'ID', child: Text('Order ID')),
                  const PopupMenuItem(value: 'Amount', child: Text('Amount')),
                ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredOrders.length,
      itemBuilder: (context, index) {
        final order = _filteredOrders[index];
        final buyerName = _buyers[order.buyerId]?.name ?? 'Unknown Customer';
        final orderDateFormatted = DateFormat(
          'yyyy-MM-dd',
        ).format(order.orderDate);

        Color statusColor;
        switch (order.status.toLowerCase()) {
          case 'processing':
            statusColor = Colors.blue;
            break;
          case 'shipped':
            statusColor = Colors.orange;
            break;
          case 'completed':
            statusColor = Colors.green;
            break;
          case 'cancelled':
            statusColor = Colors.red;
            break;
          default:
            statusColor = Colors.grey;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              _showOrderDetailsDialog(order, buyerName);
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order ID and Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        order.id,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF333333),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          order.status,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Buyer name
                  Row(
                    children: [
                      Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        buyerName,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Order Date
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        orderDateFormatted,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Item count and total price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${order.productIds.length} item${order.productIds.length > 1 ? 's' : ''}",
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        "Rs. ${order.totalPrice.toStringAsFixed(2)}",
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF6A11CB),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showUpdateStatusDialog(order),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6A11CB),
                            side: const BorderSide(color: Color(0xFF6A11CB)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: Text(
                            "Update Status",
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              () => _showOrderDetailsDialog(order, buyerName),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A11CB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: Text(
                            "View Details",
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isLoading)
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6A11CB)),
            )
          else ...[
            Icon(
              Icons.shopping_bag_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              "No orders found",
              style: GoogleFonts.raleway(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? "Try a different search term"
                  : "Orders you receive will appear here",
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_searchQuery.isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A11CB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  "Clear Filters",
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Filter Orders",
                        style: GoogleFonts.raleway(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF333333),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Status",
                    style: GoogleFonts.raleway(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children:
                        [
                          'All',
                          'Processing',
                          'Shipped',
                          'Completed',
                          'Cancelled',
                        ].map((status) {
                          return ChoiceChip(
                            label: Text(status),
                            selected: _selectedStatus == status,
                            onSelected: (selected) {
                              setModalState(() {
                                _selectedStatus = selected ? status : 'All';
                              });
                              setState(() {});
                            },
                            labelStyle: GoogleFonts.nunito(
                              color:
                                  _selectedStatus == status
                                      ? Colors.white
                                      : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: Colors.grey.shade100,
                            selectedColor: const Color(0xFF6A11CB),
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Date Range",
                    style: GoogleFonts.raleway(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children:
                        [
                          'Today',
                          'Last 7 days',
                          'Last 30 days',
                          'All time',
                        ].map((range) {
                          return ChoiceChip(
                            label: Text(range),
                            selected: _selectedDateRange == range,
                            onSelected: (selected) {
                              setModalState(() {
                                _selectedDateRange =
                                    selected ? range : 'All time';
                              });
                              setState(() {});
                            },
                            labelStyle: GoogleFonts.nunito(
                              color:
                                  _selectedDateRange == range
                                      ? Colors.white
                                      : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: Colors.grey.shade100,
                            selectedColor: const Color(0xFF6A11CB),
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedStatus = 'All';
                              _selectedDateRange = 'Last 7 days';
                            });
                            setState(() {});
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6A11CB),
                            side: const BorderSide(color: Color(0xFF6A11CB)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            "Reset Filters",
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A11CB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            "Apply Filters",
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showOrderDetailsDialog(OrderModel order, String buyerName) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Order Details",
                        style: GoogleFonts.raleway(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF333333),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildDetailRow("Order ID", order.id),
                  _buildDetailRow(
                    "Date",
                    DateFormat(
                      "MMMM d, yyyy 'at' h:mm a",
                    ).format(order.orderDate),
                  ),
                  _buildDetailRow("Customer", buyerName),
                  _buildDetailRow(
                    "Status",
                    order.status,
                    isStatus: true,
                    status: order.status,
                  ),
                  _buildDetailRow(
                    "Total Amount",
                    "Rs. ${order.totalPrice.toStringAsFixed(2)}",
                  ),
                  _buildDetailRow("Shipping Address", order.orderAddress),
                  _buildDetailRow("Contact", order.orderPhone),
                  const SizedBox(height: 16),
                  Text(
                    "Order Items",
                    style: GoogleFonts.raleway(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Order items display
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: order.productIds.length,
                    itemBuilder: (context, index) {
                      final productId = order.productIds[index];
                      final product = _products.firstWhere(
                        (p) => p.id == productId,
                        orElse:
                            () => ProductModel(
                              id: productId,
                              name: 'Unknown',
                              description: '',
                              stock: 0,
                              category: '',
                              status: ProductStatus.OutOfStock,
                              price: 0,
                              rating: 0,
                              imageUrl: '',
                              sellerId: '',
                            ),
                      );

                      // Dummy quantity = 1 (if not stored, you can add quantity list later)
                      const int quantity = 1;
                      final double itemTotal = product.price * quantity;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF333333),
                                    ),
                                  ),
                                  Text(
                                    "Rs. ${product.price.toStringAsFixed(2)} x $quantity",
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              "Rs. ${itemTotal.toStringAsFixed(2)}",
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF6A11CB),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Price summary
                  _priceRow("Subtotal", order.totalPrice * 0.9),
                  _priceRow("Tax (10%)", order.totalPrice * 0.1),
                  _priceRow("Total", order.totalPrice, isTotal: true),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.print, size: 16),
                          label: Text(
                            "Print Invoice",
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Printing invoice..."),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6A11CB),
                            side: const BorderSide(color: Color(0xFF6A11CB)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.update, size: 16),
                          label: Text(
                            "Update Status",
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _showUpdateStatusDialog(order);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A11CB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _priceRow(String label, double value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.normal,
              color: isTotal ? const Color(0xFF333333) : Colors.grey.shade800,
            ),
          ),
          Text(
            "Rs. ${value.toStringAsFixed(2)}",
            style: GoogleFonts.nunito(
              fontSize: isTotal ? 16 : 14,
              fontWeight: FontWeight.w600,
              color: isTotal ? const Color(0xFF6A11CB) : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isStatus = false,
    String status = '',
  }) {
    Color statusColor = Colors.grey;
    if (isStatus) {
      switch (status) {
        case 'Processing':
          statusColor = Colors.blue;
          break;
        case 'Shipped':
          statusColor = Colors.orange;
          break;
        case 'Completed':
          statusColor = Colors.green;
          break;
        case 'Cancelled':
          statusColor = Colors.red;
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              "$label:",
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child:
                isStatus
                    ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        value,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    )
                    : Text(
                      value,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF333333),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  void _showUpdateStatusDialog(OrderModel order) {
    String selectedStatus = order.status;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                "Update Order Status",
                style: GoogleFonts.raleway(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF333333),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Order ID: ${order.id}",
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Select new status:",
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children:
                        ["Processing", "Shipped", "Completed", "Cancelled"].map(
                          (status) {
                            return RadioListTile<String>(
                              title: Text(
                                status,
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              value: status,
                              groupValue: selectedStatus,
                              activeColor: const Color(0xFF6A11CB),
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedStatus = value!;
                                });
                              },
                            );
                          },
                        ).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    "Cancel",
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Call the method to update order status
                    _updateOrderStatus(order, selectedStatus);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A11CB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    "Update",
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
