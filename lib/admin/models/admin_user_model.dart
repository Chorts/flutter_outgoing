class AdminUser {
  final String id;
  final String username;
  final String namaLengkap;
  final String email;
  final bool isAktif;
  final DateTime? dibuatPada;

  const AdminUser({
    required this.id,
    required this.username,
    required this.namaLengkap,
    required this.email,
    this.isAktif = true,
    this.dibuatPada,
  });

  factory AdminUser.fromMap(Map<String, dynamic> map) {
    return AdminUser(
      id: map['id']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      namaLengkap: map['nama_lengkap']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      isAktif: map['is_aktif'] as bool? ?? true,
      dibuatPada: map['dibuat_pada'] != null
          ? DateTime.tryParse(map['dibuat_pada'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'nama_lengkap': namaLengkap,
      'email': email,
      'is_aktif': isAktif,
      'dibuat_pada': dibuatPada?.toIso8601String(),
    };
  }
}
