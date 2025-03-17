import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseProvider with ChangeNotifier {
  late final SupabaseClient _client;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  SupabaseClient get client {
    if (!_initialized) {
      throw Exception('SupabaseProvider not initialized yet.');
    }
    return _client;
  }

  Future<void> init() async {
    final supabaseUrl = dotenv.env['SUPABASE_URL']!;
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    _client = Supabase.instance.client;
    _initialized = true;
    notifyListeners();
  }

  Future<User?> signUpUser({
    required String email,
    required String password,
    required String name,
  }) async {
    if (!isInitialized) {
      throw Exception('SupabaseProvider not initialized.');
    }

    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    final user = response.user;
    final session = response.session;

    if (user == null || session == null) {
      return null;
    }
    if (user.emailConfirmedAt == null) {
      return null;
    }

    try {
      await _client
          .from('profiles')
          .insert({
        'id': user.id,
        'full_name': name,
      })
          .select();
      return user;
    } catch (error) {
      return null;
    }
  }

  Future<User?> signInUser({
    required String email,
    required String password,
  }) async {
    if (!isInitialized) {
      throw Exception('SupabaseProvider not initialized.');
    }

    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response.user;
    } catch (error) {
      return null;
    }
  }
}
