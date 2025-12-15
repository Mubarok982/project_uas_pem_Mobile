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
  bool _isLoading = false;
  List<Map<String, dynamic>> _cartItems = [];
  double _totalProductPrice = 0;
  final double _shippingCost = 15000;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;

    final profile = await supabase.from('profiles').select().eq('id', userId).single();
    if (profile['address'] != null) {
      _addressController.text = "${profile['address']}, ${profile['city'] ?? ''}";
    }

    final cartData = await supabase
        .from('cart_items')
        .select()
        .eq('user_id', userId);

    List<Map<String, dynamic>> enrichedItems = [];
    double tempTotal = 0;

    for (var item in cartData) {
      final product = await supabase.from('products').select().eq('id', item['product_id']).single();
      
      final qty = item['quantity'] as int;
      final price = product['price'] as int;
      tempTotal += (qty * price);

      final newItem = Map<String, dynamic>.from(item);
      newItem['products'] = product;
      enrichedItems.add(newItem);
    }

    if (mounted) {
      setState(() {
        _cartItems = enrichedItems;
        _totalProductPrice = tempTotal;
      });
    }
  }

  Future<void> _processPayment() async {
    if (_addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Alamat pengiriman wajib diisi!")));
      return;
    }
    
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;

    try {
      if (_cartItems.isEmpty) return;
      final supplierId = _cartItems.first['products']['supplier_id']; 

      final totalAmount = _totalProductPrice + _shippingCost;
      
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

      for (var item in _cartItems) {
        final product = item['products'];
        await supabase.from('order_items').insert({
          'order_id': orderId,
          'product_id': product['id'],
          'quantity': item['quantity'],
          'price_at_purchase': product['price'],
        });
      }

      await supabase.from('transactions').insert({
        'order_id': orderId,
        'amount': totalAmount,
        'status': 'paid_held',
        'payment_method': 'Virtual Account (Simulasi)',
      });

      await supabase.from('cart_items').delete().eq('user_id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pembayaran Berhasil!")));
        context.go('/dashboard'); 
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal Transaksi: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text("Pengiriman & Pembayaran")),
      body: _cartItems.isEmpty 
          ? const Center(child: CircularProgressIndicator())
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
                      onPressed: _isLoading ? null : _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading 
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