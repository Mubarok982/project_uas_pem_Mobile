import 'package:flutter/material.dart';
// Nanti kita import halaman-halamannya di sini
import 'package:veriaga/features/buyer/home/buyer_home_page.dart';
import 'package:veriaga/features/buyer/cart/halaman_keranjang.dart';
import 'package:veriaga/features/buyer/orders/status_pesanan.dart';
import 'package:veriaga/features/buyer/profile/profil_buyer.dart';

class BuyerMainPage extends StatefulWidget {
  const BuyerMainPage({super.key});

  @override
  State<BuyerMainPage> createState() => _BuyerMainPageState();
}

class _BuyerMainPageState extends State<BuyerMainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const BuyerHomePage(), 
    const BuyerCartPage(), 
    const BuyerOrderPage(), 
    const BuyerProfilePage(),           
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        indicatorColor: Colors.blue.withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Colors.blue),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart, color: Colors.blue),
            label: 'Keranjang',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: Colors.blue),
            label: 'Transaksi',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Colors.blue),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}