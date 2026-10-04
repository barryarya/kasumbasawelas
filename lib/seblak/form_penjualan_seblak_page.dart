import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'transaksi_page.dart';
import 'operasional_page.dart';
import 'dart:async';
import 'package:kasumbasawelas/core/staff_access_config.dart';
import 'package:kasumbasawelas/pilih_toko_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FormPenjualanSeblakPage extends StatefulWidget {
  const FormPenjualanSeblakPage({super.key});

  @override
  State<FormPenjualanSeblakPage> createState() =>
      _FormPenjualanSeblakPageState();
}

class _FormPenjualanSeblakPageState extends State<FormPenjualanSeblakPage> {
  final namaController = TextEditingController();

  final hargaController = TextEditingController();

  final namaBarangController = TextEditingController();

  final hargaOperasionalController = TextEditingController();

  String pembayaran = "Cash";
  String namaPetugas = "";
  String rolePetugas = "karyawan";
  String sumberOperasional = "KAS";
  bool get isAdmin => StaffAccessConfig.isAdmin(namaPetugas, rolePetugas);

  Future<void> loadPetugas() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      namaPetugas = prefs.getString('namaPetugas') ?? "Belum Dipilih";
      rolePetugas = prefs.getString('rolePetugas') ?? "karyawan";
    });
  }

  bool loading = false;

  final String sheetUrl =
      'https://script.google.com/macros/s/AKfycbw-jClh_fPOprsv8-sBvpC7Ybg6WkW1t_gm_aDme1E7xfkbWU3qxVV1JdSpLenHwlQp1A/exec';

  @override
  void initState() {
    super.initState();
    loadPetugas();
  }

  String formatRupiah(int angka) {
    return NumberFormat('#,###', 'id_ID').format(angka);
  }

  int angka(String text) {
    return int.tryParse(text.replaceAll('.', '')) ?? 0;
  }

  @override
  void dispose() {
    namaController.dispose();

    hargaController.dispose();

    namaBarangController.dispose();

    hargaOperasionalController.dispose();
    super.dispose();
  }

  // ======================
  // SIMPAN PENJUALAN
  // ======================

  Future<void> simpanPenjualan() async {
    String nama = namaController.text.trim();
    int harga = angka(hargaController.text);

    if (!StaffAccessConfig.canInput(namaPetugas)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Akses Terbatas: Anda hanya memiliki izin melihat laporan",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (nama.isEmpty || harga <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama dan harga wajib diisi")),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final data = {
        "type": "penjualan",
        "toko": "seblak",
        "tanggal": DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        "petugas": namaPetugas,
        "nama_pemesan": nama,
        "harga": harga,
        "pembayaran": pembayaran,
      };

      await http.post(
        Uri.parse(sheetUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      // ===== POPUP SUKSES =====
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text("Sukses"),
          content: Text("Data penjualan berhasil disimpan"),
        ),
      );

      // ===== RESET FORM =====
      namaController.clear();
      hargaController.clear();

      setState(() {
        pembayaran = "Cash";
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  // ======================
  // OPERASIONAL
  // ======================

  Future<void> simpanOperasional() async {
    String nama = namaBarangController.text.trim();
    int harga = angka(hargaOperasionalController.text);

    if (nama.isEmpty || harga <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama barang dan harga wajib diisi")),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    final bool potongCash = !isAdmin || (sumberOperasional == 'CASH');
    final String infoSumber = potongCash
        ? "Cash (Laci Kasir)"
        : "Uang Kas (Bank)";

    if (potongCash) {
      if (!nama.contains('*')) {
        nama = "$nama *";
      }
    } else {
      nama = nama.replaceAll('*', '').trim();
    }

    try {
      final data = {
        "type": "operasional",
        "toko": "seblak",
        "petugas": namaPetugas.isNotEmpty ? namaPetugas : "Admin",
        "nama_barang": nama,
        "harga": harga,
        "sumber": potongCash ? "CASH" : "KAS",
      };

      await http.post(
        Uri.parse(sheetUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Sukses"),
          content: Text(
            "Operasional berhasil disimpan.\nSumber Dana: $infoSumber",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );

      namaBarangController.clear();
      hargaOperasionalController.clear();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  void popupSukses(String pesan) {
    showDialog(
      context: context,

      barrierDismissible: false,

      builder: (context) {
        return AlertDialog(
          title: const Text("Berhasil"),

          content: Text(pesan),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },

              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<bool> cekStatusPetugas() async {
    final prefs = await SharedPreferences.getInstance();
    final nama = prefs.getString('namaPetugas');
    return nama != null && nama.isNotEmpty;
  }

  Widget input(String label, TextEditingController controller) {
    return TextField(
      controller: controller,

      keyboardType: TextInputType.number,

      decoration: InputDecoration(
        labelText: label,

        border: const OutlineInputBorder(),
      ),

      onChanged: (value) {
        int hasil = angka(value);

        controller.value = TextEditingValue(
          text: formatRupiah(hasil),

          selection: TextSelection.collapsed(
            offset: formatRupiah(hasil).length,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seblak Kasumba'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: "Kembali ke Pilih Toko",
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const PilihTokoPage()),
              );
            }
          },
        ),
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.dashboard),
          //   onPressed: showLoginD,
          // ),
          IconButton(
            icon: const Icon(Icons.money_off),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OperasionalSeblakPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TransaksiSeblakPage()),
              );
            },
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),

        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.person),
                const SizedBox(width: 10),
                Text(
                  "Petugas : $namaPetugas",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            "Penjualan Seblak",

            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 15),

          TextField(
            controller: namaController,

            decoration: const InputDecoration(
              labelText: "Nama Seblak",

              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 15),

          input("Harga", hargaController),

          const SizedBox(height: 15),

          DropdownButtonFormField(
            initialValue: pembayaran,

            decoration: const InputDecoration(
              labelText: "Pembayaran",

              border: OutlineInputBorder(),
            ),

            items: const [
              DropdownMenuItem(value: "Cash", child: Text("Cash")),

              DropdownMenuItem(value: "QRIS", child: Text("QRIS")),
            ],

            onChanged: (v) {
              setState(() {
                pembayaran = v!;
              });
            },
          ),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: loading ? null : simpanPenjualan,

            child: Text(loading ? "Menyimpan..." : "Simpan Penjualan"),
          ),

          const SizedBox(height: 40),

          const Text(
            "Operasional Seblak",

            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 15),

          if (isAdmin) ...[
            const Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 16,
                  color: Colors.black87,
                ),
                SizedBox(width: 6),
                Text(
                  "Sumber Dana (Role Admin):",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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
            const SizedBox(height: 15),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
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
                        fontSize: 12,
                        color: Color(0xFF1B5E20),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
          ],

          TextField(
            controller: namaBarangController,

            decoration: const InputDecoration(
              labelText: "Nama Barang",

              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 15),

          input("Harga Operasional", hargaOperasionalController),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: loading ? null : simpanOperasional,

            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),

            child: const Text(
              "Simpan Operasional",

              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
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
          color: isSelected ? Colors.black : const Color(0xFFF7F7F5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.shade300,
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
                      color: isSelected ? Colors.white : Colors.black87,
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
}
