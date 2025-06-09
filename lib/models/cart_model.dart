class CartModel {
  final String buyerId; // Reference to the user
  final List<String> productIds; // List of product IDs in the cart

  CartModel({required this.buyerId, required this.productIds});

  factory CartModel.fromMap(Map<String, dynamic> data) {
    return CartModel(
      buyerId: data['buyerId'],
      productIds: List<String>.from(data['productIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {'buyerId': buyerId, 'productIds': productIds};
  }
}
