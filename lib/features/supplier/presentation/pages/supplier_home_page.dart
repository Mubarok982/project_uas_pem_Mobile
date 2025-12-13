import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class SupplierHomePage extends StatelessWidget {
  const SupplierHomePage({super.key});

  // Ambil data User & Statistik Sederhana
  Future<Map<String, dynamic>> _getDashboardData() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;

    // 1. Ambil Profil Toko
    final profile = await supabase.from('profiles').select().eq('id', userId).single();

    // 2. Hitung Order Baru (PAID)
    final newOrders = await supabase
        .from('orders')
        .select('id')
        .eq('supplier_id', userId)
        .eq('status', 'PAID')
        .count();

    // 3. Hitung Pendapatan (COMPLETED)
    // Catatan: Di real app, gunakan RPC/Database function untuk sum. 
    // Di sini kita fetch client-side dulu untuk demo.
    final completedOrders = await supabase
        .from('orders')
        .select('total_amount')
        .eq('supplier_id', userId)
        .eq('status', 'COMPLETED');
    
    double earnings = 0;
    for (var order in completedOrders) {
      earnings += (order['total_amount'] as num).toDouble();
    }

    return {
      'shop_name': profile['shop_name'],
      'new_orders_count': newOrders.count,
      'total_earnings': earnings,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [
          // Ganti IconButton Logout yang lama dengan InkWell ke Profile
          IconButton(
            icon: const Icon(Icons.settings), // Icon Gear/Settings
            onPressed: () {
               // Pindah ke halaman Profile
               context.push('/supplier/profile');
            },
          )
        ],
      ),
      body: FutureBuilder(
        future: _getDashboardData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          // Data Default jika error/kosong
          final data = snapshot.data ?? {'shop_name': 'Toko Saya', 'new_orders_count': 0, 'total_earnings': 0.0};
          final earnings = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
              .format(data['total_earnings']);

          return RefreshIndicator(
            onRefresh: () async {
               // Trik trigger rebuild dengan setState di parent atau navigasi ulang
               // (Disini statis dulu untuk demo)
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Header Profil
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Halo, Pemilik Toko 👋", style: TextStyle(color: Colors.white70)),
                      const Gap(8),
                      Text(
                        data['shop_name'],
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Gap(24),

                // Statistik
                Row(
                  children: [
                    _buildStatCard("Pendapatan", earnings, Icons.account_balance_wallet, Colors.green),
                    const Gap(16),
                    _buildStatCard(
                      "Siap Kirim", 
                      "${data['new_orders_count']} Order", 
                      Icons.local_shipping, 
                      data['new_orders_count'] > 0 ? Colors.orange : Colors.grey
                    ),
                  ],
                ),
                const Gap(24),

                // Menu Cepat
                const Text("Aksi Cepat", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Gap(16),
                
                _buildMenuTile(
                  context,
                  title: "Tambah Produk Baru",
                  subtitle: "Upload foto & deskripsi barang",
                  icon: Icons.add_photo_alternate,
                  color: Colors.blue,
                  onTap: () => context.push('/supplier/add-product'),
                ),
                const Gap(12),
                _buildMenuTile(
                  context,
                  title: "Lihat Semua Produk",
                  subtitle: "Cek stok dan edit harga",
                  icon: Icons.inventory_2,
                  color: Colors.purple,
                  onTap: () {
                    // Navigasi manual ke Tab Produk (Index 1) agak tricky di IndexedStack 
                    // Jadi biarkan user klik tab bawah saja.
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Silakan klik tab 'Produk' di bawah")));
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const Gap(12),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withOpacity(0.1))),
      tileColor: Colors.white,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }
}