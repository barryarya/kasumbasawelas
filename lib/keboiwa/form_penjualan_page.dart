import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'transaksi_page.dart';
import 'operasional_page.dart';
import 'dashboard_page.dart';
import 'dart:async';
import 'package:kasumbasawelas/scanner/scan_buku_page.dart';
import 'package:kasumbasawelas/core/price_config.dart';
import 'package:kasumbasawelas/core/staff_access_config.dart';
import 'package:kasumbasawelas/pilih_toko_page.dart';

class FormPenjualanPage extends StatefulWidget {
  const FormPenjualanPage({super.key});

  @override
  State<FormPenjualanPage> createState() => _FormPenjualanPageState();
}

class _FormPenjualanPageState extends State<FormPenjualanPage> {
  final _formKey = GlobalKey<FormState>();
  int getHargaPerKg() => PriceConfig.getHargaPerKg(jenis);

  bool isUpdating = false; // supaya tidak loop listener
  bool isUpdatingBerat = false;
  bool isUpdatingHarga = false;
  bool sedangSimpan = false; // 🔥 mencegah double input

  double round1Decimal(double value) {
    return double.parse(value.toStringAsFixed(1));
  }

  int roundUpToThousand(int value) {
    return ((value / 1000).ceil()) * 1000;
  }

  /// ================= PETUGAS =================
  String namaPetugas = '';
  bool bolehInput = true;
  final petugasController = TextEditingController();

  Future<bool> cekStatusPetugas() async {
    final prefs = await SharedPreferences.getInstance();
    final nama = prefs.getString('namaPetugas');
    return nama != null && nama.isNotEmpty;
  }

  /// ================= FORM PENJUALAN =================
  String? jenis;
  String channel = 'Toko';
  String pembayaran = 'Cash';
  String? jenisUbi;
  String? jenisCilembu = 'Bakar';

  final beratController = TextEditingController();
  final hargaController = TextEditingController();
  final namaPemesanController = TextEditingController();
  final catatanController = TextEditingController();

  /// ================= FORM OPERASIONAL =================
  final namaBarangController = TextEditingController();
  final hargaOperasionalController = TextEditingController();
  String rolePetugas = 'karyawan';
  String sumberOperasional = 'KAS'; // Opsi admin: 'KAS' atau 'CASH'
  bool get isAdmin => StaffAccessConfig.isAdmin(namaPetugas, rolePetugas);

  final String sheetUrl =
      'https://script.google.com/macros/s/AKfycbyvlc0WNpqtnSZLYfXyyYnt1YsfO_3Et7FUpOuakhJXQar9TkUeWAzJsVKmL0fr_XSpqg/exec';

