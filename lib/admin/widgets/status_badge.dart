import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool isPaymentStatus;

  const StatusBadge({
    super.key,
    required this.status,
    this.isPaymentStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color bgColor;
    Color textColor;
    String label = status.toUpperCase();

    if (isPaymentStatus) {
      switch (s) {
        case 'dibayar':
          bgColor = Colors.green.shade50;
          textColor = Colors.green.shade800;
          label = 'DIBAYAR';
          break;
        case 'menunggu_pembayaran':
          bgColor = Colors.amber.shade50;
          textColor = Colors.amber.shade900;
          label = 'MENUNGGU BAYAR';
          break;
        case 'expired':
          bgColor = Colors.grey.shade100;
          textColor = Colors.grey.shade700;
          label = 'EXPIRED';
          break;
        case 'gagal':
          bgColor = Colors.red.shade50;
          textColor = Colors.red.shade800;
          label = 'GAGAL';
          break;
        default:
          bgColor = Colors.grey.shade100;
          textColor = Colors.grey.shade800;
      }
    } else {
      switch (s) {
        case 'diproses':
        case 'pending':
          bgColor = Colors.amber.shade50;
          textColor = Colors.amber.shade900;
          label = 'DIPROSES';
          break;
        case 'diverifikasi':
          bgColor = Colors.blue.shade50;
          textColor = Colors.blue.shade800;
          label = 'DIVERIFIKASI';
          break;
        case 'diteruskan':
          bgColor = Colors.purple.shade50;
          textColor = Colors.purple.shade800;
          label = 'DITERUSKAN';
          break;
        case 'selesai':
          bgColor = Colors.green.shade50;
          textColor = Colors.green.shade800;
          label = 'SELESAI';
          break;
        case 'gagal':
        case 'ditolak':
          bgColor = Colors.red.shade50;
          textColor = Colors.red.shade800;
          label = 'DITOLAK';
          break;
        default:
          bgColor = Colors.grey.shade100;
          textColor = Colors.grey.shade800;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
