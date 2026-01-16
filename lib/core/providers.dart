import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/local/db/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});
