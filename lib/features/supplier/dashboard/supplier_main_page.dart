import 'package:flutter/material.dart';
import 'package:veriaga/features/supplier/dashboard/supplier_home_page.dart';
import 'package:veriaga/features/supplier/manage_product/supplier_product_page.dart';
import 'package:veriaga/features/supplier/manage_product/supplier_order_page.dart';

class SupplierMainPage extends StatefulWidget {
  const SupplierMainPage({super.key});

  @override
  State<SupplierMainPage> createState() => _SupplierMainPageState();
}

class _SupplierMainPageState extends State<SupplierMainPage> {
  int _currentIndex = 0;

  // Daftar Halaman
  final List<Widget> _pages = [
    const SupplierHomePage(),    // Index 0
    const SupplierProductPage(), // Index 1
    const SupplierOrderPage(),   // Index 2
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ PERBAIKAN: Gunakan IndexedStack agar halaman tidak reload saat ganti tab
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        // Sedikit styling agar lebih terlihat profesional
        indicatorColor: const Color(0xFF0F172A).withOpacity(0.1),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Color(0xFF0F172A)),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: Color(0xFF0F172A)),
            label: 'Produk',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: Color(0xFF0F172A)),
            label: 'Pesanan',
          ),
        ],
      ),
    );
  }
}