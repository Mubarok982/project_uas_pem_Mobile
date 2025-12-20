import 'package:flutter/material.dart';

class VeriagaLogo extends StatelessWidget {
  final double size;
  final bool isColored; // True = Warna Brand, False = Putih polos

  const VeriagaLogo({
    super.key, 
    this.size = 100, 
    this.isColored = true
  });

  @override
  Widget build(BuildContext context) {
    // Warna Brand
    final Color primaryColor = const Color(0xFF0F172A);
    final Color accentColor = const Color(0xFFFBBF24); // Kuning Emas (Trust/Premium)

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // 1. Background Shape (Lingkaran/Rounded Box)
          Container(
            decoration: BoxDecoration(
              color: isColored ? primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(size * 0.25), // Sudut melengkung
              boxShadow: isColored 
                ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
                : [],
            ),
          ),

          // 2. Icon Tas Belanja (Shopping Bag)
          Center(
            child: Icon(
              Icons.shopping_bag_outlined,
              size: size * 0.55,
              color: isColored ? Colors.white : primaryColor,
            ),
          ),

          // 3. Simbol "V" atau Centang (Verified)
          Positioned(
            bottom: size * 0.22,
            right: size * 0.22,
            child: Container(
              padding: EdgeInsets.all(size * 0.05),
              decoration: BoxDecoration(
                color: isColored ? accentColor : primaryColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isColored ? primaryColor : Colors.white, 
                  width: size * 0.05
                ),
              ),
              child: Icon(
                Icons.check, // Simbol Verified
                size: size * 0.2,
                color: isColored ? primaryColor : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}