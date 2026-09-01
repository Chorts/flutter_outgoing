import 'dart:ui';
import 'package:flutter/material.dart';

class AuthGuardOverlay extends StatelessWidget {
  final Widget child; // Halaman asli
  final bool isLoggedIn;

  const AuthGuardOverlay({
    super.key, 
    required this.child, 
    required this.isLoggedIn
  });

  @override
  Widget build(BuildContext context) {
    if (isLoggedIn) return child;

    return Stack(
      children: [
        // 1. Halaman Asli yang di-disable
        AbsorbPointer(
          absorbing: true, // Mematikan semua klik/interaksi
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // Efek blur
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.2), 
                BlendMode.darken
              ),
              child: child,
            ),
          ),
        ),

        // 2. Pop-up Kontainer
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 30),
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 15, spreadRadius: 5)
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_person_rounded, size: 64, color: Colors.blueAccent),
                const SizedBox(height: 16),
                const Text("Ups! Akses Terbatas", 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text(
                  "Halaman ini hanya bisa diakses oleh pengguna terdaftar. Yuk, login dulu!",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 45),
                    backgroundColor: Colors.blueAccent,
                  ),
                  child: const Text("Login / Register", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}