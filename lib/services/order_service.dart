import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smeapp/models/order_model.dart';
import 'package:smeapp/models/product_model.dart';

class OrderService {
  final CollectionReference ordersRef = FirebaseFirestore.instance.collection(
    "orders",
  );

  // Create new order
  Future<void> createOrder(OrderModel order) async {
    try {
      await ordersRef.doc(order.id).set(order.toMap());
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  // Get orders by sellerId
  Future<List<OrderModel>> getOrdersBySellerId(String sellerId) async {
    try {
      final snapshot =
          await ordersRef.where('sellerId', isEqualTo: sellerId).get();
      return snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get orders by sellerId: $e');
    }
  }

  // Get order by buyerId
  Future<List<OrderModel>> getOrdersByBuyerId(String buyerId) async {
    try {
      final snapshot =
          await ordersRef.where('buyerId', isEqualTo: buyerId).get();
      return snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get orders by buyerId: $e');
    }
  }

  // Update order status
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final CollectionReference ordersRef = FirebaseFirestore.instance.collection(
      'orders',
    );
    final CollectionReference productsRef = FirebaseFirestore.instance
        .collection('products');

    const allowedStatuses = ['processing', 'shipped', 'completed', 'cancelled'];
    if (!allowedStatuses.contains(newStatus)) {
      throw Exception('Invalid status: $newStatus');
    }

    try {
      // First, get the current order data
      final DocumentSnapshot orderDoc = await ordersRef.doc(orderId).get();
      if (!orderDoc.exists) {
        throw Exception('Order not found: $orderId');
      }

      final OrderModel order = OrderModel.fromMap(
        orderDoc.data() as Map<String, dynamic>,
      );

      // Only decrease stock when order status changes to 'shipped' or 'completed'
      if ((newStatus == 'shipped' || newStatus == 'completed') &&
          (order.status != 'shipped' && order.status != 'completed')) {
        // Update stock for each product in the order
        for (String productId in order.productIds) {
          final DocumentSnapshot productDoc =
              await productsRef.doc(productId).get();

          if (productDoc.exists) {
            final ProductModel product = ProductModel.fromMap(
              productDoc.data() as Map<String, dynamic>,
            );

            // Decrease stock by 1
            int newStock = product.stock - 1;
            if (newStock < 0) newStock = 0;

            // Update product stock
            await productsRef.doc(productId).update({
              'stock': newStock,
              // If stock becomes 0, update status to OutOfStock
              if (newStock == 0) 'status': ProductStatus.OutOfStock.name,
            });
          }
        }
      }

      // Finally update the order status
      await ordersRef.doc(orderId).update({'status': newStatus});
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  // Get All the Orders
  Future<List<OrderModel>> getAllOrders() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('orders').get();
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        data['id'] = doc.id;
        return OrderModel.fromMap(data);
      }).toList();
    } catch (e) {
      print("Error fetching all orders: $e");
      return [];
    }
  }
}
