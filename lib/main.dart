import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'landing_page_screen.dart';
import 'admin/screens/admin_login_screen.dart';
import 'admin/screens/admin_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zmlhpztjlklqhymoflyt.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InptbGhwenRqbGtscWh5bW9mbHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkwMzM4MDAsImV4cCI6MjEwNDYwOTgwMH0.j32MN5Wgglhub4CGnFQyo2h18EMdN6EdEgxb6CIon3E',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CV Haoti Outgoing',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        final uri = Uri.tryParse(name) ?? Uri(path: '/');
        final path = uri.path;

        if (path == '/admin' || path == '/admin/login') {
          return MaterialPageRoute(
            builder: (_) => const AdminLoginScreen(),
            settings: settings,
          );
        }

        if (path == '/admin/dashboard') {
          return MaterialPageRoute(
            builder: (_) => const AdminDashboardScreen(),
            settings: settings,
          );
        }

        // Default rute nasabah (LandingPageScreen)
        return MaterialPageRoute(
          builder: (_) => const LandingPageScreen(),
          settings: settings,
        );
      },
    );
  }
}