import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smeapp/models/order_model.dart';
import 'package:smeapp/models/product_model.dart';
import 'package:intl/intl.dart';

class DashboardService {
  // This will be the service that handles all the logic for the seller dashboard

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final int lowStockThreshold =
      5; // Consider products with stock below this threshold as low stock

  Future<Map<String, dynamic>> getDashboardData(String sellerId) async {
    double totalRevenue = 0.0;
    int totalOrders = 0;
    int totalProducts = 0;
    Set<String> uniqueBuyerIds = {};
    Map<String, List<String>> orderProductMap =
        {}; // Track which products from this seller were in each order

    try {
      // First get all products for this seller to have their IDs
      final productSnapshot =
          await _db
              .collection('products')
              .where('sellerId', isEqualTo: sellerId)
              .get();

      final products =
          productSnapshot.docs
              .map((doc) => ProductModel.fromMap(doc.data()))
              .toList();

      totalProducts = products.length;

      // Create a set of product IDs that belong to this seller for easy lookup
      final sellerProductIds = products.map((product) => product.id).toSet();

      // Get all orders that contain any products from this seller
      // We need to check all orders since a buyer might purchase from multiple sellers in one order
      final orderSnapshot = await _db.collection('orders').get();
      final allOrders =
          orderSnapshot.docs
              .map((doc) => OrderModel.fromMap(doc.data()))
              .toList();

      // Filter orders and calculate metrics
      for (var order in allOrders) {
        // Check which products in this order belong to the current seller
        final sellerProductsInOrder =
            order.productIds
                .where((productId) => sellerProductIds.contains(productId))
                .toList();

        // If this order contains products from this seller
        if (sellerProductsInOrder.isNotEmpty) {
          // Get details for each product to calculate revenue
          double orderRevenueForSeller = 0.0;

          for (var productId in sellerProductsInOrder) {
            // Find product in our products list
            final product = products.firstWhere(
              (p) => p.id == productId,
              orElse:
                  () =>
                      null
                          as ProductModel, // This will throw if product not found
            );

            if (product != null) {
              orderRevenueForSeller += product.price;
            }
          }

          // Add revenue from this order
          totalRevenue += orderRevenueForSeller;

          // Track this order for this seller
          orderProductMap[order.id] = sellerProductsInOrder;

          // Add buyer to unique buyers set
          uniqueBuyerIds.add(order.buyerId);
        }
      }

      // Total orders is the number of orders that contain this seller's products
      totalOrders = orderProductMap.length;

      return {
        'totalRevenue': totalRevenue,
        'totalOrders': totalOrders,
        'totalProducts': totalProducts,
        'uniqueBuyers': uniqueBuyerIds.length,
      };
    } catch (e) {
      throw Exception("Failed to fetch dashboard data: $e");
    }
  }

  // Method to get recent orders that contain products from this seller
  Future<List<OrderModel>> getRecentOrders(
    String sellerId, {
    int limit = 5,
  }) async {
    try {
      // First get all products for this seller
      final productSnapshot =
          await _db
              .collection('products')
              .where('sellerId', isEqualTo: sellerId)
              .get();

      final products =
          productSnapshot.docs
              .map((doc) => ProductModel.fromMap(doc.data()))
              .toList();

      // Create a set of product IDs that belong to this seller
      final sellerProductIds = products.map((product) => product.id).toSet();

      // Get all recent orders
      final orderSnapshot =
          await _db
              .collection('orders')
              .orderBy('orderDate', descending: true)
              .get();

      // Filter orders that contain products from this seller
      final sellerOrders =
          orderSnapshot.docs
              .map((doc) => OrderModel.fromMap(doc.data()))
              .where(
                (order) => order.productIds.any(
                  (productId) => sellerProductIds.contains(productId),
                ),
              )
              .take(limit)
              .toList();

      return sellerOrders;
    } catch (e) {
      throw Exception("Failed to fetch recent orders: $e");
    }
  }

