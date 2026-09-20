-- ============================================================================
-- FULL DATABASE SETUP SCRIPT: CV HAOTI SISTEMA HOKINDO
-- Skrip ini menyiapkan SELURUH database dari nol (Fresh Supabase Project)
-- Termasuk tabel Nasabah, Admin, Transaksi, Kurs Mitra, dan Data Dummy Uji Coba.
-- Cukup jalankan (RUN) skrip ini 1 KALI di Supabase SQL Editor.
-- ============================================================================

-- 1. TABEL PENGGUNA (NASABAH & KYC)
CREATE TABLE IF NOT EXISTS public.pengguna (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nama_lengkap VARCHAR(100) NOT NULL,
    nomor_telepon VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    alamat TEXT,
    nik VARCHAR(20),
    pin_hash VARCHAR(64) NOT NULL,           -- SHA-256 hash PIN nasabah (6 digit)
    foto_ktp VARCHAR(255),
    jenis_kelamin VARCHAR(20),
    profesi VARCHAR(100),                    -- Profesi asli nasabah
    pekerjaan VARCHAR(100),                  -- Maksud/tujuan transfer dari kuesioner profil risiko
    sumber_dana VARCHAR(100),                -- Sumber dana APU-PPT (Gaji, Hasil Usaha, dll)
    limit_transaksi NUMERIC DEFAULT 10000000,-- Default limit transfer nasabah Rp 10.000.000
    persetujuan_snk BOOLEAN DEFAULT true,
    dibuat_pada TIMESTAMPTZ DEFAULT now(),
    diperbarui_pada TIMESTAMPTZ DEFAULT now()
);

-- 2. TABEL ADMIN TERPISAH
CREATE TABLE IF NOT EXISTS public.admin (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    nama_lengkap VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(64) NOT NULL,       -- SHA-256 hash password admin
    is_aktif BOOLEAN DEFAULT true,
    dibuat_pada TIMESTAMPTZ DEFAULT now(),
    diperbarui_pada TIMESTAMPTZ DEFAULT now()
);

-- 3. TABEL MITRA KURS (REMITTANCE PARTNERS & FX RATES)
CREATE TABLE IF NOT EXISTS public.mitra_kurs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negara VARCHAR(100) NOT NULL,
    target_currency VARCHAR(10) NOT NULL,
    nama_mitra VARCHAR(50) NOT NULL,
    kurs_jual NUMERIC NOT NULL,
    biaya_fee NUMERIC DEFAULT 0,
    fx_margin NUMERIC DEFAULT 0,
    dibuat_pada TIMESTAMPTZ DEFAULT now()
);

-- 4. TABEL TRANSAKSI OUTGOING REMITTANCE
CREATE TABLE IF NOT EXISTS public.transaksi (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_pengguna UUID REFERENCES public.pengguna(id) ON DELETE CASCADE,
    referensi_transaksi VARCHAR(100) UNIQUE,
    referensi_trans VARCHAR(100),
    nominal_idr NUMERIC NOT NULL,
    kurs_pertukaran NUMERIC NOT NULL,
    biaya_transfer NUMERIC DEFAULT 0,
    nominal_asing NUMERIC NOT NULL,
    mata_uang_tujuan VARCHAR(10) NOT NULL,
    metode_pembayaran VARCHAR(50) DEFAULT 'QRIS',
    payload_kode_qr TEXT,
    batas_waktu_pembayaran TIMESTAMPTZ,
    status_pembayaran VARCHAR(50) DEFAULT 'menunggu_pembayaran', -- menunggu_pembayaran, dibayar, expired, gagal
    status_transfer VARCHAR(50) DEFAULT 'diproses',             -- pending, diproses, diverifikasi, diteruskan, selesai, gagal
    nama_penerima VARCHAR(100),
    no_rek_penerima VARCHAR(50),
    bank_penerima VARCHAR(100),
    tujuan_transfer VARCHAR(100),
    url_resi_digital VARCHAR(255),
    bukti_pembayaran_url TEXT,
    mitra_remitansi VARCHAR(50),
    referensi_mitra VARCHAR(100),
    catatan_admin TEXT,
    diverifikasi_oleh UUID REFERENCES public.admin(id) ON DELETE SET NULL,
    diverifikasi_pada TIMESTAMPTZ,
    diteruskan_pada TIMESTAMPTZ,
    dibuat_pada TIMESTAMPTZ DEFAULT now(),
    diperbarui_pada TIMESTAMPTZ DEFAULT now()
);

-- 5. TABEL AUDIT LOG NASABAH
CREATE TABLE IF NOT EXISTS public.jejak_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_pengguna UUID REFERENCES public.pengguna(id) ON DELETE CASCADE,
    aksi VARCHAR(100) NOT NULL,
    deskripsi TEXT,
    alamat_ip VARCHAR(50),
    dibuat_pada TIMESTAMPTZ DEFAULT now()
);

