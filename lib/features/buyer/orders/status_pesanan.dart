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
          isScrollable: true,
          labelColor: Colors.blue,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: "Belum Bayar"),
            Tab(text: "Diproses"), 
            Tab(text: "Dikirim"),
            Tab(text: "Selesai"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _BuyerOrderList(statusFilters: ['PENDING', 'paid', 'PAID']), // Handle variasi huruf
          _BuyerOrderList(statusFilters: ['PACKED', 'packed', 'paid_held']),
          _BuyerOrderList(statusFilters: ['SHIPPED', 'shipped', 'DELIVERED', 'delivered']),
          _BuyerOrderList(statusFilters: ['COMPLETED', 'completed', 'CANCELLED', 'cancelled', 'DISPUTED', 'disputed']),
        ],
      ),
    );
  }
}

// ✅ UBAH JADI STATEFUL AGAR STREAM STABIL (KeepAlive)
class _BuyerOrderList extends StatefulWidget {
  final List<String> statusFilters;
  const _BuyerOrderList({required this.statusFilters});

  @override
  State<_BuyerOrderList> createState() => _BuyerOrderListState();
}

class _BuyerOrderListState extends State<_BuyerOrderList> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Tab tidak reload saat digeser

  late final Stream<List<Map<String, dynamic>>> _ordersStream;

  @override
  void initState() {
    super.initState();
    final myId = Supabase.instance.client.auth.currentUser!.id;
    
    // Setup Stream Realtime
    _ordersStream = Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('buyer_id', myId) // Pastikan ini 'buyer_id'
        .order('created_at', ascending: false)
        .map((data) => data.where((order) => widget.statusFilters.contains(order['status'])).toList());
  }

  Future<void> _confirmReceived(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Terima Barang?"),
        content: const Text("Pastikan barang sudah diterima. Dana akan diteruskan ke Penjual."),
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
      // Ambil data dulu baru pindah ke Verifikasi AI
      try {
        final orderData = await Supabase.instance.client
            .from('orders')
            .select()
            .eq('id', orderId)
            .single();
            
        if (mounted) {
          context.push('/buyer/verify-ai', extra: orderData);
        }
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return StreamBuilder(
      stream: _ordersStream,
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
                Text("Tidak ada pesanan", style: TextStyle(color: Colors.grey[600])),
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
            final status = (order['status'] as String).toUpperCase();
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Order #${order['id'].toString().substring(0, 8)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        _StatusBadge(status: status),
                      ],
                    ),
                    const Divider(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total Belanja:"),
                        Text(total, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    
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

                    // TOMBOL TERIMA (Hanya di tab Dikirim)
                    if (status == 'SHIPPED' || status == 'DELIVERED')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _confirmReceived(order['id']),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text("Barang Diterima & Verifikasi", style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      
                    if (status == 'COMPLETED')
                       const Center(child: Text("Transaksi Selesai ✅", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
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
    else if (s == 'DISPUTED') { color = Colors.red; text = "KOMPLAIN"; }
    else { color = Colors.black; text = s; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }
}