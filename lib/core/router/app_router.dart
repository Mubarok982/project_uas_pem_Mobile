//import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Import semua halaman
import 'package:veriaga/features/auth/presentation/login_page.dart';
import 'package:veriaga/features/auth/presentation/register_page.dart';
import 'package:veriaga/features/supplier/presentation/supplier_main_page.dart'; 
import 'package:veriaga/features/supplier/presentation/pages/product/add_product_page.dart';
import 'package:veriaga/features/supplier/presentation/pages/product/edit_product_page.dart'; 
import 'package:veriaga/features/supplier/presentation/pages/supplier_dispute_page.dart';
import 'package:veriaga/features/supplier/presentation/pages/supplier_profile_page.dart'; 
import 'package:veriaga/features/buyer/presentation/buyer_main_page.dart'; // Pastikan import ini ada
import 'package:veriaga/features/buyer/cart/buyer_product_detail_page.dart';
import 'package:veriaga/features/buyer/orders/halaman_checkout.dart';
import 'package:veriaga/features/buyer/orders/verifikasiAI.dart';






final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    // 1. Login
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    
    // 2. Register
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    
    // 3. Dashboard (Logika Percabangan Peran)
    GoRoute(
      path: '/dashboard',
      builder: (context, state) {
        // Ambil role, default ke 'buyer' jika null
        final role = state.extra as String? ?? 'buyer';
        
        if (role == 'supplier') {
          return const SupplierMainPage();
        } else {
          // ✅ PERBAIKAN: Langsung arahkan ke BuyerMainPage
          return const BuyerMainPage(); 
        }
      },
    ),
    
    // --- RUTE SUPPLIER ---
    GoRoute(
      path: '/supplier/add-product',
      builder: (context, state) => const AddProductPage(),
    ),
    GoRoute(
      path: '/supplier/edit-product',
      builder: (context, state) {
        final product = state.extra as Map<String, dynamic>; 
        return EditProductPage(product: product);
      },
    ),
    GoRoute(
      path: '/supplier/dispute-detail',
      builder: (context, state) {
        final orderId = state.extra as String;
        return SupplierDisputePage(orderId: orderId);
      },
    ),
    GoRoute(
      path: '/supplier/profile',
      builder: (context, state) => const SupplierProfilePage(),
    ),
    // --- RUTE BUYER ---
    GoRoute(
      path: '/buyer/product-detail',
      builder: (context, state) {
        final product = state.extra as Map<String, dynamic>;
        return BuyerProductDetailPage(product: product);
      },
    ),
    GoRoute(
      path: '/buyer/checkout',
      builder: (context, state) => const BuyerCheckoutPage(),
    ),
    GoRoute(
      path: '/buyer/verify-ai',
      builder: (context, state) {
        final order = state.extra as Map<String, dynamic>;
        return BuyerAiVerificationPage(order: order);
      },
    )
  ],
);