import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/local/db/app_database.dart';
import '../../../../data/repositories/transaction_repository.dart';
import '../../../../core/providers.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../features/settings/presentation/providers/settings_provider.dart';

// Simple model for cart item
class CartItem {
  final Product product;
  final int quantity;

  CartItem({required this.product, required this.quantity});

  int get total => product.price * quantity;
}

class PosState {
  final List<CartItem> cart;
  final Customer? selectedCustomer;
  final int taxRate;
  final String defaultPaymentMethod;

  PosState({
    this.cart = const [],
    this.selectedCustomer,
    this.taxRate = 0,
    this.defaultPaymentMethod = 'cash',
  });

  int get subtotal => cart.fold(0, (sum, item) => sum + item.total);
  int get taxAmount => (subtotal * taxRate / 100).round();
  int get totalAmount => subtotal + taxAmount;

  PosState copyWith({
    List<CartItem>? cart,
    Customer? selectedCustomer,
    int? taxRate,
    String? defaultPaymentMethod,
    bool clearCustomer = false,
  }) {
    return PosState(
      cart: cart ?? this.cart,
      selectedCustomer: clearCustomer
          ? null
          : (selectedCustomer ?? this.selectedCustomer),
      taxRate: taxRate ?? this.taxRate,
      defaultPaymentMethod: defaultPaymentMethod ?? this.defaultPaymentMethod,
    );
  }
}

class PosController extends StateNotifier<PosState> {
  final TransactionRepository _transactionRepo;
  final AppDatabase _db;
  final Ref _ref;

  PosController(this._transactionRepo, this._db, this._ref)
    : super(PosState()) {
    _loadDefaultSettings();
  }

  Future<void> _loadDefaultSettings() async {
    final shop = await (_db.select(_db.shops)..limit(1)).getSingleOrNull();
    if (shop != null) {
      state = state.copyWith(
        taxRate: shop.taxRate,
        defaultPaymentMethod: shop.defaultPaymentMethod,
      );
    }
  }

  void setTaxRate(int rate) {
    state = state.copyWith(taxRate: rate);
  }

  void addToCart(Product product) {
    final existingIndex = state.cart.indexWhere(
      (i) => i.product.id == product.id,
    );
    if (existingIndex >= 0) {
      final newCart = List<CartItem>.from(state.cart);
      newCart[existingIndex] = CartItem(
        product: product,
        quantity: newCart[existingIndex].quantity + 1,
      );
      state = state.copyWith(cart: newCart);
    } else {
      state = state.copyWith(
        cart: [
          ...state.cart,
          CartItem(product: product, quantity: 1),
        ],
      );
    }
  }

  void removeFromCart(Product product) {
    state = state.copyWith(
      cart: state.cart.where((i) => i.product.id != product.id).toList(),
    );
  }

  void updateQuantity(Product product, int qty) {
    if (qty <= 0) {
      removeFromCart(product);
      return;
    }
    final newCart = state.cart.map((i) {
      if (i.product.id == product.id) {
        return CartItem(product: product, quantity: qty);
      }
      return i;
    }).toList();
    state = state.copyWith(cart: newCart);
  }

  void clearCart() {
    state = PosState(
      taxRate: state.taxRate,
    ); // Keep tax rate but clear cart/customer
  }

  void setCustomer(Customer? customer) {
    if (customer == null) {
      state = state.copyWith(clearCustomer: true);
    } else {
      state = state.copyWith(selectedCustomer: customer);
    }
  }

  Future<int?> checkout(String paymentMethod, int cashReceived) async {
    if (state.cart.isEmpty) return null;

    if (paymentMethod == 'debt' && state.selectedCustomer == null) {
      return null;
    }

    final subtotal = state.subtotal;
    final tax = state.taxAmount;
    final total = state.totalAmount;
    final change = cashReceived - total;

    final transaction = TransactionsCompanion(
      invoiceNumber: Value('INV-${DateTime.now().millisecondsSinceEpoch}'),
      subtotal: Value(subtotal),
      tax: Value(tax),
      totalAmount: Value(total),
      paymentMethod: Value(paymentMethod),
      cashReceived: Value(paymentMethod == 'cash' ? cashReceived : null),
      changeAmount: Value(paymentMethod == 'cash' ? change : null),
      status: const Value('completed'),
      customerId: Value(state.selectedCustomer?.id),
    );

    final items = state.cart
        .map(
          (i) => TransactionItemsCompanion(
            productId: Value(i.product.id),
            productName: Value(i.product.name),
            quantity: Value(i.quantity),
            priceAtTime: Value(i.product.price),
            costAtTime: Value(i.product.cost),
          ),
        )
        .toList();

    final id = await _transactionRepo.createTransaction(
      transaction: transaction,
      items: items,
    );

    // id is not null because we await createTransaction which returns non-nullable int if successful,
    // though the repo signature says it can be null if not using try-catch internally.
    // In our case, let's just use the result.
    final isSoundEnabled = _ref.read(settingsProvider).isSoundEnabled;
    if (isSoundEnabled) {
      _ref.read(soundServiceProvider).playBeep();
    }

    // Note: don't clearCart() here if we want to show success screen with details,
    // but the app usually clears and shows receipt.
    clearCart();
    return id;
  }
}

final posControllerProvider = StateNotifierProvider<PosController, PosState>((
  ref,
) {
  return PosController(
    ref.watch(transactionRepositoryProvider),
    ref.watch(databaseProvider),
    ref,
  );
});
