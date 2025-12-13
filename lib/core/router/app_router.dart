import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Import halaman-halaman
import 'package:veriaga/features/auth/presentation/login_page.dart';
import 'package:veriaga/features/auth/presentation/register_page.dart';
import 'package:veriaga/features/supplier/presentation/supplier_main_page.dart'; 
import 'package:veriaga/features/supplier/presentation/pages/product/add_product_page.dart';
import 'package:veriaga/features/supplier/presentation/pages/product/edit_product_page.dart'; // ✅ TAMBAHAN IMPORT
import 'package:veriaga/features/supplier/presentation/pages/supplier_dispute_page.dart';
import 'package:veriaga/features/supplier/presentation/pages/supplier_profile_page.dart'; // Import Baru

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
    
    // 3. Dashboard (Pemisah Role)
    GoRoute(
      path: '/dashboard',
      builder: (context, state) {
        final role = state.extra as String? ?? 'buyer';
        
        if (role == 'supplier') {
          return const SupplierMainPage();
        } else {
          return const Scaffold(
            body: Center(child: Text("Halaman Pembeli (Segera Hadir)")),
          );
        }
      },
    ),
    
    // 4. Tambah Produk
    GoRoute(
      path: '/supplier/add-product',
      builder: (context, state) => const AddProductPage(),
    ),

    // 5. Edit Produk (✅ RUTE BARU)
    GoRoute(
      path: '/supplier/edit-product',
      builder: (context, state) {
        // Kita menangkap data produk yang dikirim lewat parameter 'extra'
        // Data ini dikirim dari tombol Edit di SupplierProductPage
        final product = state.extra as Map<String, dynamic>; 
        return EditProductPage(product: product);
      },
    ),
    // 6. Halaman Dispute Supplier
    GoRoute(
      path: '/supplier/dispute-detail',
      builder: (context, state) {
        final orderId = state.extra as String;
        return SupplierDisputePage(orderId: orderId);
      },
    ),
    // 7. Halaman Profil Supplier 
    GoRoute(
      path: '/supplier/profile',
      builder: (context, state) => const SupplierProfilePage(),
    ),
  ],
);