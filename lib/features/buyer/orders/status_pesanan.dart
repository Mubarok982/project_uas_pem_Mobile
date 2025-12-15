import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

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
    // 4 Tab: Belum Bayar, Diproses, Dikirim, Selesai
    _tabController = TabController(length: 4, vsync: this);
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
        title: const Text("Pesanan Saya"),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, // Biar tab-nya bisa digeser kalau sempit
          labelColor: Colors.blue,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: "Belum Bayar"),
            Tab(text: "Diproses"), // Paid, Packed
            Tab(text: "Dikirim"),  // Shipped, Delivered
            Tab(text: "Selesai"),  // Completed, Cancelled
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _BuyerOrderList(statusFilters: ['PENDING']),
          _BuyerOrderList(statusFilters: ['PAID', 'PACKED', 'paid', 'packed', 'paid_held']),
          _BuyerOrderList(statusFilters: ['SHIPPED', 'DELIVERED', 'shipped', 'delivered']),
          _BuyerOrderList(statusFilters: ['COMPLETED', 'CANCELLED', 'DISPUTED', 'completed', 'cancelled']),
        ],
      ),
    );
  }
}

class _BuyerOrderList extends StatelessWidget {
  final List<String> statusFilters;
  const _BuyerOrderList({required this.statusFilters});

  // ✅ STREAM REALTIME KHUSUS BUYER
  Stream<List<Map<String, dynamic>>> _ordersStream() {
    final myId = Supabase.instance.client.auth.currentUser!.id;
    return Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        // Filter: Hanya pesanan milik saya (buyer_id)
        // Pastikan kolom di DB namanya 'buyer_id' atau 'user_id'
        .eq('buyer_id', myId) 
        .order('created_at', ascending: false)
        .map((data) => data.where((order) => statusFilters.contains(order['status'])).toList());
  }

  Future<void> _confirmReceived(BuildContext context, String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Terima Barang?"),
        content: const Text("Pastikan barang sudah diterima dengan baik. Dana akan diteruskan ke Penjual."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Ya, Terima"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Pindah ke Halaman Verifikasi AI (Opsional) atau langsung Selesai
        // Di sini kita arahkan ke Verifikasi AI sesuai alur aplikasimu
        
        // 1. Ambil data order dulu untuk dipassing
        final orderData = await Supabase.instance.client.from('orders').select().eq('id', orderId).single();
        
        if (context.mounted) {
          context.push('/buyer/verify-ai', extra: orderData);
        }

        // Kalo mau langsung selesai tanpa AI, pakai kode ini:
        /*
        await Supabase.instance.client.from('orders').update({'status': 'COMPLETED'}).eq('id', orderId);
        */

      } catch (e) {
        if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shopping_bag_outlined, size: 60, color: Colors.grey),
                const Gap(10),
                Text("Tidak ada pesanan di sini", style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        final orders = snapshot.data!;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const Gap(16),
          itemBuilder: (context, index) {
            final order = orders[index];
            final status = order['status'] as String;
            final total = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(order['total_amount']);
            final resi = order['tracking_number'];

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Order ID & Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Order #${order['id'].toString().substring(0, 8)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        _StatusBadge(status: status),
                      ],
                    ),
                    const Divider(height: 24),
                    
                    // Detail Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total Belanja:"),
                        Text(total, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    
                    // Tampilkan Resi jika ada
                    if (resi != null && resi.toString().isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Icon(Icons.local_shipping, size: 16, color: Colors.blue),
                            const Gap(8),
                            Expanded(child: Text("Resi: $resi", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),

                    const Gap(16),

                    // TOMBOL AKSI (Hanya muncul jika barang dikirim)
                    if (status == 'SHIPPED' || status == 'shipped' || status == 'DELIVERED' || status == 'delivered')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _confirmReceived(context, order['id']),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text("Barang Diterima & Verifikasi", style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      
                    // Tombol Komplain (Muncul jika status dikirim/selesai)
                    if (['SHIPPED', 'DELIVERED', 'COMPLETED'].contains(status))
                       Center(
                         child: TextButton(
                           onPressed: () {
                             // Fitur komplain nanti
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hubungi Admin untuk komplain")));
                           },
                           child: const Text("Ajukan Komplain", style: TextStyle(color: Colors.grey)),
                         ),
                       )
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
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    final s = status.toUpperCase();

    if (s == 'PENDING') { color = Colors.grey; text = "BELUM BAYAR"; }
    else if (s == 'PAID') { color = Colors.orange; text = "DIPROSES"; }
    else if (s == 'PACKED') { color = Colors.blue; text = "DIKEMAS"; }
    else if (s == 'SHIPPED') { color = Colors.indigo; text = "DIKIRIM"; }
    else if (s == 'DELIVERED') { color = Colors.green; text = "SAMPAI"; }
    else if (s == 'COMPLETED') { color = Colors.green; text = "SELESAI"; }
    else if (s == 'CANCELLED') { color = Colors.red; text = "DIBATALKAN"; }
    else { color = Colors.black; text = s; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }
}