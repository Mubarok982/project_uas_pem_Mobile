import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart'; // Pastikan package gap terinstall, atau ganti SizedBox

class SupplierProductPage extends StatefulWidget {
  const SupplierProductPage({super.key});

  @override
  State<SupplierProductPage> createState() => _SupplierProductPageState();
}

class _SupplierProductPageState extends State<SupplierProductPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Stream data produk
  Stream<List<Map<String, dynamic>>> _productsStream() {
    return Supabase.instance.client
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('supplier_id', Supabase.instance.client.auth.currentUser!.id)
        .order('created_at', ascending: false);
  }

  Future<void> _toggleStatus(String productId, bool currentValue) async {
    await Supabase.instance.client
        .from('products')
        .update({'is_active': !currentValue})
        .eq('id', productId);
  }

  void _confirmDelete(BuildContext context, String productId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Produk?"),
        content: const Text("Produk yang dihapus tidak bisa dikembalikan."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Supabase.instance.client.from('products').delete().eq('id', productId);
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Background abu-abu sangat muda (clean)
      appBar: AppBar(
        title: const Text("Stok Barang", style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/supplier/add-product');
          if (mounted) setState(() {});
        },
        label: const Text("Tambah"),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- 1. SEARCH BAR ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: "Cari nama produk...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // --- 2. GRID PRODUK ---
          Expanded(
            child: StreamBuilder(
              stream: _productsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState("Belum ada produk");
                }

                // Filtering Logic di Client Side (biar cepat & realtime)
                final allProducts = snapshot.data!;
                final filteredProducts = allProducts.where((product) {
                  final name = (product['name'] as String).toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();

                if (filteredProducts.isEmpty) {
                  return _buildEmptyState("Produk tidak ditemukan");
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // 2 Barang ke samping
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72, // Mengatur tinggi kartu (makin kecil makin tinggi)
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    return _buildElegantCard(filteredProducts[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET KARTU YANG ELEGAN ---
  Widget _buildElegantCard(Map<String, dynamic> product) {
    final isActive = product['is_active'] ?? true;
    final price = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(product['price']);
    final stock = product['stock'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A. Gambar Produk
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Container(
                    width: double.infinity,
                    color: Colors.grey[100],
                    child: Image.network(
                      product['image_url'] ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 40),
                      ),
                    ),
                  ),
                ),
                // Overlay jika Non-Aktif
                if (!isActive)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: const Center(
                        child: Text(
                          "NON-AKTIF",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                // Menu Option (Titik Tiga)
                Positioned(
                  top: 4,
                  right: 4,
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.8),
                    radius: 14,
                    child: PopupMenuButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert, size: 18, color: Colors.black87),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await context.push('/supplier/edit-product', extra: product);
                          if (mounted) setState(() {});
                        } else if (value == 'delete') {
                          _confirmDelete(context, product['id']);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: Colors.blue), SizedBox(width: 8), Text("Edit")])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text("Hapus")])),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // B. Informasi Produk
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isActive ? Colors.black87 : Colors.grey,
                  ),
                ),
                const Gap(4),
                Text(
                  price,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const Gap(4),
                Text(
                  "Stok: $stock",
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const Gap(8),
                
                // C. Switch Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isActive ? "Aktif" : "Mati",
                      style: TextStyle(
                        fontSize: 11, 
                        fontWeight: FontWeight.w500,
                        color: isActive ? const Color.fromARGB(255, 74, 164, 77) : Colors.grey
                      ),
                    ),
                    SizedBox(
                      height: 24,
                      child: Switch(
                        value: isActive,
                        activeColor: Colors.white,
                        activeTrackColor: Colors.lightBlue,
                        inactiveThumbColor: Colors.grey[400],
                        inactiveTrackColor: Colors.grey[200],
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (val) => _toggleStatus(product['id'], isActive),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 60, color: Colors.grey[300]),
          const Gap(16),
          Text(message, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ],
      ),
    );
  }
}