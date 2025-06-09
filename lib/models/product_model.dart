enum ProductStatus { Active, Draft, OutOfStock }

class ProductModel {
  final String id;
  final String name;
  final String description;
  final int stock;
  final String category;
  final ProductStatus status;
  final double price;
  final String imageUrl;
  final double rating;
  final String sellerId;

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.stock,
    required this.category,
    required this.status,
    required this.price,
    required this.rating,
    required this.imageUrl,
    required this.sellerId,
  });

  factory ProductModel.fromMap(Map<String, dynamic> data) {
    // Read status string and map to enum, default to Active if missing/invalid
    final rawStatus = (data['status'] as String?) ?? '';
    final status = ProductStatus.values.firstWhere(
      (e) => e.name == rawStatus,
      orElse: () => ProductStatus.Active,
    );

    return ProductModel(
      id: data['id'] as String,
      name: data['name'] as String,
      description: data['description'] as String,
      stock: (data['stock'] as int?) ?? 0,
      category: data['category'] as String,
      status: status,
      price: (data['price'] as num).toDouble(),
      rating: (data['rating'] as num).toDouble(),
      imageUrl: data['imageUrl'] as String,
      sellerId: data['sellerId'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'stock': stock,
      'category': category,
      'status': status.name, // store enum name as string
      'price': price,
      'rating': rating,
      'imageUrl': imageUrl,
      'sellerId': sellerId,
    };
  }
}
