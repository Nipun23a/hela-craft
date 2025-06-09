import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smeapp/models/cart_model.dart';

class CartService {
  final CollectionReference cartRef = FirebaseFirestore.instance.collection(
    'carts',
  );

  /// Check if cart exists for the given userId
  Future<bool> hasActiveCart(String buyerId) async {
    final doc = await cartRef.doc(buyerId).get();
    return doc.exists;
  }

  Future<void> addItemToCart(String buyerId, String productId) async {
    final docRef = cartRef.doc(buyerId);
    final doc = await docRef.get();

    if (!doc.exists) {
      // Create new cart
      final newCart = CartModel(buyerId: buyerId, productIds: [productId]);
      await docRef.set(newCart.toMap());
    } else {
      // Update existing cart
      final existingData = doc.data() as Map<String, dynamic>;
      final existingCart = CartModel.fromMap(existingData);

      // Avoid duplicates
      if (!existingCart.productIds.contains(productId)) {
        existingCart.productIds.add(productId);
        await docRef.update({'productIds': existingCart.productIds});
      }
    }
  }

  /// Remove the entire cart for a user
  Future<void> removeCart(String buyerId) async {
    final docRef = cartRef.doc(buyerId);
    final doc = await docRef.get();

    if (doc.exists) {
      await docRef.delete();
    }
  }

  /// Get cart by buyer ID — if no cart exists, create an empty one
  Future<CartModel?> getCartByBuyerId(String buyerId) async {
    final docRef = cartRef.doc(buyerId);
    final doc = await docRef.get();

    if (!doc.exists) {
      // Create an empty cart
      final emptyCart = CartModel(buyerId: buyerId, productIds: []);
      await docRef.set(emptyCart.toMap());
      return emptyCart;
    }

    return CartModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  /// Remove a product from the cart
  Future<void> removeProductFromCart(String buyerId, String productId) async {
    final docRef = cartRef.doc(buyerId);
    final doc = await docRef.get();

    if (!doc.exists) {
      // Nothing to remove if cart doesn't exist
      return;
    }

    final cartData = CartModel.fromMap(doc.data() as Map<String, dynamic>);
    final updatedProductIds = List<String>.from(cartData.productIds)
      ..remove(productId);

    await docRef.update({'productIds': updatedProductIds});
  }
}