  @override
  void initState() {
    super.initState();

    loadPetugas();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showPeringatanInput();
    });

    beratController.addListener(() {
      if (isUpdating) return;
      if (beratController.text.isEmpty) return;

      isUpdating = true;

      hitungHargaDariBerat();

      isUpdating = false;
    });

    hargaController.addListener(() {
      if (isUpdating) return;
      if (hargaController.text.isEmpty) return;

      isUpdating = true;

      String text = hargaController.text.replaceAll('.', '');
      int harga = int.tryParse(text) ?? 0;

      // 🔥 Format ribuan TANPA pembulatan
      String formatted = formatRupiah(harga);

      hargaController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );

      // 🔥 Hitung berat dari harga asli
      int hargaAsli = harga;

      double berat = hargaAsli / getHargaPerKg();
      berat = round1Decimal(berat);

      beratController.text = berat.toStringAsFixed(1).replaceAll('.', ',');

      isUpdating = false;
    });

    hargaOperasionalController.addListener(() {
      if (hargaOperasionalController.text.isEmpty) return;

      String text = hargaOperasionalController.text.replaceAll('.', '');

      int harga = int.tryParse(text) ?? 0;

      String formatted = formatRupiah(harga);

      hargaOperasionalController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    });
  }

  void hitungHargaDariBerat() {
    if (beratController.text.isEmpty) return;
    if (jenis == null) return;

    double berat = parseBeratToDouble(beratController.text);
    double beratRounded = round1Decimal(berat);

    int total = (beratRounded * getHargaPerKg()).round();

    // ✅ Semua ubi dibulatkan ke atas
    total = roundUpToThousand(total);

    hargaController.text = formatRupiah(total);
  }

  void formatHargaInput() {
    String text = hargaController.text.replaceAll('.', '');

    if (text.isEmpty) return;

    final number = int.tryParse(text);
    if (number == null) return;

    final formatted = formatRupiah(number);

    hargaController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  @override
  void dispose() {
    petugasController.dispose();
    beratController.dispose();
    hargaController.dispose();
    namaPemesanController.dispose();
    catatanController.dispose();
    namaBarangController.dispose();
    hargaOperasionalController.dispose();

    super.dispose();
  }

  Future<void> loadPetugas() async {
    final prefs = await SharedPreferences.getInstance();

    final nama = prefs.getString('namaPetugas') ?? '';
    final role = prefs.getString('rolePetugas') ?? 'karyawan';

    setState(() {
      namaPetugas = nama;
      rolePetugas = role;
      petugasController.text = nama;

      // Hak input petugas ditentukan secara terpusat & dinamis
      bolehInput = StaffAccessConfig.canInput(nama);
    });
  }

  String formatRupiah(int angka) {
    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(angka);
  }

  double parseBeratToDouble(String input) {
    input = input.trim().replaceAll(',', '.');

    // contoh: 1 1/4
    if (input.contains(' ')) {
      final parts = input.split(' ');
      if (parts.length == 2) {
        final angkaUtuh = double.tryParse(parts[0]) ?? 0;
        if (parts[1].contains('/')) {
          final pecahan = parts[1].split('/');
          if (pecahan.length == 2) {
            final pembilang = double.tryParse(pecahan[0]) ?? 0;
            final penyebut = double.tryParse(pecahan[1]) ?? 1;
            return angkaUtuh + (pembilang / penyebut);
          }
        }
      }
    }

    // contoh: 1/4
    if (input.contains('/')) {
      final pecahan = input.split('/');
      if (pecahan.length == 2) {
        final pembilang = double.tryParse(pecahan[0]) ?? 0;
        final penyebut = double.tryParse(pecahan[1]) ?? 1;
        return pembilang / penyebut;
      }
    }

    return double.tryParse(input) ?? 0;
  }

  String convertBerat(String input) {
    input = input.trim().replaceAll(',', '.');

    if (input.contains(' ')) {
      final parts = input.split(' ');
      if (parts.length == 2) {
        final angkaUtuh = double.tryParse(parts[0]) ?? 0;
        if (parts[1].contains('/')) {
          final pecahan = parts[1].split('/');
          if (pecahan.length == 2) {
            final pembilang = double.tryParse(pecahan[0]) ?? 0;
            final penyebut = double.tryParse(pecahan[1]) ?? 1;
            return (angkaUtuh + (pembilang / penyebut)).toString().replaceAll(
              '.',
              ',',
            );
          }
        }
      }
    }

    if (input.contains('/')) {
      final pecahan = input.split('/');
      if (pecahan.length == 2) {
        final pembilang = double.tryParse(pecahan[0]) ?? 0;
        final penyebut = double.tryParse(pecahan[1]) ?? 1;
        return (pembilang / penyebut).toString().replaceAll('.', ',');
      }
    }

    return input.replaceAll('.', ',');
  }

  /// ================= KIRIM PENJUALAN =================
  Future<void> kirimKeSheet() async {
    int hargaBersih =
        int.tryParse(hargaController.text.replaceAll('.', '')) ?? 0;

    final data = {
      "type": "penjualan",
      "tanggal": DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      "petugas": namaPetugas,
      "berat": convertBerat(beratController.text),
      "jenis": jenis,
      "channel": channel,
      "nama_pemesan": (channel == 'ShopeeFood' || channel == 'GoFood')
          ? namaPemesanController.text
          : '',
      "pembayaran": pembayaran,
      "harga": hargaBersih,
      "catatan": catatanController.text,
    };

    await http.post(
      Uri.parse(sheetUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
  }

  /// ================= KIRIM OPERASIONAL =================
  Future<void> kirimOperasional() async {
    final hargaBersih = int.parse(
      hargaOperasionalController.text.replaceAll('.', ''),
    );

    String namaBarang = namaBarangController.text.trim();

    // Jika staff/karyawan: otomatis potong CASH (tanda *)
    // Jika admin: sesuai pilihan Admin ('CASH' atau 'KAS')
    final bool potongCash = !isAdmin || (sumberOperasional == 'CASH');

    if (potongCash) {
      if (!namaBarang.contains('*')) {
        namaBarang = "$namaBarang *";
      }
    } else {
      namaBarang = namaBarang.replaceAll('*', '').trim();
    }

    final data = {
      "type": "operasional",
      "nama_barang": namaBarang,
      "harga": hargaBersih,
      "sumber": potongCash ? "CASH" : "KAS",
      "petugas": namaPetugas,
    };

    await http.post(
      Uri.parse(sheetUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
  }

  Future<void> simpan() async {
    if (sedangSimpan) return;

    setState(() => sedangSimpan = true);

    showLoadingDialog(); // 🔥 tampilkan loading

    bool aktif = await cekStatusPetugas();

    if (!aktif) {
      Navigator.pop(context); // tutup loading
      setState(() => sedangSimpan = false);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      Navigator.pop(context); // tutup loading
      setState(() => sedangSimpan = false);
      return;
    }

    await kirimKeSheet();

    Navigator.pop(context); // 🔥 tutup loading setelah selesai

    showDialog(
      context: context,
      builder: (_) => const AlertDialog(
        title: Text("Sukses"),
        content: Text("Data Penjualan berhasil disimpan"),
      ),
    );

    beratController.clear();
    hargaController.clear();
    namaPemesanController.clear();
    catatanController.clear();

    setState(() {
      sedangSimpan = false;
    });
  }

  void scanCatatan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanBukuPage(
          tokoName: "Kebo Iwa",
          sheetUrl: sheetUrl,
          namaPetugas: namaPetugas,
          bolehInput: bolehInput,
        ),
      ),
    );
  }

  Future<void> simpanOperasional() async {
    if (sedangSimpan) return;

    setState(() => sedangSimpan = true);

    bool aktif = await cekStatusPetugas();

    if (!aktif) {
      setState(() => sedangSimpan = false);
      return;
    }

    if (namaBarangController.text.isEmpty ||
        hargaOperasionalController.text.isEmpty) {
      setState(() => sedangSimpan = false);
      return;
    }

    final bool potongCash = !isAdmin || (sumberOperasional == 'CASH');
    final String infoSumber = potongCash
        ? "Cash (Laci Kasir)"
        : "Uang Kas (Bank)";

    await kirimOperasional();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sukses'),
        content: Text(
          'Operasional berhasil disimpan.\nSumber Dana: $infoSumber',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    namaBarangController.clear();
    hargaOperasionalController.clear();

    setState(() {
      sedangSimpan = false; // 🔥 reset tombol setelah selesai
    });
  }

  void showPeringatanInput() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("⚠️ Peringatan"),
          content: const Text(
            "Periksa kembali input penjualan agar sesuai dengan transaksi yang terjadi.\n\n"
            "Pastikan berat ubi, harga, dan metode pembayaran (QRIS / Cash) sudah sesuai dengan transaksi pelanggan.\n\n"
            "Kesalahan input dapat mempengaruhi laporan penjualan.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Mengerti"),
            ),
          ],
        );
      },
    );
  }

  void showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return PopScope(
          canPop: false,
          child: Center(
            child: Container(
              width: 130,
              height: 130,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),

                  SizedBox(height: 20),

                  Text(
                    "Memuat",
                    style: TextStyle(color: Colors.white, fontSize: 22),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void showLoginDialog() {
    final user = TextEditingController();
    final pass = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Login Admin"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: user,
              decoration: const InputDecoration(labelText: "Username"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              if (user.text == "admin" && pass.text == "admin99") {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DashboardPage()),
                );
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("Login salah")));
              }
            },
            child: const Text("Login"),
          ),
        ],
      ),
    );
  }

  void showMenuBottomSheet(
    BuildContext context, {
    required String title,
    required Color color,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),

              const SizedBox(height: 15),

              /// JENIS UBI
              /// KHUSUS UBI CILEMBU
              if (title == 'Ubi Cilembu' || title == 'Ubi Ungu') ...[
                DropdownButtonFormField<String>(
                  initialValue: jenis,
                  decoration: const InputDecoration(
                    labelText: "Jenis Ubi",
                    border: OutlineInputBorder(),
                  ),
                  items: title == "Ubi Ungu"
                      ? const [
                          DropdownMenuItem(
                            value: 'Ubi Ungu Mentah',
                            child: Text('Mentah'),
                          ),
                          DropdownMenuItem(
                            value: 'Ubi Ungu Bakar',
                            child: Text('Bakar'),
                          ),
                        ]
                      : const [
                          DropdownMenuItem(
                            value: 'Mentah',
                            child: Text('Mentah'),
                          ),
                          DropdownMenuItem(
                            value: 'Bakar',
                            child: Text('Bakar'),
                          ),
                        ],
                  onChanged: (value) {
                    setState(() {
                      jenis = value!;
                      hitungHargaDariBerat();
                    });
                  },
                ),

                const SizedBox(height: 15),
              ],

              TextFormField(
                controller: beratController,
                decoration: const InputDecoration(labelText: "Berat"),
              ),

              const SizedBox(height: 15),

              /// PEMBAYARAN
              DropdownButtonFormField<String>(
                initialValue: pembayaran,
                decoration: const InputDecoration(
                  labelText: "Metode Pembayaran",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'QRIS BJB', child: Text('QRIS BJB')),
                  DropdownMenuItem(
                    value: 'ShopeePay',
                    child: Text('ShopeePay'),
                  ),
                  DropdownMenuItem(value: 'GoPay', child: Text('GoPay')),
                ],
                onChanged: (value) {
                  setState(() {
                    pembayaran = value!;
                  });
                },
              ),

              const SizedBox(height: 10),

              TextFormField(
                controller: hargaController,
                decoration: const InputDecoration(labelText: "Harga"),
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: catatanController,
                decoration: const InputDecoration(labelText: "Catatan"),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: color),
                  onPressed: () {
                    Navigator.pop(context);
                    simpan();
                  },
                  child: const Text("Simpan"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),

      // ================= BOTTOM NAVIGATION =================
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBottomNavItem(
                  icon: Icons.point_of_sale_rounded,
                  label: "Penjualan",
                  active: true,
                  onTap: () {},
                ),

                _buildBottomNavItem(
                  icon: Icons.receipt_long_rounded,
                  label: "Transaksi",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TransaksiPage()),
                    );
                  },
                ),

                _buildBottomNavItem(
                  icon: Icons.account_balance_wallet_rounded,
                  label: "Operasional",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OperasionalPage(),
                      ),
                    );
                  },
                ),

                _buildBottomNavItem(
                  icon: Icons.dashboard_rounded,
                  label: "Dashboard",
                  onTap: showLoginDialog,
                ),
              ],
            ),
          ),
        ),
      ),

      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            children: [
              // =====================================================
              // HEADER
              // =====================================================
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: Color(0xFF20251F),
                      ),
                      tooltip: "Kembali ke Pilih Toko",
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PilihTokoPage(),
                            ),
                          );
                        }
                      },
                    ),
                  ),

                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8A00),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.eco_rounded,
                      color: Colors.white,
                      size: 27,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Kasumba Sawelas",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Kebo iwa",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: IconButton(
                      onPressed: showLoginDialog,
                      icon: const Icon(Icons.dashboard_rounded, size: 21),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // =====================================================
              // GREETING
              // =====================================================
              Text(
                "Halo, ${namaPetugas.isEmpty ? 'Petugas' : namaPetugas} 👋",
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                "Siap mencatat penjualan hari ini?",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),

              const SizedBox(height: 20),

              // =====================================================
              // PETUGAS CARD
              // =====================================================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF20251F), Color(0xFF343B32)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),

                    const SizedBox(width: 13),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "PETUGAS AKTIF",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            namaPetugas.isEmpty ? "Memuat..." : namaPetugas,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.circle, color: Color(0xFF5BE37A), size: 8),
                          SizedBox(width: 6),
                          Text(
                            "Online",
                            style: TextStyle(
                              color: Color(0xFF8FF0A3),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // =====================================================
              // TITLE
              // =====================================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Penjualan Kebo Iwa",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        "Pilih produk yang dijual",
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8A00).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "PRODUK",
                      style: TextStyle(
                        color: Color(0xFFFF7800),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // =====================================================
              // PRODUCT GRID
              // =====================================================
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 13,
                mainAxisSpacing: 13,
                childAspectRatio: 0.82,
                children: [
                  buildMenuCard(
                    title: "Ubi Cilembu",
                    subtitle: "Mulai Rp25.000/kg",
                    imagePath: 'assets/ubi_cilembu.jpeg',
                    color: const Color(0xFFFF8A00),
                    onTap: () {
                      if (!bolehInput) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Anda hanya bisa melihat laporan, tidak bisa input",
                            ),
                          ),
                        );
                        return;
                      }

                      setState(() {
                        jenis = 'Mentah';
                      });

                      showMenuBottomSheet(
                        context,
                        title: "Ubi Cilembu",
                        color: const Color(0xFFFF8A00),
                      );
                    },
                  ),

                  buildMenuCard(
                    title: "Ubi Ungu",
                    subtitle: "Mulai Rp25.000/kg",
                    imagePath: 'assets/ubi_ungu.jpg',
                    color: const Color(0xFF7545B8),
                    onTap: () {
                      if (!bolehInput) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Anda hanya bisa melihat laporan, tidak bisa input",
                            ),
                          ),
                        );
                        return;
                      }

                      setState(() {
                        jenis = 'Ubi Ungu Mentah';
                      });

                      showMenuBottomSheet(
                        context,
                        title: "Ubi Ungu",
                        color: const Color(0xFF7545B8),
                      );
                    },
                  ),

                  buildMenuCard(
                    title: "Ubi Yakon",
                    subtitle: "Rp35.000/kg",
                    imagePath: 'assets/ubi_yakon.jpeg',
                    color: const Color(0xFF3D8B55),
                    onTap: () {
                      if (!bolehInput) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Anda hanya bisa melihat laporan, tidak bisa input",
                            ),
                          ),
                        );
                        return;
                      }

                      setState(() {
                        jenis = 'Mentah';
                      });

                      showMenuBottomSheet(
                        context,
                        title: "Ubi Yakon",
                        color: const Color(0xFF3D8B55),
                      );
                    },
                  ),

                  buildMenuCard(
                    title: "Coming Soon",
                    subtitle: "Produk berikutnya",
                    imagePath: 'assets/soon.png',
                    color: const Color(0xFF8A6A52),
                    onTap: () {},
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // =====================================================
              // SCAN BUKU
              // =====================================================
              GestureDetector(
                onTap: scanCatatan,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2474E5), Color(0xFF1857B8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2474E5).withValues(alpha: 0.20),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.document_scanner_rounded,
                          color: Colors.white,
                          size: 27,
                        ),
                      ),

                      const SizedBox(width: 15),

                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Scan Buku",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Scan catatan menggunakan kamera",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // =====================================================
              // OPERASIONAL
              // =====================================================
              if (bolehInput) ...[
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_rounded, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      "Operasional",
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                Text(
                  "Catat kebutuhan dan pengeluaran toko",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),

                const SizedBox(height: 15),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pilihan Sumber Dana untuk Admin / Info Badge untuk Karyawan
                      if (isAdmin) ...[
                        const Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 16,
                              color: Color(0xFF20251F),
                            ),
                            SizedBox(width: 6),
                            Text(
                              "Sumber Dana (Role Admin):",
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF20251F),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSumberOption(
                                label: "Uang Kas",
                                sublabel: "Bank (Kas Toko)",
                                icon: Icons.account_balance_outlined,
                                isSelected: sumberOperasional == 'KAS',
                                onTap: () {
                                  setState(() => sumberOperasional = 'KAS');
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildSumberOption(
                                label: "Cash",
                                sublabel: "Laci Kasir",
                                icon: Icons.payments_outlined,
                                isSelected: sumberOperasional == 'CASH',
                                onTap: () {
                                  setState(() => sumberOperasional = 'CASH');
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFC8E6C9)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: Color(0xFF2E7D32),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Operasional otomatis dipotong dari Uang Cash (Laci Kasir)",
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF1B5E20),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Nama barang
                      TextFormField(
                        controller: namaBarangController,
                        decoration: InputDecoration(
                          labelText: "Nama Barang",
                          hintText: "Contoh: Plastik, Gas, Kardus",
                          prefixIcon: const Icon(Icons.inventory_2_outlined),
                          filled: true,
                          fillColor: const Color(0xFFF7F7F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF20251F),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 13),

                      // Harga
                      TextFormField(
                        controller: hargaOperasionalController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "Harga",
                          hintText: "Rp 0",
                          prefixIcon: const Icon(Icons.payments_outlined),
                          filled: true,
                          fillColor: const Color(0xFFF7F7F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF20251F),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: sedangSimpan ? null : simpanOperasional,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF20251F),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: sedangSimpan
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_circle_outline_rounded,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      "Simpan Operasional",
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSumberOption({
    required String label,
    required String sublabel,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF20251F) : const Color(0xFFF7F7F5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF20251F) : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF20251F),
                    ),
                  ),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: isSelected ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                size: 15,
                color: Colors.white,
              ),
          ],
        ),
      ),
    );
  }

  Widget buildMenuCard({
    required String title,
    required String subtitle,
    required String imagePath,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: color.withValues(alpha: 0.08),
        highlightColor: color.withValues(alpha: 0.04),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ================= IMAGE =================
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(19),
                          ),
                        ),
                      ),

                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Image.asset(imagePath, fit: BoxFit.contain),
                        ),
                      ),

                      Positioned(
                        top: 9,
                        right: 9,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ================= TITLE =================
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 4),

                // ================= PRICE =================
                Text(
                  subtitle,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 9),

                // ================= ACTION =================
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Input penjualan",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),

                    Icon(Icons.chevron_right_rounded, color: color, size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    bool active = false,
    required VoidCallback onTap,
  }) {
    final Color activeColor = const Color(0xFFFF8A00);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 32,
              decoration: BoxDecoration(
                color: active
                    ? activeColor.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 21,
                color: active ? activeColor : Colors.grey.shade500,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? activeColor : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
