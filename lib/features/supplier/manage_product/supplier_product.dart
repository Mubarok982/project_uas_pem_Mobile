import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// ✅ UBAH JADI STATEFUL WIDGET
class SupplierProductPage extends StatefulWidget {
  const SupplierProductPage({super.key});

  @override
  State<SupplierProductPage> createState() => _SupplierProductPageState();
}

class _SupplierProductPageState extends State<SupplierProductPage> {
  
  // Stream data produk
  Stream<List<Map<String, dynamic>>> _productsStream() {
    return Supabase.instance.client
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('supplier_id', Supabase.instance.client.auth.currentUser!.id)
        .order('created_at', ascending: false);
  }

  // Fungsi Toggle Status Aktif/Nonaktif
  Future<void> _toggleStatus(String productId, bool currentValue) async {
    await Supabase.instance.client
        .from('products')
        .update({'is_active': !currentValue}) 
        .eq('id', productId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Stok Barang")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // 1. Tunggu user selesai tambah produk
          await context.push('/supplier/add-product');
          
          // 2. Refresh halaman (Sekarang sudah bisa karena Stateful)
          if (mounted) {
            setState(() {}); 
          }
        },
        label: const Text("Tambah Produk"),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder(
        stream: _productsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Belum ada produk"));
          }

          final products = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final product = products[index];
              final isActive = product['is_active'] ?? true;
              final price = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(product['price']);

              return Card(
                elevation: 2,
                color: isActive ? Colors.white : Colors.grey[200],
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          product['image_url'] ?? '',
                          width: 60, height: 60, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(width: 60, height: 60, color: Colors.grey, child: const Icon(Icons.image)),
                        ),
                      ),
                      if (!isActive)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black54,
                            child: const Icon(Icons.visibility_off, color: Colors.white, size: 20),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    product['name'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: isActive ? null : TextDecoration.lineThrough,
                      color: isActive ? Colors.black : Colors.grey,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(price, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      Text("Stok: ${product['stock']}"),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: isActive,
                        activeThumbColor: const Color(0xFF0F172A),
                        onChanged: (val) => _toggleStatus(product['id'], isActive),
                      ),
                      PopupMenuButton(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            await context.push('/supplier/edit-product', extra: product);
                            if (mounted) setState(() {}); 
                          } else if (value == 'delete') {
                            _confirmDelete(context, product['id']);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text("Edit")])),
                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text("Hapus")])),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
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
}