  // Method to get low stock items
  Future<List<ProductModel>> getLowStockItems(String sellerId) async {
    try {
      final productSnapshot =
          await _db
              .collection('products')
              .where('sellerId', isEqualTo: sellerId)
              .where('stock', isLessThanOrEqualTo: lowStockThreshold)
              .where('status', isEqualTo: ProductStatus.Active.name)
              .get();

      return productSnapshot.docs
          .map((doc) => ProductModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception("Failed to fetch low stock items: $e");
    }
  }

  // Method to get monthly order data for the chart, filtered by seller's products
  Future<List<Map<String, dynamic>>> getMonthlyOrdersData(
    String sellerId,
  ) async {
    try {
      // Get start of current month
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfNextMonth = DateTime(now.year, now.month + 1, 1);

      // First get all products for this seller
      final productSnapshot =
          await _db
              .collection('products')
              .where('sellerId', isEqualTo: sellerId)
              .get();

      final products =
          productSnapshot.docs
              .map((doc) => ProductModel.fromMap(doc.data()))
              .toList();

      // Create a set of product IDs and a map of product ID to price
      final sellerProductIds = products.map((product) => product.id).toSet();
      final productPriceMap = {
        for (var product in products) product.id: product.price,
      };

      // Get all orders for this month
      final orderSnapshot =
          await _db
              .collection('orders')
              .where('orderDate', isGreaterThanOrEqualTo: startOfMonth)
              .where('orderDate', isLessThan: startOfNextMonth)
              .orderBy('orderDate')
              .get();

      final allOrders =
          orderSnapshot.docs
              .map((doc) => OrderModel.fromMap(doc.data()))
              .toList();

      // Group orders by day, but only count seller's products
      final Map<int, int> orderCountByDay = {};
      final Map<int, double> revenueByDay = {};

      for (var order in allOrders) {
        // Filter product IDs to only those belonging to this seller
        final sellerProductsInOrder =
            order.productIds
                .where((productId) => sellerProductIds.contains(productId))
                .toList();

        if (sellerProductsInOrder.isNotEmpty) {
          final day = order.orderDate.day;

          // Calculate revenue from seller's products in this order
          double orderRevenueForSeller = 0.0;
          for (var productId in sellerProductsInOrder) {
            orderRevenueForSeller += productPriceMap[productId] ?? 0;
          }

          // Increment order count for this day
          orderCountByDay[day] = (orderCountByDay[day] ?? 0) + 1;

          // Add revenue for this day
          revenueByDay[day] = (revenueByDay[day] ?? 0) + orderRevenueForSeller;
        }
      }

      // Create data points for the chart
      final List<Map<String, dynamic>> chartData = [];
      for (int day = 1; day <= now.day; day++) {
        chartData.add({
          'day': day,
          'orders': orderCountByDay[day] ?? 0,
          'revenue': revenueByDay[day] ?? 0.0,
        });
      }

      return chartData;
    } catch (e) {
      throw Exception("Failed to fetch monthly orders data: $e");
    }
  }

  // Method to get order data for a specific month and year
  Future<List<Map<String, dynamic>>> getOrdersForMonth(
    String sellerId,
    int month,
    int year,
  ) async {
    try {
      final startOfMonth = DateTime(year, month, 1);
      final startOfNextMonth =
          month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);

      // First get all products for this seller
      final productSnapshot =
          await _db
              .collection('products')
              .where('sellerId', isEqualTo: sellerId)
              .get();

      final products =
          productSnapshot.docs
              .map((doc) => ProductModel.fromMap(doc.data()))
              .toList();

      // Create a set of product IDs and a map of product ID to price
      final sellerProductIds = products.map((product) => product.id).toSet();
      final productPriceMap = {
        for (var product in products) product.id: product.price,
      };

      // Get all orders for the specified month
      final orderSnapshot =
          await _db
              .collection('orders')
              .where('orderDate', isGreaterThanOrEqualTo: startOfMonth)
              .where('orderDate', isLessThan: startOfNextMonth)
              .orderBy('orderDate')
              .get();

      final allOrders =
          orderSnapshot.docs
              .map((doc) => OrderModel.fromMap(doc.data()))
              .toList();

      // Get the number of days in the month
      final daysInMonth = DateTime(year, month + 1, 0).day;

      // Initialize data for all days of the month
      final List<Map<String, dynamic>> chartData = [];
      for (int day = 1; day <= daysInMonth; day++) {
        chartData.add({
          'day': day,
          'date': DateFormat('MM/dd').format(DateTime(year, month, day)),
          'orders': 0,
          'revenue': 0.0,
        });
      }

      // Update with actual order data that contains this seller's products
      for (var order in allOrders) {
        // Filter product IDs to only those belonging to this seller
        final sellerProductsInOrder =
            order.productIds
                .where((productId) => sellerProductIds.contains(productId))
                .toList();

        if (sellerProductsInOrder.isNotEmpty) {
          final day = order.orderDate.day;

          // Calculate revenue from seller's products in this order
          double orderRevenueForSeller = 0.0;
          for (var productId in sellerProductsInOrder) {
            orderRevenueForSeller += productPriceMap[productId] ?? 0;
          }

          // Update chart data
          chartData[day - 1]['orders'] += 1;
          chartData[day - 1]['revenue'] += orderRevenueForSeller;
        }
      }

      return chartData;
    } catch (e) {
      throw Exception("Failed to fetch orders for month: $e");
    }
  }

  // Method to get best selling products
  Future<List<Map<String, dynamic>>> getBestSellingProducts(
    String sellerId, {
    int limit = 5,
  }) async {
    try {
      // First get all products for this seller
      final productSnapshot =
          await _db
              .collection('products')
              .where('sellerId', isEqualTo: sellerId)
              .get();

      final products =
          productSnapshot.docs
              .map((doc) => ProductModel.fromMap(doc.data()))
              .toList();

      // Create a set of product IDs
      final sellerProductIds = products.map((product) => product.id).toSet();

      // Get all orders
      final orderSnapshot = await _db.collection('orders').get();

      final allOrders =
          orderSnapshot.docs
              .map((doc) => OrderModel.fromMap(doc.data()))
              .toList();

      // Count product occurrences, but only for this seller's products
      final Map<String, int> productOccurrences = {};
      for (var order in allOrders) {
        for (var productId in order.productIds) {
          if (sellerProductIds.contains(productId)) {
            productOccurrences[productId] =
                (productOccurrences[productId] ?? 0) + 1;
          }
        }
      }

      // Sort product IDs by occurrences (descending)
      final sortedProductIds =
          productOccurrences.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      // Get top products details
      final List<Map<String, dynamic>> bestSellers = [];
      for (int i = 0; i < sortedProductIds.length && i < limit; i++) {
        final productId = sortedProductIds[i].key;
        final occurrences = sortedProductIds[i].value;

        // Find product in our products list (should always be found)
        final productData = products.firstWhere(
          (p) => p.id == productId,
          orElse:
              () =>
                  null as ProductModel, // This will throw if product not found
        );

        if (productData != null) {
          bestSellers.add({'product': productData, 'salesCount': occurrences});
        }
      }

      return bestSellers;
    } catch (e) {
      throw Exception("Failed to fetch best selling products: $e");
    }
  }
}
