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
        title: const Text("Kelola Pesanan"),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0F172A),
          indicatorColor: const Color(0xFF0F172A),
          tabs: const [
            Tab(text: "Perlu Proses"),
            Tab(text: "Dikirim / Selesai"),
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
          _OrderList(statusFilters: ['PAID', 'paid', 'PACKED', 'packed', 'paid_held']),
          _OrderList(statusFilters: ['SHIPPED', 'shipped', 'DELIVERED', 'delivered', 'COMPLETED', 'completed']),
          _OrderList(statusFilters: ['DISPUTED', 'disputed', 'CANCELLED', 'cancelled']),
        ],
      ),
    );
  }
}

// ✅ UBAH JADI STATEFUL WIDGET (Supaya Stream Stabil)
class _OrderList extends StatefulWidget {
  final List<String> statusFilters;
  const _OrderList({required this.statusFilters});

  @override
  State<_OrderList> createState() => _OrderListState();
}

class _OrderListState extends State<_OrderList> with AutomaticKeepAliveClientMixin {
  // ✅ Fitur KeepAlive: Tab tidak akan reload/putus saat digeser
  @override
  bool get wantKeepAlive => true;

  late final Stream<List<Map<String, dynamic>>> _ordersStream;

  @override
  void initState() {
    super.initState();
    // ✅ Inisialisasi Stream SEKALI SAJA di sini (Anti-Lag)
    final myId = Supabase.instance.client.auth.currentUser!.id;
    
    _ordersStream = Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('supplier_id', myId)
        .order('created_at', ascending: false)
        .map((data) => data.where((order) => widget.statusFilters.contains(order['status'])).toList());
  }

  // Logic: Update Status
  Future<void> _updateStatus(String orderId, String newStatus) async {
    try {
      await Supabase.instance.client
          .from('orders')
          .update({'status': newStatus})
          .eq('id', orderId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Status diperbarui!")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    }
  }

  // Logic: Input Resi
  void _showInputResiDialog(String orderId) {
    final resiController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Masukkan Nomor Resi"),
        content: TextField(
          controller: resiController,
          decoration: const InputDecoration(hintText: "Contoh: JNE12345678"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              if (resiController.text.isNotEmpty) {
                Navigator.pop(ctx);
                try {
                  await Supabase.instance.client
                      .from('orders')
                      .update({
                        'status': 'SHIPPED',
                        'tracking_number': resiController.text.trim()
                      })
                      .eq('id', orderId);
                } catch (e) {
                  // Error handled by stream
                }
              }
            },
            child: const Text("Kirim Barang"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Wajib panggil ini untuk KeepAlive
    
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
                const Icon(Icons.inbox, size: 50, color: Colors.grey),
                const Gap(8),
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
            final resi = order['tracking_number'] ?? '-';

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: status == 'DISPUTED' ? const BorderSide(color: Colors.red, width: 2) : BorderSide.none
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
                        _StatusBadge(status: status),
                      ],
                    ),
                    const Divider(),
                    Text("Total: $total", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    
                    if (['SHIPPED', 'DELIVERED', 'COMPLETED'].contains(status))
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text("Resi: $resi", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                      ),

                    const Gap(16),
                    
                    if (status == 'PAID' || status == 'PAID_HELD')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _updateStatus(order['id'], 'PACKED'), 
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                          child: const Text("Terima & Kemas", style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    
                    if (status == 'PACKED')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showInputResiDialog(order['id']),
                          icon: const Icon(Icons.local_shipping, color: Colors.white),
                          label: const Text("Input Resi & Kirim", style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        ),
                      ),

                    if (status == 'DISPUTED')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => context.push('/supplier/dispute-detail', extra: order['id']),
                          icon: const Icon(Icons.gavel),
                          label: const Text("Lihat Komplain"),
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
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    final s = status.toUpperCase();

    if (s == 'PAID' || s == 'PAID_HELD') { color = Colors.orange; text = "PERLU PROSES"; }
    else if (s == 'PACKED') { color = Colors.blue; text = "SIAP KIRIM"; }
    else if (s == 'SHIPPED') { color = Colors.indigo; text = "DIKIRIM"; }
    else if (s == 'DELIVERED') { color = Colors.green; text = "SAMPAI"; }
    else if (s == 'COMPLETED') { color = Colors.green; text = "SELESAI"; }
    else if (s == 'DISPUTED') { color = Colors.red; text = "KOMPLAIN"; }
    else if (s == 'CANCELLED') { color = Colors.grey; text = "DIBATALKAN"; }
    else { color = Colors.grey; text = s; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }
}