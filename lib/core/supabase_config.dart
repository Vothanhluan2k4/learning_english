import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig{
  static const String supabaseUrl ='https://ymkysurfuuabtkssfqlr.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.ey'
      'Jpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlta3lzdXJmdXVhYnRrc3NmcWxyIiwicm9sZSI6ImFu'
      'b24iLCJpYXQiOjE3NTk0MDY2NDUsImV4cCI6MjA3NDk4MjY0NX0.JnxdCyzRwlMRDBvG7Z_4DqX3ST3kTSSgqOHLrm1caao';
  static Future<void> initialize() async{
    await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
    );
  }
  static SupabaseClient get client => Supabase.instance.client;
}