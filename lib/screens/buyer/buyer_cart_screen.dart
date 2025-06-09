import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smeapp/models/cart_model.dart';
import 'package:smeapp/models/product_model.dart';
import 'package:smeapp/models/user_model.dart';
import 'package:smeapp/services/cart_service.dart';
import 'package:smeapp/services/product_service.dart';
import 'package:smeapp/services/auth_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<ProductModel> _productsInCart = [];
  final CartService _cartService = CartService();
  final ProductService _productService = ProductService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  Map<String, UserModel> _sellers = {};

  @override
  void initState() {
    super.initState();
    _loadCartProducts();
  }

  Future<void> _loadCartProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.getLocalUser();
      final cart = await _cartService.getCartByBuyerId(user['uid']!);
      final productIds = cart?.productIds ?? [];

      final products = await _productService.getProductsByIds(productIds);

      // Load unique sellers for the cart products
      final sellerIds = products.map((p) => p.sellerId).toSet();
      Map<String, UserModel> sellersMap = {};

      for (String sellerId in sellerIds) {
        try {
          final seller = await _authService.getUserById(sellerId);
          sellersMap[sellerId] = seller!;
        } catch (e) {
          print("Failed to fetch seller $sellerId: $e");
        }
      }

      setState(() {
        _productsInCart = products;
        _sellers = sellersMap;
      });
    } catch (e) {
      print('Failed to load cart products: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _removeItem(ProductModel product) async {
    final user = await _authService.getLocalUser();

    // Remove from backend
    await _cartService.removeProductFromCart(user['uid']!, product.id);

    setState(() {
      _productsInCart.removeWhere((p) => p.id == product.id);
    });

    // Show snackbar with undo option
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} removed from cart'),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.amber,
          onPressed: () async {
            await _cartService.addItemToCart(user['uid']!, product.id);
            _loadCartProducts(); // Reload cart products from backend
          },
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  double get _subtotal {
    return _productsInCart.fold(0.0, (sum, product) => sum + product.price);
  }

  double get _deliveryFee {
    // Sample delivery fee calculation logic
    return _subtotal > 100 ? 0.0 : 10.0;
  }

  double get _totalPrice {
    return _subtotal + _deliveryFee;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _productsInCart.isEmpty
              ? _buildEmptyCart()
              : _buildCartContent(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_rounded,
          color: Color(0xFF333333),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Your Cart',
        style: GoogleFonts.raleway(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF333333),
        ),
      ),
      actions: [
        if (_productsInCart.isNotEmpty)
          TextButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: Text(
                        'Clear Cart',
                        style: GoogleFonts.raleway(fontWeight: FontWeight.bold),
                      ),
                      content: const Text(
                        'Are you sure you want to remove all items?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final user = await _authService.getLocalUser();
                            await _cartService.removeCart(user['uid']!);

                            setState(() {
                              _productsInCart.clear();
                            });

                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Clear',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
              );
            },
            icon: const Icon(Icons.delete_outline, color: Color(0xFF6A11CB)),
            label: const Text(
              'Clear',
              style: TextStyle(color: Color(0xFF6A11CB)),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Your cart is empty',
            style: GoogleFonts.raleway(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Looks like you haven\'t added\nanything to your cart yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              // Navigate to products screen
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A11CB),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              'Start Shopping',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartContent() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 10),
            itemCount: _productsInCart.length,
            itemBuilder: (context, index) {
              final product = _productsInCart[index];
              return _buildCartItem(
                product,
              ); // Update this to accept ProductModel
            },
          ),
        ),
        _buildCartSummary(),
      ],
    );
  }

  Widget _buildCartItem(ProductModel item) {
    final sellerName = _sellers[item.sellerId]?.name ?? 'Unknown Seller';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                item.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder:
                    (context, error, stackTrace) => Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
              ),
            ),
            const SizedBox(width: 12),

            // Product details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _removeItem(item),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "by $sellerName",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "\Rs. ${item.price.toStringAsFixed(2)}",
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: const Color(0xFF6A11CB),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Order Summary",
            style: GoogleFonts.raleway(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow("Subtotal", _subtotal),
          _buildSummaryRow("Delivery Fee", _deliveryFee),
          const Divider(height: 24),
          _buildSummaryRow("Total", _totalPrice, isTotal: true),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/checkout',
                  arguments: {
                    'cartItems': _productsInCart,
                    'subtotal': _subtotal,
                    'deliveryFee': _deliveryFee,
                    'totalPrice': _totalPrice,
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A11CB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
              child: Text(
                "Proceed to Checkout",
                style: GoogleFonts.raleway(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.arrow_back_rounded,
                size: 16,
                color: Color(0xFF6A11CB),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(
                  "Continue Shopping",
                  style: GoogleFonts.nunito(
                    color: const Color(0xFF6A11CB),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String title, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.nunito(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? const Color(0xFF333333) : Colors.grey[700],
            ),
          ),
          Text(
            "\Rs. ${amount.toStringAsFixed(2)}",
            style: GoogleFonts.nunito(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? const Color(0xFF6A11CB) : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
