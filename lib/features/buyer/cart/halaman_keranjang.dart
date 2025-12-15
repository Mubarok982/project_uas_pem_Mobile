import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

class BuyerCartPage extends StatefulWidget {
  const BuyerCartPage({super.key});

  @override
  State<BuyerCartPage> createState() => _BuyerCartPageState();
}

class _BuyerCartPageState extends State<BuyerCartPage> {
  // Stream Keranjang dengan Relasi ke Produk
  Stream<List<Map<String, dynamic>>> _cartStream() {
    final userId = Supabase.instance.client.auth.currentUser!.id;

    return Supabase.instance.client
        .from('cart_items')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at')
        // HAPUS BAGIAN .map() YANG LAMA, LANGSUNG KE asyncMap
        .asyncMap((data) async {
          final List<Map<String, dynamic>> enrichedData = [];
          
          // Loop data keranjang
          for (var item in data) {
            // Fetch manual data produk berdasarkan product_id
            final product = await Supabase.instance.client
                .from('products')
                .select()
                .eq('id', item['product_id'])
                .single(); // Ambil 1 data produk
            
            // Gabungkan data keranjang + data produk
            final newItem = Map<String, dynamic>.from(item);
            newItem['products'] = product; 
            enrichedData.add(newItem);
          }
          
          return enrichedData;
        });
  }

  // Fungsi Update Qty
  Future<void> _updateQty(String cartId, int currentQty, int change, int maxStock) async {
    final newQty = currentQty + change;
    if (newQty < 1) return; // Minimal 1
    if (newQty > maxStock) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Stok tidak mencukupi")));
      }
      return;
    }

    await Supabase.instance.client
        .from('cart_items')
        .update({'quantity': newQty})
        .eq('id', cartId);
  }

  // Fungsi Hapus Item
  Future<void> _deleteItem(String cartId) async {
    await Supabase.instance.client.from('cart_items').delete().eq('id', cartId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Keranjang Belanja")),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _cartStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
             return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[300]),
                  const Gap(16),
                  const Text("Keranjang kamu kosong"),
                  TextButton(
                    onPressed: () {
                      // Logic pindah tab manual (opsional, bisa dikosongkan)
                    }, 
                    child: const Text("Mulai Belanja")
                  )
                ],
              ),
            );
          }

          final cartItems = snapshot.data!;
          
          // Hitung Total Harga
          double totalPrice = 0;
          for (var item in cartItems) {
            final qty = item['quantity'] as int;
            // Pastikan produk tidak null (jaga-jaga kalau produk dihapus supplier)
            if (item['products'] != null) {
               final price = item['products']['price'] as num;
               totalPrice += (qty * price);
            }
          }

          return Column(
            children: [
              // List Item
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: cartItems.length,
                  separatorBuilder: (_,__) => const Gap(12),
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    final product = item['products'];
                    
                    // Jaga-jaga jika produk dihapus supplier
                    if (product == null) return const SizedBox();

                    final qty = item['quantity'] as int;
                    final price = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
                        .format(product['price']);
                    
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Gambar Produk
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                product['image_url'] ?? '',
                                width: 70, height: 70, fit: BoxFit.cover,
                                errorBuilder: (_,__,___) => Container(width: 70, height: 70, color: Colors.grey[200]),
                              ),
                            ),
                            const Gap(12),
                            
                            // Info & Kontrol
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product['name'], style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(price, style: const TextStyle(color: Colors.green)),
                                  const Gap(8),
                                  Row(
                                    children: [
                                      // Tombol Kurang
                                      InkWell(
                                        onTap: () => _updateQty(item['id'], qty, -1, product['stock']),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
                                          child: const Icon(Icons.remove, size: 16),
                                        ),
                                      ),
                                      const Gap(12),
                                      Text("$qty", style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const Gap(12),
                                      // Tombol Tambah
                                      InkWell(
                                        onTap: () => _updateQty(item['id'], qty, 1, product['stock']),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
                                          child: const Icon(Icons.add, size: 16),
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                            
                            // Tombol Hapus (Sampah)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteItem(item['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bagian Bawah: Total & Checkout
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,-4))],
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Total Pembayaran", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Text(
                          NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(totalPrice),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        // LANJUT KE CHECKOUT
                        context.push('/buyer/checkout'); 
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text("Checkout"),
                    )
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }
}