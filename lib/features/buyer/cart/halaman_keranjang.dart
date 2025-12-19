import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

class HalamanKeranjang extends StatefulWidget {
  const HalamanKeranjang({super.key});

  @override
  State<HalamanKeranjang> createState() => _HalamanKeranjangState();
}

class _HalamanKeranjangState extends State<HalamanKeranjang> {
  bool _isInitialLoading = true;
  List<Map<String, dynamic>> _cartItems = [];
  double _totalPrice = 0;
  
  // Listener Realtime
  StreamSubscription? _cartSubscription;

  @override
  void initState() {
    super.initState();
    _setupRealtimeCart();
  }

  @override
  void dispose() {
    _cartSubscription?.cancel();
    super.dispose();
  }

  // ✅ LOGIC REALTIME YANG CEPAT (Sama seperti Checkout)
  void _setupRealtimeCart() {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;

    _cartSubscription = supabase
        .from('cart_items')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false) // Barang baru di atas
        .listen((List<Map<String, dynamic>> rawCartItems) async {
          
          if (rawCartItems.isEmpty) {
            if (mounted) {
              setState(() {
                _cartItems = [];
                _totalPrice = 0;
                _isInitialLoading = false;
              });
            }
            return;
          }

          // Ambil semua detail produk sekaligus (Batch Fetch) biar ngebut 🚀
          final productIds = rawCartItems.map((item) => item['product_id']).toList();
          
          final products = await supabase
              .from('products')
              .select()
              .inFilter('id', productIds);

          List<Map<String, dynamic>> enrichedItems = [];
          double tempTotal = 0;

          for (var cartItem in rawCartItems) {
            // Gabungkan data keranjang dengan data produk
            final matchingProducts = products.where((p) => p['id'] == cartItem['product_id']);
            final product = matchingProducts.isNotEmpty ? matchingProducts.first : null;

            if (product != null) {
              final qty = cartItem['quantity'] as int;
              final price = product['price'] as int;
              tempTotal += (qty * price);

              final newItem = Map<String, dynamic>.from(cartItem);
              newItem['products'] = product; // Masukkan object produk
              enrichedItems.add(newItem);
            }
          }

          if (mounted) {
            setState(() {
              _cartItems = enrichedItems;
              _totalPrice = tempTotal;
              _isInitialLoading = false;
            });
          }
        }, onError: (e) {
          if (mounted) setState(() => _isInitialLoading = false);
          debugPrint("Error Stream Keranjang: $e");
        });
  }

  // Logic Hapus Item
  Future<void> _deleteItem(String cartId) async {
    await Supabase.instance.client.from('cart_items').delete().eq('id', cartId);
    // Tidak perlu setState, Stream akan otomatis update UI
  }

  // Logic Update Jumlah (+ / -)
  Future<void> _updateQty(String cartId, int currentQty, int delta, int maxStock) async {
    final newQty = currentQty + delta;
    if (newQty > 0 && newQty <= maxStock) {
      // Optimistic UI (opsional): Bisa setState dulu biar terasa instan, tapi Stream usually fast enough
      await Supabase.instance.client
          .from('cart_items')
          .update({'quantity': newQty})
          .eq('id', cartId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text("Keranjang Belanja")),
      body: _isInitialLoading 
          ? const Center(child: CircularProgressIndicator())
          : _cartItems.isEmpty
              ? const Center(child: Text("Keranjang masih kosong"))
              : Column(
                  children: [
                    // LIST ITEM
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _cartItems.length,
                        separatorBuilder: (_,__) => const Gap(12),
                        itemBuilder: (context, index) {
                          final item = _cartItems[index];
                          final product = item['products'];
                          final qty = item['quantity'] as int;
                          final maxStock = product['stock'] as int;

                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Gambar Kecil
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      product['image_url'] ?? '',
                                      width: 70, height: 70, fit: BoxFit.cover,
                                      errorBuilder: (_,__,___) => Container(width: 70, height: 70, color: Colors.grey[200], child: const Icon(Icons.broken_image)),
                                    ),
                                  ),
                                  const Gap(16),
                                  
                                  // Info Produk
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(product['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text(currency.format(product['price']), style: const TextStyle(color: Colors.grey)),
                                      ],
                                    ),
                                  ),

                                  // Kontrol Qty & Delete
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                        onPressed: () => _deleteItem(item['id']),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const Gap(8),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey[300]!)
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _QtyBtn(icon: Icons.remove, onTap: () => _updateQty(item['id'], qty, -1, maxStock)),
                                            Text("$qty", style: const TextStyle(fontWeight: FontWeight.bold)),
                                            _QtyBtn(icon: Icons.add, onTap: () => _updateQty(item['id'], qty, 1, maxStock)),
                                          ],
                                        ),
                                      )
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // BOTTOM BAR (Total & Checkout)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Total Belanja", style: TextStyle(color: Colors.grey)),
                                Text(currency.format(_totalPrice), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => context.push('/buyer/checkout'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text("Checkout"),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
    );
  }
}

// Widget Kecil untuk Tombol + -
class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, size: 16, color: Colors.black87),
      ),
    );
  }
}