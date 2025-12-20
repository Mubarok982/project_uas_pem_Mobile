# Veriaga 🛍️✅

**Veriaga** adalah aplikasi marketplace mobile berbasis Flutter yang menghubungkan **Supplier** dan **Buyer** dengan sistem transaksi yang aman, terverifikasi, dan *real-time*. Aplikasi ini dirancang dengan antarmuka modern (Clean UI) dan fitur manajemen toko yang lengkap.

![Veriaga Banner](assets/icon/icon.png) 
*(Ganti ini dengan screenshot aplikasi jika ada)*

## 🌟 Fitur Unggulan

### 🛒 Untuk Pembeli (Buyer)
* **Browsing Produk**: Tampilan grid produk dengan pencarian *real-time*.
* **Dompet Digital (Saldo Veriaga)**: Sistem pembayaran instan menggunakan saldo internal.
* **Keranjang Belanja**: Manajemen cart yang dinamis (tambah/kurang qty).
* **Status Pesanan**: Pelacakan status (Belum Bayar, Diproses, Dikirim, Selesai).
* **Verifikasi AI**: (Konsep) Fitur verifikasi saat barang diterima untuk keamanan.
* **Chat Penjual**: Kirim pesan dan komplain langsung ke supplier dengan fitur *Copy Order ID*.

### 📦 Untuk Supplier (Penjual)
* **Dashboard Analitik**: Grafik tren penjualan 7 hari terakhir & ringkasan pendapatan.
* **Manajemen Produk**: Tambah, Edit, dan Hapus produk toko.
* **Manajemen Pesanan**: Terima pesanan dan update status resi.
* **Inbox Chat**: Daftar chat yang dikelompokkan berdasarkan pembeli.

### 🔐 Fitur Umum
* **Autentikasi Aman**: Login & Register menggunakan Supabase Auth.
* **Role-Based Access**: Pembedaan tampilan antara akun Supplier dan Buyer.
* **Auto Login**: Menyimpan sesi user menggunakan *Shared Preferences*.

---

## 🛠️ Tech Stack

* **Frontend**: Flutter (Dart)
* **Backend**: Supabase (PostgreSQL, Auth, Realtime)
* **State Management**: `setState` & `StreamBuilder` (Realtime Data)
* **Routing**: `go_router`
* **UI/UX**: `google_fonts`, `flex_color_scheme`, `gap`, `fl_chart`
* **Local Storage**: `shared_preferences`

---

## 🚀 Cara Instalasi

Ikuti langkah ini untuk menjalankan proyek di komputer lokal:

### 1. Clone Repository
```bash
git clone [https://github.com/username-kamu/veriaga.git](https://github.com/mubarok982/project-uas-pem-mobile.git)
cd veriaga