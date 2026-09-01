import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'landing_page_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://abnldewabyishhvksrvb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFibmxkZXdhYnlpc2hodmtzcnZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU1NDA2MDMsImV4cCI6MjA5MTExNjYwM30.I5cjL-79kEBAteOI_1rddY5QSPqEILJMU5c4LkaXgCg',
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
      home: const LandingPageScreen(),
        
    );
  }
}