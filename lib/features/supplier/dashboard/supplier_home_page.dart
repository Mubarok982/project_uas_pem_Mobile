import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class SupplierHomePage extends StatelessWidget {
  const SupplierHomePage({super.key});

  // ✅ STREAM REALTIME (Mendengarkan perubahan data terus-menerus)
  Stream<List<Map<String, dynamic>>> _dashboardStream() {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    return Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('supplier_id', userId); // ✅ SUDAH DISESUAIKAN: supplier_id
  }

  // Ambil Nama Toko (Cukup sekali load di awal)
  Future<String> _getShopName() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final data = await Supabase.instance.client
        .from('profiles')
        .select('shop_name')
        .eq('id', userId)
        .single();
    return data['shop_name'] ?? 'Toko Saya';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Realtime"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/supplier/profile'),
          )
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _dashboardStream(),
        builder: (context, snapshot) {
          // --- DEBUGGING ---
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}")); 
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allOrders = snapshot.data ?? [];

          // HITUNG DATA (Realtime)
          // 1. Order Baru (Status PAID)
          final newOrdersCount = allOrders.where((o) => o['status'] == 'PAID' || o['status'] == 'paid').length;

          // 2. Pendapatan (Status COMPLETED)
          final completedOrders = allOrders.where((o) => o['status'] == 'COMPLETED' || o['status'] == 'completed');
          double totalEarnings = 0;
          for (var order in completedOrders) {
            totalEarnings += (order['total_amount'] as num).toDouble();
          }

          final earningsFormatted = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
              .format(totalEarnings);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Header Profil
              FutureBuilder<String>(
                future: _getShopName(),
                builder: (context, shopSnapshot) {
                  return Container(
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
                          shopSnapshot.data ?? "Memuat...",
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }
              ),
              const Gap(24),

              // Statistik Realtime
              Row(
                children: [
                  _buildStatCard("Pendapatan", earningsFormatted, Icons.account_balance_wallet, Colors.green),
                  const Gap(16),
                  _buildStatCard(
                    "Siap Kirim", 
                    "$newOrdersCount Order", 
                    Icons.local_shipping, 
                    newOrdersCount > 0 ? Colors.orange : Colors.grey
                  ),
                ],
              ),
              const Gap(24),

              // Menu Navigasi
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
                title: "Lihat Semua Pesanan",
                subtitle: "Proses pesanan masuk",
                icon: Icons.receipt_long,
                color: Colors.purple,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Klik menu 'Pesanan' di bawah")));
                },
              ),
            ],
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