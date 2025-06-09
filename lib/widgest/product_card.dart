import 'package:flutter/material.dart';

class ProductCard extends StatelessWidget {
  final String name;
  final String imageUrl;
  final double price;

  const ProductCard({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Image.network(imageUrl, height: 100, fit: BoxFit.cover),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text("\$${price.toStringAsFixed(2)}"),
        ],
      ),
    );
  }
}
