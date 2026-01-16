import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/repositories/transaction_repository.dart';

final dashboardStatsProvider =
    StreamProvider.autoDispose<TransactionTodayStats>((ref) {
      final repo = ref.watch(transactionRepositoryProvider);
      return repo.watchTodayStats();
    });
