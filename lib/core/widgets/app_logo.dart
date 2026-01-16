import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'lib/core/constants/KasirKu.png',
      height: size,
      width: size,
      fit: BoxFit.contain,
    );
  }
}