-- 6. TABEL AUDIT LOG KHUSUS ADMIN (KEPATUHAN APU-PPT)
CREATE TABLE IF NOT EXISTS public.jejak_audit_admin (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_admin UUID REFERENCES public.admin(id) ON DELETE SET NULL,
    aksi VARCHAR(100) NOT NULL,
    deskripsi TEXT,
    id_transaksi UUID REFERENCES public.transaksi(id) ON DELETE CASCADE,
    alamat_ip VARCHAR(50),
    dibuat_pada TIMESTAMPTZ DEFAULT now()
);

-- ============================================================================
-- SEED DATA AWAL (DATA DEFAULT & DATA UJI COBA)
-- ============================================================================

-- A. Akun Admin Default (Username: admin, Password: admin123)
-- SHA-256 dari 'admin123': 240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9
INSERT INTO public.admin (username, nama_lengkap, email, password_hash)
VALUES ('admin', 'Admin Operasional', 'admin@haoti.co.id', '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9')
ON CONFLICT (username) DO NOTHING;

-- B. Akun Nasabah Contoh (PIN: 123456)
-- SHA-256 dari '123456': 8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92
INSERT INTO public.pengguna (
    id, nama_lengkap, nomor_telepon, email, alamat, nik, pin_hash, jenis_kelamin, profesi, pekerjaan, sumber_dana
) VALUES (
    'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d',
    'Budi Santoso',
    '081234567890',
    'budi.santoso@gmail.com',
    'Jl. Raya Darmo No. 45, Surabaya',
    '3578012345670001',
    '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92',
    'Laki-laki',
    'Wiraswasta',
    'Biaya Pendidikan Anak',
    'Hasil Usaha / Tabungan'
) ON CONFLICT (email) DO NOTHING;

-- C. Data Mitra Kurs Resmi (Wallex, Instarem, Transferku)
INSERT INTO public.mitra_kurs (negara, target_currency, nama_mitra, kurs_jual, biaya_fee, fx_margin)
VALUES 
    ('Singapore', 'SGD', 'Wallex', 12050, 25000, 0.002),
    ('Singapore', 'SGD', 'Instarem', 12020, 30000, 0.003),
    ('Singapore', 'SGD', 'Transferku', 12100, 15000, 0.005),
    ('Malaysia', 'MYR', 'Wallex', 3450, 20000, 0.002),
    ('Malaysia', 'MYR', 'Instarem', 3430, 25000, 0.003),
    ('United States', 'USD', 'Wallex', 16250, 35000, 0.002),
    ('United States', 'USD', 'Instarem', 16280, 40000, 0.003),
    ('Australia', 'AUD', 'Wallex', 10800, 30000, 0.002),
    ('Japan', 'JPY', 'Wallex', 105.5, 25000, 0.002)
ON CONFLICT DO NOTHING;

-- D. Data Transaksi Contoh untuk Uji Coba Antrean Admin
INSERT INTO public.transaksi (
    id_pengguna,
    referensi_transaksi,
    referensi_trans,
    nominal_idr,
    kurs_pertukaran,
    biaya_transfer,
    nominal_asing,
    mata_uang_tujuan,
    metode_pembayaran,
    status_pembayaran,
    status_transfer,
    nama_penerima,
    no_rek_penerima,
    bank_penerima,
    tujuan_transfer,
    dibuat_pada
) VALUES 
    -- Transaksi 1: Status "diproses" (Menunggu Verifikasi Admin)
    (
        'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d',
        'TRX-HAOTI-20260910-001',
        'TRX-HAOTI-20260910-001',
        6025000,
        12050,
        25000,
        500.00,
        'SGD',
        'QRIS',
        'dibayar',
        'diproses',
        'Tan Wei Ming',
        '0987654321',
        'DBS Bank Singapore',
        'Pembayaran Uang Kuliah Semester',
        NOW() - INTERVAL '30 minutes'
    ),
    -- Transaksi 2: Status "diverifikasi" (Sudah diverifikasi, Siap Diteruskan ke Wallex/Instarem)
    (
        'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d',
        'TRX-HAOTI-20260910-002',
        'TRX-HAOTI-20260910-002',
        3450000,
        3450,
        20000,
        1000.00,
        'MYR',
        'QRIS',
        'dibayar',
        'diverifikasi',
        'Ahmad Bin Zakaria',
        '1122334455',
        'Maybank Malaysia',
        'Biaya Hidup Keluarga',
        NOW() - INTERVAL '2 hours'
    ),
    -- Transaksi 3: Status "diteruskan" (Sedang Diproses oleh Mitra Wallex)
    (
        'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d',
        'TRX-HAOTI-20260910-003',
        'TRX-HAOTI-20260910-003',
        8125000,
        16250,
        35000,
        500.00,
        'USD',
        'QRIS',
        'dibayar',
        'diteruskan',
        'Johnathan Miller',
        '9988776655',
        'Bank of America',
        'Pembayaran Vendor Software',
        NOW() - INTERVAL '5 hours'
    );
