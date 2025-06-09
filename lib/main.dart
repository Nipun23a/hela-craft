import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:smeapp/models/product_model.dart';
import 'package:smeapp/screens/buyer/buyer_cart_screen.dart';
import 'package:smeapp/screens/buyer/buyer_checkout_screen.dart';
import 'package:smeapp/screens/buyer/buyer_product_detail.dart';
import 'package:smeapp/screens/buyer/buyer_profile_screen.dart';
import 'firebase_options.dart';
import 'screens/getstart.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/buyer/buyer_home_screen.dart';
import 'screens/seller_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ); // ✅ Use firebase_options.dart here
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SME App',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => const GetStartedPage(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/buyerHome': (context) => const BuyerHomeScreen(),
        '/sellerHome': (context) => const SellerDashboardScreen(),
        '/profile': (context) => const BuyerProfileScreen(),
        '/cart': (context) => const CartScreen(),
        '/productDetails': (context) {
          final product =
              ModalRoute.of(context)!.settings.arguments as ProductModel;
          return ProductDetailScreen(product: product);
        },
      },
      // Handle checkout route separately since it needs parameters
      onGenerateRoute: (settings) {
        if (settings.name == '/checkout') {
          // Extract the arguments if they exist
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null) {
            return MaterialPageRoute(
              builder:
                  (context) => CheckoutScreen(
                    cartItems: args['cartItems'],
                    subtotal: args['subtotal'],
                  ),
            );
          }
          // Fallback if there are no arguments - redirect to cart
          return MaterialPageRoute(builder: (context) => const CartScreen());
        }
        return null;
      },
    );
  }
}
