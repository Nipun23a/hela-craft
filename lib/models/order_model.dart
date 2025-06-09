import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String buyerId;
  final String orderAddress;
  final String orderPhone;
  final List<String> productIds;
  final double totalPrice;
  String status;
  final DateTime orderDate;

  OrderModel({
    required this.id,
    required this.buyerId,
    required this.productIds,
    required this.totalPrice,
    required this.status,
    required this.orderAddress,
    required this.orderPhone,
    required this.orderDate,
  });

  factory OrderModel.fromMap(Map<String, dynamic> data) {
    return OrderModel(
      id: data['id'],
      buyerId: data['buyerId'],
      productIds: List<String>.from(data['productIds']),
      totalPrice: (data['totalPrice'] as num).toDouble(),
      status: data['status'],
      orderPhone: data['orderPhone'] ?? '',
      orderAddress: data['orderAddress'] ?? '',
      orderDate: (data['orderDate'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'buyerId': buyerId,
      'productIds': productIds,
      'totalPrice': totalPrice,
      'status': status,
      'orderAddress': orderAddress,
      'orderPhone': orderPhone,
      'orderDate': orderDate, // Firestore will store this as a Timestamp
    };
  }
}
