import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';

class BuyerOrderPage extends StatefulWidget {
  const BuyerOrderPage({super.key});

  @override
  State<BuyerOrderPage> createState() => _BuyerOrderPageState();
}

class _BuyerOrderPageState extends State<BuyerOrderPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text("Transaksi Saya"),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0F172A),
          indicatorColor: const Color(0xFF0F172A),
          tabs: const [
            Tab(text: "Berjalan"), // Paid, Shipped, Delivered
            Tab(text: "Selesai"),  // Completed, Cancelled, Disputed
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _OrderList(isActive: true),
          _OrderList(isActive: false),
        ],
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final bool isActive;
  const _OrderList({required this.isActive});

  Stream<List<Map<String, dynamic>>> _ordersStream() {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    
    final List<String> statuses = isActive 
        ? ['paid', 'packed', 'shipped', 'delivered'] 
        : ['completed', 'cancelled', 'disputed', 'resolved_refund', 'resolved_appeal'];

    return Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('buyer_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.where((order) => statuses.contains(order['status'])).toList());
  }

  // Helper untuk Warna Status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid': return Colors.orange;
      case 'shipped': return Colors.blue;
      case 'delivered': return Colors.purple;
      case 'completed': return Colors.green;
      case 'disputed': return Colors.red;
      case 'cancelled': return Colors.grey;
      default: return Colors.black;
    }
  }

  // Helper untuk Teks Status
  String _getStatusText(String status) {
    switch (status) {
      case 'paid': return "Diproses Penjual";
      case 'shipped': return "Sedang Dikirim";
      case 'delivered': return "Barang Sampai - Butuh Verifikasi"; // INI PENTING NANTI
      case 'completed': return "Selesai";
      case 'disputed': return "Dalam Komplain";
      case 'cancelled': return "Dibatalkan";
      default: return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _ordersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text(isActive ? "Tidak ada pesanan aktif" : "Belum ada riwayat selesai"));
        }

        final orders = snapshot.data!;
        final currency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const Gap(16),
          itemBuilder: (context, index) {
            final order = orders[index];
            final status = order['status'] ?? 'unknown';
            final total = currency.format(order['total_amount']);
            final date = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(order['created_at']).toLocal());

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Tanggal & Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getStatusText(status),
                            style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    
                    // Body: Total Belanja
                    Row(
                      children: [
                        const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
                        const Gap(12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Total Belanja", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(total, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                    
                    // Footer: Tombol Aksi (Nanti di sini kita pasang tombol AI)
                    if (status == 'delivered') ...[
                      const Gap(16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            context.push('/buyer/verify-ai', extra: order);
                          },
                          icon: const Icon(Icons.camera_alt),
                          label: const Text("VERIFIKASI BARANG (AI)"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A), 
                            foregroundColor: Colors.white
                          ),
                        ),
                      )
                    ] else if (status == 'shipped') ...[
                       const Gap(16),
                       const SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: null, // Disable
                          child: Text("Menunggu Kurir..."),
                        ),
                      )
                    ]
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}