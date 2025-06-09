import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smeapp/models/product_model.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _productRef;

  ProductService()
    : _productRef = FirebaseFirestore.instance.collection('products');

  // Add New Product to firestore
  Future<String> addProduct(Map<String, dynamic> productData) async {
    try {
      final docRef = await _productRef.add(productData);
      // Update the document with its ID
      await docRef.update({'id': docRef.id});
      return docRef.id;
    } catch (e) {
      throw Exception("Failed to add product: $e");
    }
  }

  // Get All Products
  Future<List<ProductModel>> getProducts() async {
    try {
      final snapshot = await _productRef.get();
      return snapshot.docs.map((doc) {
        // Combine doc ID with data
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        // Make sure id is available in the data
        data['id'] = doc.id;
        return ProductModel.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error fetching products: $e');
      return [];
    }
  }

  // Get product details by product ID
  Future<ProductModel> getProductById(String id) async {
    try {
      final doc = await _productRef.doc(id).get();
      if (!doc.exists) {
        throw Exception("Product not found");
      } else {
        // Combine doc ID with data
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return ProductModel.fromMap(data);
      }
    } catch (e) {
      throw Exception("Failed to get product: $e");
    }
  }

  // Update existing product
  Future<void> updateProduct(ProductModel product) async {
    try {
      await _productRef.doc(product.id).update(product.toMap());
    } catch (e) {
      throw Exception("Failed to update product: $e");
    }
  }

  // Get Products belonging to a specific seller
  Future<List<ProductModel>> getProductsBySeller(String sellerId) async {
    try {
      print('Fetching products for seller: $sellerId');
      final query =
          await _productRef.where('sellerId', isEqualTo: sellerId).get();

      print('Query completed. Found ${query.docs.length} products');

      return query.docs.map((doc) {
        // Combine doc ID with data
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        print('Processing product: ${doc.id}');
        return ProductModel.fromMap(data);
      }).toList();
    } catch (e, stackTrace) {
      print('Error fetching products by seller: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  // Delete product
  Future<void> deleteProduct(String id) async {
    try {
      await _productRef.doc(id).delete();
    } catch (e) {
      throw Exception("Failed to delete product: $e");
    }
  }

  Future<void> deactivateProduct(String productId) {
    return _productRef.doc(productId).update({
      'status': ProductStatus.Draft.name,
    });
  }

  Future<void> activateProduct(String productId) {
    return _productRef.doc(productId).update({
      'status': ProductStatus.Active.name,
    });
  }

  Stream<List<Map<String, dynamic>>> getProductsStream() {
    return _productRef.orderBy('dateAdded', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    });
  }

  // If you need to filter by sellerId
  Stream<List<ProductModel>> getProductsBySellerStream(String sellerId) {
    return _productRef
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('dateAdded', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return ProductModel.fromMap(data);
          }).toList();
        });
  }

  // Get Product by Id
  Future<List<ProductModel>> getProductsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final snapshots =
        await _productRef.where(FieldPath.documentId, whereIn: ids).get();
    return snapshots.docs
        .map((doc) => ProductModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  Future<List<ProductModel>> getNewlyAddedProducts({int limit = 10}) async {
    try {
      final snapshot =
          await _productRef
              .orderBy('dateAdded', descending: true)
              .limit(limit)
              .get();

      return snapshot.docs
          .map(
            (doc) => ProductModel.fromMap(doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw Exception("Failed to fetch newly added products: $e");
    }
  }

  Future<List<ProductModel>> getRandomFeaturedProducts({int limit = 5}) async {
    try {
      final snapshot =
          await _productRef
              .where('status', isEqualTo: ProductStatus.Active.name)
              .get();

      final allProducts =
          snapshot.docs
              .map(
                (doc) =>
                    ProductModel.fromMap(doc.data() as Map<String, dynamic>),
              )
              .toList();

      allProducts.shuffle();
      return allProducts.take(limit).toList();
    } catch (e) {
      throw Exception("Failed to fetch random featured products: $e");
    }
  }
}
