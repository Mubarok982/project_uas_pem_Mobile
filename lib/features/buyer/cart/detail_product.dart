import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

class BuyerProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const BuyerProductDetailPage({super.key, required this.product});

  @override
  State<BuyerProductDetailPage> createState() => _BuyerProductDetailPageState();
}

class _BuyerProductDetailPageState extends State<BuyerProductDetailPage> {
  int _quantity = 1;
  bool _isLoading = false;

  // Fungsi Tambah/Kurang Jumlah
  void _updateQuantity(int delta) {
    setState(() {
      int newQty = _quantity + delta;
      // Minimal beli 1, Maksimal sebanyak stok
      if (newQty > 0 && newQty <= (widget.product['stock'] as int)) {
        _quantity = newQty;
      }
    });
  }

  // LOGIC UTAMA: Masuk Keranjang
  Future<void> _addToCart() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;
    final productId = widget.product['id'];

    try {
      // 1. Cek dulu: Apakah barang ini sudah ada di keranjang user?
      final existingCartItem = await supabase
          .from('cart_items')
          .select()
          .eq('user_id', userId)
          .eq('product_id', productId)
          .maybeSingle(); 

      if (existingCartItem != null) {
        // SKENARIO A: Sudah ada -> Update Jumlahnya
        final oldQty = existingCartItem['quantity'] as int;
        final newQty = oldQty + _quantity;
        
        // Cek stok lagi biar gak over
        if (newQty > widget.product['stock']) {
          throw "Stok tidak cukup untuk menambah lagi.";
        }

        await supabase
            .from('cart_items')
            .update({'quantity': newQty, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', existingCartItem['id']);
            
      } else {
        // SKENARIO B: Belum ada -> Insert Baru
        await supabase.from('cart_items').insert({
          'user_id': userId,
          'product_id': productId,
          'quantity': _quantity,
        });
      }

      // ✅ NOTIFIKASI DIHAPUS, LANGSUNG KEMBALI
      if (mounted) {
        context.pop(); // Kembali ke halaman sebelumnya
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final price = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
        .format(product['price']);

    return Scaffold(
      appBar: AppBar(title: const Text("Detail Produk")),
      body: Column(
        children: [
          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gambar Besar
                  Container(
                    height: 300,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: Image.network(
                      product['image_url'] ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (_,__,___) => const Icon(Icons.broken_image, size: 100, color: Colors.grey),
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Harga & Judul
                        Text(price, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const Gap(8),
                        Text(product['name'], style: const TextStyle(fontSize: 20)),
                        const Gap(16),
                        
                        // Info Stok
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                          child: Text("Stok Tersedia: ${product['stock']}", style: TextStyle(color: Colors.grey[700])),
                        ),
                        const Gap(24),

                        // Deskripsi
                        const Text("Deskripsi Produk", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Gap(8),
                        Text(
                          product['description'] ?? "Tidak ada deskripsi.",
                          style: const TextStyle(color: Colors.black87, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Bar (Sticky)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
            ),
            child: Row(
              children: [
                // Selector Jumlah
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      IconButton(onPressed: () => _updateQuantity(-1), icon: const Icon(Icons.remove, size: 18)),
                      Text("$_quantity", style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(onPressed: () => _updateQuantity(1), icon: const Icon(Icons.add, size: 18)),
                    ],
                  ),
                ),
                const Gap(16),
                
                // Tombol Add to Cart
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _addToCart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                        : const Text("+ Keranjang", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}