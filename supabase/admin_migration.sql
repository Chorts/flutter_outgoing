-- ============================================================================
-- SQL MIGRATION: DASHBOARD ADMIN CV HAOTI SISTEMA HOKINDO
-- Eksekusi script ini di Supabase SQL Editor
-- ============================================================================

-- 1. TABEL ADMIN TERPISAH
CREATE TABLE IF NOT EXISTS public.admin (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    nama_lengkap VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(64) NOT NULL, -- SHA-256 Hex Digest (64 karakter)
    is_aktif BOOLEAN DEFAULT true,
    dibuat_pada TIMESTAMPTZ DEFAULT now(),
    diperbarui_pada TIMESTAMPTZ DEFAULT now()
);

-- Akun Admin Default (Username: admin, Password: admin123)
-- Hash SHA-256 dari 'admin123': 240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9
INSERT INTO public.admin (username, nama_lengkap, email, password_hash)
VALUES ('admin', 'Admin Operasional', 'admin@haoti.co.id', '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9')
ON CONFLICT (username) DO NOTHING;

-- 2. TABEL LOG AUDIT KHUSUS ADMIN (AUDIT TRAIL APU-PPT)
-- Memuat id_admin (FK ke admin.id) untuk akuntabilitas person-in-charge
CREATE TABLE IF NOT EXISTS public.jejak_audit_admin (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_admin UUID REFERENCES public.admin(id) ON DELETE SET NULL, -- Siapa admin yang mengeksekusi
    aksi VARCHAR(100) NOT NULL,                                   -- e.g. VERIFIKASI_PEMBAYARAN, PENOLAKAN_PEMBAYARAN, PENERUSAN_MITRA
    deskripsi TEXT,                                               -- Catatan/rincian aksi
    id_transaksi UUID REFERENCES public.transaksi(id) ON DELETE CASCADE, -- Transaksi terkait
    alamat_ip VARCHAR(50),
    dibuat_pada TIMESTAMPTZ DEFAULT now()
);

-- 3. KOLOM TAMBAHAN PADA TABEL TRANSAKSI UNTUK OPERASIONAL ADMIN
ALTER TABLE public.transaksi 
    ADD COLUMN IF NOT EXISTS bukti_pembayaran_url TEXT,
    ADD COLUMN IF NOT EXISTS mitra_remitansi VARCHAR(50),
    ADD COLUMN IF NOT EXISTS referensi_mitra VARCHAR(100),
    ADD COLUMN IF NOT EXISTS catatan_admin TEXT,
    ADD COLUMN IF NOT EXISTS diverifikasi_oleh UUID REFERENCES public.admin(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS diverifikasi_pada TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS diteruskan_pada TIMESTAMPTZ;
