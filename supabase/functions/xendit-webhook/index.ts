// supabase/functions/xendit-webhook/index.ts
//
// Edge Function ini menerima notifikasi dari Xendit saat QR berhasil dibayar.
// Xendit mengirim POST request ke URL function ini secara otomatis.
//
// Deploy dengan: supabase functions deploy xendit-webhook

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req: Request) => {
  // Xendit mengirim webhook via POST
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    // ── 1. Verifikasi token rahasia dari Xendit ───────────────────────────────
    // Di Xendit Dashboard → Webhooks → set "Webhook Token" lalu simpan di
    // Supabase: Settings → Edge Functions → Secrets → tambah XENDIT_WEBHOOK_TOKEN
    const webhookToken = Deno.env.get('XENDIT_WEBHOOK_TOKEN') ?? '';
    const incomingToken = req.headers.get('x-callback-token') ?? '';

    if (webhookToken && incomingToken !== webhookToken) {
      console.error('Token tidak valid:', incomingToken);
      return new Response('Unauthorized', { status: 401 });
    }

    // ── 2. Parse body dari Xendit ─────────────────────────────────────────────
    const body = await req.json();
    console.log('Xendit webhook diterima:', JSON.stringify(body));

    // Xendit mengirim event type di field 'event'
    // Untuk QR QRIS yang dibayar: event = 'qr.payment'
    const event   = body?.event as string;
    const qrId    = body?.data?.id as string;       // Xendit QR Code ID
    const refId   = body?.data?.reference_id as string; // referensi_transaksi kamu
    const status  = body?.data?.status as string;

    if (event !== 'qr.payment' || !refId) {
      // Event lain (misal: qr.created) — abaikan saja
      return new Response(JSON.stringify({ received: true }), { status: 200 });
    }

    // ── 3. Update tabel transaksi di Supabase ─────────────────────────────────
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '', // Service role — bisa bypass RLS
    );

    const newStatus =
      status === 'SUCCEEDED' || status === 'PAID'
        ? 'pembayaran_diterima'
        : 'gagal';

    const { error } = await supabase
      .from('transaksi')
      .update({
        status_pembayaran: newStatus,
        // Simpan ID QR Xendit untuk referensi audit
        payload_kode_qr: qrId ?? '',
      })
      .eq('referensi_transaksi', refId);

    if (error) {
      console.error('Supabase update error:', error.message);
      return new Response(JSON.stringify({ error: error.message }), { status: 500 });
    }

    console.log(`Transaksi ${refId} diperbarui ke ${newStatus}`);
    return new Response(JSON.stringify({ success: true }), { status: 200 });

  } catch (err) {
    console.error('Webhook error:', err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});