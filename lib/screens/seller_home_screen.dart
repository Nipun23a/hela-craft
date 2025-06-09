// All necessary imports
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:smeapp/models/order_model.dart';
import 'package:smeapp/models/product_model.dart';
import 'package:smeapp/screens/add_product_screen.dart';
import 'package:smeapp/screens/order_screen.dart';
import 'package:smeapp/screens/product_screen.dart';
import 'package:smeapp/screens/seller_order_scree.dart';
import 'package:smeapp/screens/setting_screen.dart';
import 'package:smeapp/services/auth_service.dart';
import 'package:smeapp/services/dashboard_service.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  int _selectedIndex = 0;

  final DashboardService _dashboardService = DashboardService();
  final AuthService _authService = AuthService();

  double _totalRevenue = 0.0;
  int _totalOrders = 0;
  int _totalProducts = 0;
  int _totalCustomers = 0;
  List<OrderModel> _recentOrders = [];
  List<ProductModel> _lowStockProducts = [];
  List<FlSpot> _salesData = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.getLocalUser();
      final sellerId = user['uid'] as String?;

      if (sellerId == null) {
        throw Exception("Seller ID is null");
      }

      final dashboardData = await _dashboardService.getDashboardData(sellerId);
      final recentOrders = await _dashboardService.getRecentOrders(sellerId);
      final lowStockItems = await _dashboardService.getLowStockItems(sellerId);
      final monthlyOrdersData = await _dashboardService.getMonthlyOrdersData(
        sellerId,
      );

      setState(() {
        _totalRevenue = dashboardData['totalRevenue'];
        _totalOrders = dashboardData['totalOrders'];
        _totalProducts = dashboardData['totalProducts'];
        _totalCustomers = dashboardData['uniqueBuyers'];
        _recentOrders = recentOrders;
        _lowStockProducts = lowStockItems;
        _salesData =
            monthlyOrdersData.map((entry) {
              return FlSpot(
                (entry['day'] as int).toDouble(),
                (entry['revenue'] as double),
              );
            }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading dashboard data: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildSelectedScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF6A11CB),
        unselectedItemColor: Colors.grey.shade600,
        selectedLabelStyle: GoogleFonts.nunito(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: GoogleFonts.nunito(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_rounded),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_rounded),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedScreen() {
    switch (_selectedIndex) {
      case 1:
        return const ProductsScreen();
      case 2:
        return const SellerOrdersScreen();
      case 3:
        return const SettingsScreen();
      default:
        return _buildDashboardScreen();
    }
  }

  Widget _buildDashboardScreen() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildSummaryCards(),
            const SizedBox(height: 24),
            _buildSalesChart(),
            const SizedBox(height: 24),
            _buildRecentOrdersSection(),
            const SizedBox(height: 24),
            _buildLowStockProductsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome Back, Seller!",
                style: GoogleFonts.raleway(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat("EEEE, MMMM d").format(DateTime.now()),
                style: GoogleFonts.nunito(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddProductScreen(),
                ),
              ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF7B00),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text("+ Add Product"),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.6,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildSummaryCard(
          "Total Revenue",
          "Rs. ${_totalRevenue.toStringAsFixed(0)}",
          Icons.monetization_on_rounded,
          const Color(0xFF6A11CB),
          "",
          true,
        ),
        _buildSummaryCard(
          "Total Orders",
          "$_totalOrders",
          Icons.shopping_bag_rounded,
          const Color(0xFFFF7B00),
          "",
          true,
        ),
        _buildSummaryCard(
          "Products",
          "$_totalProducts",
          Icons.inventory_2_rounded,
          Colors.teal,
          "",
          true,
        ),
        _buildSummaryCard(
          "Customers",
          "$_totalCustomers",
          Icons.people_rounded,
          Colors.indigo,
          "",
          true,
        ),
      ],
    );
  }

  Widget _buildSalesChart() {
    return _buildDashboardSection(
      "Sales Overview",
      _salesData.isEmpty
          ? Center(
            child: Text(
              "No sales data found.",
              style: GoogleFonts.nunito(fontSize: 14, color: Colors.black54),
            ),
          )
          : SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget:
                          (value, _) => Text(
                            "${value.toInt() + 1}",
                            style: GoogleFonts.nunito(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget:
                          (value, _) => Text(
                            '${(value / 1000).toInt()}K',
                            style: GoogleFonts.nunito(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _salesData,
                    isCurved: true,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6A11CB), Color(0xFFFF7B00)],
                    ),
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6A11CB).withOpacity(0.3),
                          const Color(0xFFFF7B00).withOpacity(0.1),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildRecentOrdersSection() {
    return _buildDashboardSection(
      "Recent Orders",
      _recentOrders.isEmpty
          ? Center(
            child: Text(
              "No orders found.",
              style: GoogleFonts.nunito(fontSize: 14, color: Colors.black54),
            ),
          )
          : Column(
            children:
                _recentOrders.map((order) {
                  Color statusColor;
                  switch (order.status) {
                    case 'Processing':
                      statusColor = Colors.blue;
                      break;
                    case 'Shipped':
                      statusColor = Colors.orange;
                      break;
                    case 'Completed':
                      statusColor = Colors.green;
                      break;
                    default:
                      statusColor = Colors.grey;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shopping_bag,
                          color: Color(0xFF6A11CB),
                          size: 30,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Order ID: ${order.id}",
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'MMM d, yyyy',
                                ).format(order.orderDate),
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "Rs. ${order.totalPrice.toStringAsFixed(0)}",
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w700,
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
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ),
    );
  }

  Widget _buildLowStockProductsSection() {
    return _buildDashboardSection(
      "Low Stock Products",
      _lowStockProducts.isEmpty
          ? Center(
            child: Text(
              "All good! No low stock products.",
              style: GoogleFonts.nunito(fontSize: 14, color: Colors.black54),
            ),
          )
          : Column(
            children:
                _lowStockProducts.map((product) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      product.name,
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text("Rs. ${product.price.toStringAsFixed(0)}"),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            product.stock < 5
                                ? Colors.red.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "${product.stock} left",
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: product.stock < 5 ? Colors.red : Colors.orange,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
    );
  }

  Widget _buildDashboardSection(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.raleway(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
    bool isPositive,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (subtitle.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isPositive ? Colors.green : Colors.red,
                      size: 12,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.nunito(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.raleway(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }
}
