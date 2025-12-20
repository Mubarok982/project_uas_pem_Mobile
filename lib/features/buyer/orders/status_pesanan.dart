import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ WAJIB: Untuk fitur Copy Clipboard
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
          labelColor: const Color(0xFF0F172A),
          indicatorColor: const Color(0xFF0F172A),
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
          _BuyerOrderList(statusFilters: ['PENDING', 'paid', 'PAID']), 
          _BuyerOrderList(statusFilters: ['PACKED', 'packed', 'paid_held']),
          _BuyerOrderList(statusFilters: ['SHIPPED', 'shipped', 'DELIVERED', 'delivered']),
          _BuyerOrderList(statusFilters: ['COMPLETED', 'completed', 'CANCELLED', 'cancelled', 'DISPUTED', 'disputed']),
        ],
      ),
    );
  }
}

class _BuyerOrderList extends StatefulWidget {
  final List<String> statusFilters;
  const _BuyerOrderList({required this.statusFilters});

  @override
  State<_BuyerOrderList> createState() => _BuyerOrderListState();
}

class _BuyerOrderListState extends State<_BuyerOrderList> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; 

  late final Stream<List<Map<String, dynamic>>> _ordersStream;

  @override
  void initState() {
    super.initState();
    final myId = Supabase.instance.client.auth.currentUser!.id;
    
    _ordersStream = Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('buyer_id', myId) 
        .order('created_at', ascending: false)
        .map((data) => data.where((order) => widget.statusFilters.contains(order['status'])).toList());
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
            return _BuyerOrderCard(order: orders[index]);
          },
        );
      },
    );
  }
}

class _BuyerOrderCard extends StatefulWidget {
  final Map<String, dynamic> order;
  const _BuyerOrderCard({required this.order});

  @override
  State<_BuyerOrderCard> createState() => _BuyerOrderCardState();
}

class _BuyerOrderCardState extends State<_BuyerOrderCard> {
  bool _isLoadingDetails = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    final supabase = Supabase.instance.client;
    try {
      final itemsData = await supabase
          .from('order_items')
          .select('quantity, price_at_purchase, products(name, image_url)')
          .eq('order_id', widget.order['id']);
      
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(itemsData);
          _isLoadingDetails = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  // ✅ FITUR BARU 1: Copy ID Pesanan
  void _copyOrderId() {
    Clipboard.setData(ClipboardData(text: widget.order['id']));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("ID Pesanan disalin! Tempel di chat."))
    );
  }

  // ✅ FITUR BARU 2: Buka Halaman Chat
  void _openChat() {
    final orderIdShort = widget.order['id'].toString().substring(0, 8);
    final initialMsg = "Halo kak, saya mau tanya soal pesanan #$orderIdShort ini.";
    
    context.push('/chat', extra: {
      'partnerId': widget.order['supplier_id'], 
      'partnerName': "Penjual", 
      'initialMessage': initialMsg,
    });
  }

  Future<void> _confirmReceived() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Barang Sudah Sampai?"),
        content: const Text("Jika Anda klik Ya, status akan berubah menjadi 'Sampai' dan Anda WAJIB melakukan verifikasi AI untuk menyelesaikan pesanan."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Ya, Barang Sampai"),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      showDialog(
        context: context, 
        barrierDismissible: false, 
        builder: (_) => const Center(child: CircularProgressIndicator())
      );

      try {
        await Supabase.instance.client
            .from('orders')
            .update({'status': 'DELIVERED'}) 
            .eq('id', widget.order['id']);

        if (mounted) {
          Navigator.pop(context); // Tutup Loading
          
          final extraData = {
            'order': widget.order,
            'items': _items,
          };
          context.push('/buyer/verify-ai', extra: extraData);
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); 
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Gagal update status: $e"), backgroundColor: Colors.red)
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
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
            // ✅ HEADER: ID Pesanan + Tombol Copy + Badge Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text("Order #${order['id'].toString().substring(0, 8)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Gap(8),
                      // Ikon Copy
                      InkWell(
                        onTap: _copyOrderId,
                        child: const Icon(Icons.copy, size: 16, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            const Divider(height: 24),

            // LIST BARANG
            if (_isLoadingDetails)
              const Padding(padding: EdgeInsets.all(8.0), child: Text("Memuat rincian barang..."))
            else if (_items.isEmpty)
              const Text("Data barang tidak ditemukan", style: TextStyle(color: Colors.red))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                separatorBuilder: (_,__) => const Gap(8),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final product = item['products'];
                  final qty = item['quantity'];
                  final price = item['price_at_purchase'] ?? 0;
                  final fmtPrice = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(price);

                  return Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                        child: product['image_url'] != null 
                            ? Image.network(product['image_url'], fit: BoxFit.cover, errorBuilder: (_,__,___)=>const Icon(Icons.image))
                            : const Icon(Icons.image, size: 20, color: Colors.grey),
                      ),
                      const Gap(10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product['name'] ?? "Produk", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text("$qty x $fmtPrice", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping, size: 18, color: Colors.blue),
                    const Gap(8),
                    Expanded(child: Text("Resi: $resi", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),

            const Gap(16),

            // ✅ UPDATE TOMBOL AKSI: Chat & Terima Barang
            Row(
              children: [
                // Tombol Chat (Selalu muncul)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openChat,
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: const Text("Chat"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFF0F172A)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                
                // Tombol Terima Barang (Hanya jika SHIPPED / DELIVERED)
                if (status == 'SHIPPED' || status == 'DELIVERED') ...[
                  const Gap(8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirmReceived, 
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, 
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text("Terima"),
                    ),
                  ),
                ],
              ],
            ),
              
            if (status == 'COMPLETED')
               const Padding(
                 padding: EdgeInsets.only(top: 12),
                 child: Center(child: Text("Transaksi Selesai ✅", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
               ),
            if (status == 'DISPUTED')
               const Padding(
                 padding: EdgeInsets.only(top: 12),
                 child: Center(child: Text("Dalam Komplain ⚠️", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
               ),
          ],
        ),
      ),
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
    else if (s == 'DELIVERED') { color = Colors.purple; text = "SAMPAI - BUTUH VERIFIKASI"; }
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