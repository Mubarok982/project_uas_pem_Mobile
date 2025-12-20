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
  
  // Variabel untuk menyimpan saldo saat ini (untuk tampilan)
  double _currentBalance = 0;

  StreamSubscription? _cartSubscription;

  @override
  void initState() {
    super.initState();
    _fetchUserData(); // Ganti nama fungsi biar sekalian ambil saldo
    _setupRealtimeCart();
  }

  @override
  void dispose() {
    _cartSubscription?.cancel();
    _addressController.dispose();
    super.dispose();
  }

  // Ambil Alamat & Saldo User
  Future<void> _fetchUserData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('address, city, balance') // Ambil balance juga
          .eq('id', userId)
          .single();
      
      if (mounted) {
        setState(() {
          if (profile['address'] != null) {
            _addressController.text = "${profile['address']}, ${profile['city'] ?? ''}";
          }
          // Simpan saldo ke variabel state
          _currentBalance = (profile['balance'] ?? 0).toDouble();
        });
      }
    } catch (e) {
      // Ignore error fetch profile
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

  Future<bool> _checkBlockingOrders() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;

    try {
      final List blockedOrders = await supabase
          .from('orders')
          .select('id, status')
          .eq('buyer_id', userId)
          .or('status.eq.DELIVERED,status.eq.delivered'); 
      
      return blockedOrders.isNotEmpty;
    } catch (e) {
      return false; 
    }
  }

  // ✅ LOGIC UTAMA: Bayar Potong Saldo
  Future<void> _processPayment() async {
    if (_addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Alamat pengiriman wajib diisi!")));
      return;
    }
    
    setState(() => _isLoadingPayment = true);

    // 1. Cek Blokir Order
    bool isBlocked = await _checkBlockingOrders();
    if (isBlocked) {
      setState(() => _isLoadingPayment = false);
      if (mounted) _showBlockedDialog();
      return; 
    }

    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;
    final totalAmount = _totalProductPrice + _shippingCost;
    final currency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

    try {
      if (_cartItems.isEmpty) return;

      // ✅ 2. CEK SALDO REALTIME (Ambil data terbaru dari DB biar akurat)
      final profileRes = await supabase.from('profiles').select('balance').eq('id', userId).single();
      final double latestBalance = (profileRes['balance'] ?? 0).toDouble();

      // ✅ 3. VALIDASI: Apakah Saldo Cukup?
      if (latestBalance < totalAmount) {
        throw Exception("Saldo tidak cukup! Saldo Anda hanya ${currency.format(latestBalance)}");
      }

      // 4. Cek Stok Produk
      for (var item in _cartItems) {
        final product = item['products'];
        final qty = item['quantity'] as int;
        final currentStock = product['stock'] as int;

        if (qty > currentStock) {
          throw Exception("Stok '${product['name']}' tidak cukup (Sisa: $currentStock)");
        }
      }
      
      final supplierId = _cartItems.first['products']['supplier_id']; 
      
      // ✅ 5. POTONG SALDO USER
      await supabase.from('profiles').update({
        'balance': latestBalance - totalAmount
      }).eq('id', userId);

      // 6. Buat Order
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

      // 7. Proses Item & Kurangi Stok
      for (var item in _cartItems) {
        final product = item['products'];
        final qty = item['quantity'] as int;
        final currentStock = product['stock'] as int;
        
        await supabase.from('order_items').insert({
          'order_id': orderId,
          'product_id': product['id'],
          'quantity': qty,
          'price_at_purchase': product['price'],
        });

        await supabase.from('products').update({
          'stock': currentStock - qty
        }).eq('id', product['id']);
      }

      // 8. Catat Transaksi (Metode: Saldo Veriaga)
      await supabase.from('transactions').insert({
        'order_id': orderId,
        'amount': totalAmount,
        'status': 'paid_held',
        'payment_method': 'Saldo Veriaga', // ✅ Ubah metode pembayaran
      });

      // 9. Hapus Keranjang
      await supabase.from('cart_items').delete().eq('user_id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pembayaran Berhasil! Saldo berkurang.")));
        context.go('/dashboard'); 
      }

    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceAll('Exception: ', '');
        // Tampilkan dialog error yang jelas (terutama kalau saldo kurang)
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Pembayaran Gagal"),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingPayment = false);
    }
  }

  void _showBlockedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Selesaikan Pesanan Dulu! ⚠️"),
        content: const Text("Ada pesanan yang statusnya 'Sampai' tapi belum diverifikasi. Selesaikan dulu ya."),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/dashboard');
            },
            child: const Text("Ke Pesanan Saya"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final totalBill = _totalProductPrice + _shippingCost;
    
    // Logic warna tombol (Abu-abu kalau saldo kurang)
    final bool isBalanceEnough = _currentBalance >= totalBill;

    return Scaffold(
      appBar: AppBar(title: const Text("Pengiriman & Pembayaran")),
      body: _isInitialLoading 
          ? const Center(child: CircularProgressIndicator())
          : _cartItems.isEmpty
              ? const Center(child: Text("Keranjang kosong"))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Alamat Pengiriman", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Gap(8),
                      TextField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: "Alamat Lengkap...",
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const Gap(24),

                      const Text("Metode Pembayaran", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Gap(8),
                      // ✅ Tampilan Saldo di Halaman Checkout
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!)
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_wallet, color: Colors.blue),
                            const Gap(12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Saldo Veriaga", style: TextStyle(fontSize: 12, color: Colors.black54)),
                                Text(currency.format(_currentBalance), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            const Spacer(),
                            if (!isBalanceEnough)
                              const Text("Kurang!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12))
                          ],
                        ),
                      ),
                      const Gap(24),

                      const Text("Rincian Pembayaran", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Gap(8),
                      _buildSummaryRow("Subtotal Produk", _totalProductPrice, currency),
                      _buildSummaryRow("Biaya Pengiriman", _shippingCost, currency),
                      const Divider(thickness: 1, height: 24),
                      _buildSummaryRow("Total Tagihan", totalBill, currency, isTotal: true),
                      
                      const Gap(32),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoadingPayment ? null : _processPayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isBalanceEnough ? const Color(0xFF0F172A) : Colors.grey, // Warna beda kalau saldo kurang
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoadingPayment 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                "BAYAR SEKARANG", 
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                              ),
                        ),
                      ),
                      if (!isBalanceEnough)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Center(child: Text("Silakan Top Up saldo terlebih dahulu di halaman utama.", style: TextStyle(color: Colors.red, fontSize: 12))),
                        )
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