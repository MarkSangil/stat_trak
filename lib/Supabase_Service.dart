import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  late final SupabaseClient client;

  /// Initialize Supabase using values from the .env file.
  Future<void> init() async {
    final supabaseUrl = dotenv.env['SUPABASE_URL']!;
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    client = Supabase.instance.client;
  }

}
