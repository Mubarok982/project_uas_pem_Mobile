import 'package:flutter/material.dart'; // ✅ Jangan lupa uncomment ini
import 'package:go_router/go_router.dart';

// --- AUTH ---
import 'package:veriaga/features/auth/presentation/login_page.dart';
import 'package:veriaga/features/auth/presentation/register_page.dart';

// --- SUPPLIER ---
import 'package:veriaga/features/supplier/dashboard/supplier_main.dart'; 
import 'package:veriaga/features/supplier/product/add_product.dart';
import 'package:veriaga/features/supplier/product/edit_product.dart'; 
import 'package:veriaga/features/supplier/manage_product/supplier_dispute.dart';
import 'package:veriaga/features/supplier/dashboard/supplier_profile.dart'; 
import 'package:veriaga/features/supplier/chat/supplier_chat.dart'; 

// --- BUYER ---
import 'package:veriaga/features/buyer/presentation/halaman_utama.dart'; 
import 'package:veriaga/features/buyer/cart/detail_product.dart';
import 'package:veriaga/features/buyer/orders/halaman_checkout.dart';
import 'package:veriaga/features/buyer/orders/verifikasi_ai.dart';
import 'package:veriaga/features/buyer/profile/edit_profil.dart';

// --- COMMON (UMUM) ---
import 'package:veriaga/features/common/halaman_chat.dart'; // ✅ Import Chat Page disini

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    // 1. LOGIN
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    
    // 2. REGISTER
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    
    // ✅ 3. RUTE SUPPLIER HOME (Solusi Error 'no routes')
    GoRoute(
      path: '/supplier/home',
      builder: (context, state) => const SupplierMainPage(),
    ),

    // 4. DASHBOARD (Rute Utama Buyer / Fallback)
    GoRoute(
      path: '/dashboard',
      builder: (context, state) {
        // Logika safety: Kalau ada extra 'supplier', lempar ke SupplierMainPage
        // Tapi normalnya Buyer langsung kesini.
        final role = state.extra as String? ?? 'buyer';
        
        if (role == 'supplier') {
          return const SupplierMainPage();
        } else {
          return const BuyerMainPage(); 
        }
      },
    ),
    
    // --- SUB-HALAMAN SUPPLIER ---
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
    
    // --- SUB-HALAMAN BUYER ---
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
        // Ambil data (support format lama & baru)
        final extra = state.extra as Map<String, dynamic>;
        return VerifikasiAI(data: extra);
      },
    ),
    GoRoute(
      path: '/buyer/edit-profile',
      builder: (context, state) {
        final currentData = state.extra as Map<String, dynamic>?; 
        return BuyerEditProfilePage(currentData: currentData);
      },
    ),

    // --- HALAMAN CHAT (UMUM) ---
    GoRoute(
      path: '/chat',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return ChatPage(
          partnerId: data['partnerId'], 
          partnerName: data['partnerName'],
          initialMessage: data['initialMessage'],
        );
      },
    ),
  ],
);