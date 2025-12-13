import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SupplierOrderPage extends StatefulWidget {
  const SupplierOrderPage({super.key});

  @override
  State<SupplierOrderPage> createState() => _SupplierOrderPageState();
}

class _SupplierOrderPageState extends State<SupplierOrderPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Kita pakai 3 Tab: Perlu Dikirim, Dalam Proses, Komplain (PENTING)
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pesanan Masuk"),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0F172A),
          indicatorColor: const Color(0xFF0F172A),
          tabs: const [
            Tab(text: "Perlu Dikirim"),
            Tab(text: "Dalam Proses"),
            // Tab Khusus Masalah (Kasih Icon Warning)
            Tab(child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                SizedBox(width: 4),
                Text("Komplain", style: TextStyle(color: Colors.red)),
              ],
            )),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _OrderList(statusFilters: ['PAID', 'paid_held']), 
          _OrderList(statusFilters: ['SHIPPED', 'DELIVERED']),
          // Tab 3 Khusus DISPUTED
          _OrderList(statusFilters: ['disputed']),
        ],
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<String> statusFilters;
  const _OrderList({required this.statusFilters});

  Stream<List<Map<String, dynamic>>> _ordersStream() {
    final myId = Supabase.instance.client.auth.currentUser!.id;
    return Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('supplier_id', myId)
        .order('created_at', ascending: false)
        .map((data) => data.where((order) => statusFilters.contains(order['status'])).toList());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _ordersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("Tidak ada pesanan di status ini"));
        }

        final orders = snapshot.data!;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const Gap(16),
          itemBuilder: (context, index) {
            final order = orders[index];
            final status = order['status'];
            final total = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(order['total_amount']);

            return Card(
              // Kalau Disputed, kasih border merah biar eye-catching
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: status == 'disputed' ? const BorderSide(color: Colors.red, width: 2) : BorderSide.none
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Order #${order['id'].toString().substring(0, 8)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        _buildStatusBadge(status),
                      ],
                    ),
                    const Divider(),
                    Text("Total: $total", style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Gap(12),
                    
                    // Tombol Aksi
                    if (status == 'PAID' || status == 'paid_held')
                      ElevatedButton(
                        onPressed: () {}, // (Logika input resi ada di kode sebelumnya)
                        child: const Text("Input Resi"),
                      ),
                    
                    // JIKA DISPUTED -> Tombol LIHAT KOMPLAIN
                    if (status == 'disputed')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Buka Halaman Detail Dispute
                            context.push('/supplier/dispute-detail', extra: order['id']);
                          },
                          icon: const Icon(Icons.gavel),
                          label: const Text("Selesaikan Masalah"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    // ... (Copy logika badge warna-warni dari kode sebelumnya di sini)
    // Tambahkan case untuk DISPUTED
    if (status == 'disputed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(4)),
        child: const Text("SENGKETA", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      );
    }
    return Text(status); // Placeholder
  }
}