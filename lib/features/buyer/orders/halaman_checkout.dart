import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

class BuyerCheckoutPage extends StatefulWidget {
  const BuyerCheckoutPage({super.key});

  @override
  State<BuyerCheckoutPage> createState() => _BuyerCheckoutPageState();
}

class _BuyerCheckoutPageState extends State<BuyerCheckoutPage> {
  final _addressController = TextEditingController();
  
  bool _isLoadingPayment = false;
  bool _isInitialLoading = true;
  
  List<Map<String, dynamic>> _cartItems = [];
  double _totalProductPrice = 0;
  final double _shippingCost = 15000;

  StreamSubscription? _cartSubscription;

  @override
  void initState() {
    super.initState();
    _fetchAddress();
    _setupRealtimeCart();
  }

  @override
  void dispose() {
    _cartSubscription?.cancel();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _fetchAddress() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      
      if (profile['address'] != null) {
        _addressController.text = "${profile['address']}, ${profile['city'] ?? ''}";
      }
    } catch (e) {
      // Ignore
    }
  }

  void _setupRealtimeCart() {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;

    _cartSubscription = supabase
        .from('cart_items')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((List<Map<String, dynamic>> rawCartItems) async {
          
          if (rawCartItems.isEmpty) {
            if (mounted) {
              setState(() {
                _cartItems = [];
                _totalProductPrice = 0;
                _isInitialLoading = false;
              });
            }
            return;
          }

          final productIds = rawCartItems.map((item) => item['product_id']).toList();

          final products = await supabase
              .from('products')
              .select()
              .inFilter('id', productIds);

          List<Map<String, dynamic>> enrichedItems = [];
          double tempTotal = 0;

          for (var cartItem in rawCartItems) {
            final matchingProducts = products.where((p) => p['id'] == cartItem['product_id']);
            final product = matchingProducts.isNotEmpty ? matchingProducts.first : null;

            if (product != null) {
              final qty = cartItem['quantity'] as int;
              final price = product['price'] as int;
              tempTotal += (qty * price);

              final newItem = Map<String, dynamic>.from(cartItem);
              newItem['products'] = product;
              enrichedItems.add(newItem);
            }
          }

          if (mounted) {
            setState(() {
              _cartItems = enrichedItems;
              _totalProductPrice = tempTotal;
              _isInitialLoading = false;
            });
          }
        }, onError: (error) {
          if (mounted) setState(() => _isInitialLoading = false);
        });
  }

  Future<void> _processPayment() async {
    if (_addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Alamat pengiriman wajib diisi!")));
      return;
    }
    
    setState(() => _isLoadingPayment = true);
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;

    try {
      if (_cartItems.isEmpty) return;

      // 1. CEK STOK DULU (Validasi)
      // Jangan sampai beli barang ghoib (stok habis tapi lolos)
      for (var item in _cartItems) {
        final product = item['products'];
        final qty = item['quantity'] as int;
        final currentStock = product['stock'] as int;

        if (qty > currentStock) {
          throw Exception("Stok '${product['name']}' tidak cukup (Sisa: $currentStock)");
        }
      }
      
      final supplierId = _cartItems.first['products']['supplier_id']; 
      final totalAmount = _totalProductPrice + _shippingCost;
      
      // 2. Buat Order
      final orderRes = await supabase.from('orders').insert({
        'buyer_id': userId,
        'supplier_id': supplierId,
        'total_amount': totalAmount,
        'shipping_address': _addressController.text,
        'shipping_cost': _shippingCost,
        'status': 'paid',
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      final orderId = orderRes['id'];

      // 3. Proses Item Order & KURANGI STOK
      for (var item in _cartItems) {
        final product = item['products'];
        final qty = item['quantity'] as int;
        final currentStock = product['stock'] as int;
        
        // A. Insert ke tabel order_items
        await supabase.from('order_items').insert({
          'order_id': orderId,
          'product_id': product['id'],
          'quantity': qty,
          'price_at_purchase': product['price'],
        });

        // ✅ B. UPDATE STOK PRODUK (Kurangi Stok)
        // Ini bagian yang tadi mungkin terlewat
        final newStock = currentStock - qty;
        await supabase.from('products').update({
          'stock': newStock
        }).eq('id', product['id']);
      }

      // 4. Catat Transaksi
      await supabase.from('transactions').insert({
        'order_id': orderId,
        'amount': totalAmount,
        'status': 'paid_held',
        'payment_method': 'Virtual Account (Simulasi)',
      });

      // 5. HAPUS KERANJANG
      await supabase.from('cart_items').delete().eq('user_id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pembayaran Berhasil!")));
        context.go('/dashboard'); // Balik ke Home
      }

    } catch (e) {
      if (mounted) {
        // Rapihkan pesan error
        final message = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: $message"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingPayment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text("Pengiriman & Pembayaran")),
      body: _isInitialLoading 
          ? const Center(child: CircularProgressIndicator())
          : _cartItems.isEmpty
              ? const Center(child: Text("Keranjang kosong, yuk belanja dulu!"))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Alamat Pengiriman", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Gap(8),
                      TextField(
                        controller: _addressController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: "Jalan, Nomor Rumah, RT/RW, Kecamatan...",
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const Gap(24),

                      const Text("Ringkasan Pesanan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Gap(8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _cartItems.length,
                          separatorBuilder: (_,__) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _cartItems[index];
                            final product = item['products'];
                            return ListTile(
                              title: Text(product['name'], style: const TextStyle(fontSize: 14)),
                              subtitle: Text("${item['quantity']} x ${currency.format(product['price'])}"),
                              trailing: Text(
                                currency.format(item['quantity'] * product['price']),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
                      ),
                      const Gap(24),

                      const Text("Rincian Pembayaran", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Gap(8),
                      _buildSummaryRow("Subtotal Produk", _totalProductPrice, currency),
                      _buildSummaryRow("Biaya Pengiriman", _shippingCost, currency),
                      const Divider(thickness: 1, height: 24),
                      _buildSummaryRow("Total Tagihan", _totalProductPrice + _shippingCost, currency, isTotal: true),
                      
                      const Gap(32),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoadingPayment ? null : _processPayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoadingPayment 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("BAYAR SEKARANG", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryRow(String label, double value, NumberFormat fmt, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize: isTotal ? 16 : 14, 
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal
          )),
          Text(fmt.format(value), style: TextStyle(
            fontSize: isTotal ? 16 : 14, 
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? const Color(0xFF0F172A) : Colors.black87
          )),
        ],
      ),
    );
  }
}