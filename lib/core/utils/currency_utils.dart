import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyUtils {
  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static String format(num amount) {
    return _formatter.format(amount);
  }

  static NumberFormat get formatter => _formatter;
}

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern('id_ID');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remove all non-digits
    final String onlyDigits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (onlyDigits.isEmpty) return const TextEditingValue();

    final int? value = int.tryParse(onlyDigits);
    if (value == null) return oldValue;

    final String formattedValue = _formatter.format(value);

    return newValue.copyWith(
      text: formattedValue,
      selection: TextSelection.collapsed(offset: formattedValue.length),
    );
  }
}
