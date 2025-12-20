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
          labelColor: const Color(0xFF0F172A), // Sesuaikan dengan tema kamu
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
   // Cari bagian body: TabBarView
body: TabBarView(
  controller: _tabController,
  children: const [
    // Tab 1: Perlu Proses
    _OrderList(statusFilters: ['PAID', 'paid', 'PACKED', 'packed', 'paid_held']),
    
    // ✅ FIX 1: Tambahkan 'DELIVERED' dan 'delivered' di sini
    _OrderList(statusFilters: [
      'SHIPPED', 'shipped', 
      'DELIVERED', 'delivered', // <--- INI YANG KURANG TADI
      'COMPLETED', 'completed'
    ]),
    
    // Tab 3: Komplain/Batal
    _OrderList(statusFilters: ['DISPUTED', 'disputed', 'CANCELLED', 'cancelled']),
  ],
),
    );
  }
}

class _OrderList extends StatefulWidget {
  final List<String> statusFilters;
  const _OrderList({required this.statusFilters});

  @override
  State<_OrderList> createState() => _OrderListState();
}

class _OrderListState extends State<_OrderList> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final Stream<List<Map<String, dynamic>>> _ordersStream;
  final TextEditingController _searchController = TextEditingController(); // 1. Controller Search
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    final myId = Supabase.instance.client.auth.currentUser!.id;
    
    // Query tetap sama
    _ordersStream = Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('supplier_id', myId)
        .order('created_at', ascending: false)
        .map((data) => data.where((order) => widget.statusFilters.contains(order['status'])).toList());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Column( // 2. Ubah jadi Column biar ada Search Bar di atas
      children: [
        // --- SEARCH BAR MULAI ---
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Cari ID Order...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase(); // 3. Update query saat ngetik
              });
            },
          ),
        ),
        // --- SEARCH BAR SELESAI ---

        Expanded(
          child: StreamBuilder(
            stream: _ordersStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text("Tidak ada pesanan", style: TextStyle(color: Colors.grey[600])));
              }

              final allOrders = snapshot.data!;
              
              // 4. LOGIC FILTERING (Saring data sebelum ditampilkan)
              final filteredOrders = allOrders.where((order) {
                final id = order['id'].toString().toLowerCase();
                // Kalau mau cari nama pembeli agak tricky karena harus join table profiles dulu.
                // Untuk sekarang cari berdasarkan ID Order dulu yg paling gampang.
                return id.contains(_searchQuery); 
              }).toList();

              if (filteredOrders.isEmpty) {
                return const Center(child: Text("Pesanan tidak ditemukan"));
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filteredOrders.length, // Pakai list yg sudah difilter
                separatorBuilder: (_, __) => const Gap(16),
                itemBuilder: (context, index) {
                  return _OrderCard(order: filteredOrders[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ✅ WIDGET CARD: Logic Detail sudah disesuaikan dengan 'full_name'
class _OrderCard extends StatefulWidget {
  final Map<String, dynamic> order;
  const _OrderCard({required this.order});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _isLoadingDetails = true;
  String _buyerName = "Memuat...";
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _fetchAdditionalDetails();
  }

  Future<void> _fetchAdditionalDetails() async {
    final supabase = Supabase.instance.client;
    try {
      // 1. Ambil Nama Pembeli (✅ FIX: Pakai full_name)
      final buyerId = widget.order['buyer_id'];
      if (buyerId != null) {
        final buyerData = await supabase
            .from('profiles')
            .select('full_name') // Kita ambil kolom yang baru dibuat
            .eq('id', buyerId)
            .maybeSingle();
            
        if (buyerData != null) {
          setState(() {
            _buyerName = buyerData['full_name'] ?? "Tanpa Nama";
          });
        } else {
          setState(() => _buyerName = "User Tidak Dikenal");
        }
      }

      // 2. Ambil Item Produk
      final itemsData = await supabase
          .from('order_items')
          .select('quantity, products(name)')
          .eq('order_id', widget.order['id']);
      
      setState(() {
        _items = List<Map<String, dynamic>>.from(itemsData);
        _isLoadingDetails = false;
      });

    } catch (e) {
      debugPrint("Gagal ambil detail: $e");
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  // LOGIC UPDATE STATUS (Aman untuk Web)
  Future<void> _updateStatus(String newStatus, {bool isCancelling = false}) async {
    final supabase = Supabase.instance.client;
    final orderId = widget.order['id'];

    try {
      if (isCancelling) await _returnStock(orderId);

      await supabase.from('orders').update({'status': newStatus}).eq('id', orderId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Status diperbarui!")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    }
  }

  // LOGIC RETURN STOCK (Aman untuk Web)
  Future<void> _returnStock(String orderId) async {
    final supabase = Supabase.instance.client;
    final items = await supabase.from('order_items').select().eq('order_id', orderId);
    for (var item in items) {
      final productId = item['product_id'];
      final qty = (item['quantity'] as num).toInt(); 
      final product = await supabase.from('products').select('stock').eq('id', productId).single();
      final currentStock = (product['stock'] as num).toInt();
      await supabase.from('products').update({'stock': currentStock + qty}).eq('id', productId);
    }
  }

  void _showInputResiDialog(String? currentResi) {
    final resiController = TextEditingController(text: currentResi);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Input Nomor Resi"),
        content: TextField(
          controller: resiController,
          decoration: const InputDecoration(hintText: "Contoh: JNE-88219192"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (resiController.text.isNotEmpty) {
                 await Supabase.instance.client.from('orders').update({
                   'status': 'SHIPPED',
                   'tracking_number': resiController.text.trim()
                 }).eq('id', widget.order['id']);
                 
                 if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Resi tersimpan!")));
              }
            },
            child: const Text("Kirim"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final status = (order['status'] as String).toUpperCase();
    final total = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(order['total_amount']);
    final address = order['shipping_address'] ?? 'Alamat tidak tersedia';
    final resi = order['tracking_number'];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: ID & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Order #${order['id'].toString().substring(0, 8)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                _StatusBadge(status: status),
              ],
            ),
            const Divider(height: 24),

            // Info Pembeli
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.blueGrey),
                const Gap(8),
                Text(_buyerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const Gap(4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.blueGrey),
                const Gap(8),
                Expanded(child: Text(address, style: const TextStyle(fontSize: 13, color: Colors.black87))),
              ],
            ),
            
            const Gap(12),
            
            // List Barang
            Container(
              padding: const EdgeInsets.all(8), 
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Daftar Barang:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const Gap(4),
                  if (_isLoadingDetails)
                    const Text("Memuat detail barang...", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic))
                  else if (_items.isEmpty)
                     const Text("Data barang kosong", style: TextStyle(fontSize: 12, color: Colors.red))
                  else
                    ..._items.map((item) {
                      final productName = item['products']?['name'] ?? 'Produk dihapus';
                      final qty = item['quantity'];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.circle, size: 6, color: Colors.black54),
                            const Gap(8),
                            Expanded(child: Text("$productName", style: const TextStyle(fontSize: 14))),
                            Text("x$qty", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            
            const Gap(16),
            
            // Total Harga
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total Pendapatan", style: TextStyle(color: Colors.grey)),
                Text(total, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
              ],
            ),
            
            // Resi (Jika Ada)
            if (resi != null && status != 'COMPLETED') 
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
                child: Text("Resi: $resi", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
              ),

            const Gap(16),
            
            // Tombol Aksi
            if (status == 'PAID' || status == 'PAID_HELD')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateStatus('CANCELLED', isCancelling: true),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                      child: const Text("Tolak"),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateStatus('PACKED'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                      child: const Text("Proses"),
                    ),
                  ),
                ],
              ),
            
            if (status == 'PACKED')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showInputResiDialog(null),
                  icon: const Icon(Icons.local_shipping),
                  label: const Text("Input Resi & Kirim"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                ),
              ),

             if (status == 'SHIPPED')
               SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showInputResiDialog(resi),
                  icon: const Icon(Icons.edit),
                  label: const Text("Edit Resi"),
                ),
              ),
              
             if (status == 'DISPUTED')
               SizedBox(
                 width: double.infinity,
                 child: ElevatedButton.icon(
                   onPressed: () => context.push('/supplier/dispute-detail', extra: widget.order['id']),
                   icon: const Icon(Icons.gavel),
                   label: const Text("Lihat Komplain"),
                   style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                 ),
               ),
          ],
        ),
      ),
    );
  }
}

// Cari class _StatusBadge
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    final s = status.toUpperCase();

    if (s == 'PAID' || s == 'PAID_HELD') { color = Colors.orange; text = "PERLU PROSES"; }
    else if (s == 'PACKED') { color = Colors.blue; text = "DIKEMAS"; }
    else if (s == 'SHIPPED') { color = Colors.indigo; text = "DIKIRIM"; }
    
    // ✅ FIX 2: Tambahkan logika tampilan untuk DELIVERED
    else if (s == 'DELIVERED') { 
      color = Colors.teal; 
      text = "SAMPAI (MENUNGGU VERIFIKASI)"; 
    }
    
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