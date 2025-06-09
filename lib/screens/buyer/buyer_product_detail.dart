import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smeapp/models/product_model.dart';
import 'package:smeapp/models/user_model.dart';
import 'package:smeapp/screens/buyer/buyer_cart_screen.dart';
import 'package:smeapp/services/auth_service.dart';
import 'package:smeapp/services/cart_service.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  UserModel? _seller;
  bool _isLoadingSeller = true;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadSeller();
  }

  Future<void> _loadSeller() async {
    try {
      final seller = await _authService.getUserById(widget.product.sellerId);
      setState(() {
        _seller = seller;
        _isLoadingSeller = false;
      });
    } catch (e) {
      print("Error loading seller info: $e");
      setState(() {
        _isLoadingSeller = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildProductImage(context),
          Expanded(child: _buildProductDetails(context)),
        ],
      ),
    );
  }

  Widget _buildProductImage(BuildContext context) {
    return Stack(
      children: [
        Hero(
          tag: widget.product.id,
          child: Container(
            height: 300,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(widget.product.imageUrl),
                fit: BoxFit.cover,
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(30),
              ),
            ),
          ),
        ),

        // ✅ AppBar overlay (logo + wishlist + cart)
        Positioned(top: 40, left: 0, right: 0, child: _buildAppBar()),
      ],
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Back button
          CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.black,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),

          // Right: Wishlist + Cart with badge
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.favorite_border_rounded),
                color: Colors.grey[700],
                onPressed: () {
                  Navigator.pushNamed(context, '/wishlist');
                },
              ),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined),
                    color: Colors.grey[700],
                    onPressed: () {
                      Navigator.pushNamed(context, '/cart');
                    },
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF7B00),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: const Text(
                        '3', // Make this dynamic for real usage
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductDetails(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price + Free Delivery Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Rs. ${widget.product.price.toStringAsFixed(2)}",
                style: GoogleFonts.nunito(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF6A11CB),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.local_shipping, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    "Free Delivery",
                    style: GoogleFonts.nunito(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Category and Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.product.category,
                  style: GoogleFonts.nunito(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Chip(
                label: Text(
                  widget.product.status == ProductStatus.OutOfStock
                      ? "Out of Stock"
                      : "In Stock",
                  style: TextStyle(
                    color:
                        widget.product.status == ProductStatus.OutOfStock
                            ? Colors.red
                            : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor:
                    widget.product.status == ProductStatus.OutOfStock
                        ? Colors.red[50]
                        : Colors.green[50],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Seller Info
          _buildSellerInfo(),
          const SizedBox(height: 20),

          // Product Description
          Text(
            "Description",
            style: GoogleFonts.raleway(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.product.description,
            style: GoogleFonts.nunito(
              fontSize: 15,
              color: Colors.grey[800],
              height: 1.5,
            ),
          ),
          const Spacer(),

          // Add to Cart Button
          _buildAddToCartButton(context),
        ],
      ),
    );
  }

  Widget _buildSellerInfo() {
    if (_isLoadingSeller) {
      return const CircularProgressIndicator();
    }

    if (_seller == null) {
      return Text(
        "Seller information unavailable",
        style: GoogleFonts.nunito(color: Colors.red[400]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.deepPurple[100],
            child: Text(
              _seller!.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.black87),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _seller!.name,
                  style: GoogleFonts.raleway(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _seller!.email,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.deepPurple[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              "Verified",
              style: TextStyle(color: Colors.deepPurple),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Rs. ${widget.product.price.toStringAsFixed(2)}",
          style: GoogleFonts.nunito(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6A11CB),
          ),
        ),
        Row(
          children: [
            Icon(Icons.local_shipping, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              "Free Delivery",
              style: GoogleFonts.nunito(color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddToCartButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final user = await _authService.getLocalUser();
          if (user['uid'] != null && user['uid']!.isNotEmpty) {
            await CartService().addItemToCart(user['uid']!, widget.product.id);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${widget.product.name} added to cart'),
                backgroundColor: Colors.green[600],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("User not logged in"),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        icon: const Icon(Icons.shopping_cart_checkout_rounded),
        label: Text(
          "Add to Cart",
          style: GoogleFonts.raleway(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6A11CB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 3,
        ),
      ),
    );
  }
}
