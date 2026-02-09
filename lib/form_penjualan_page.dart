import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class FormPenjualanPage extends StatefulWidget {
  const FormPenjualanPage({super.key});

  @override
  State<FormPenjualanPage> createState() => _FormPenjualanPageState();
}

class _FormPenjualanPageState extends State<FormPenjualanPage> {
  final _formKey = GlobalKey<FormState>();

  /// PETUGAS
  String namaPetugas = '';
  final petugasController = TextEditingController();

  /// FORM DATA
  String channel = 'Toko';
  String pembayaran = 'Cash';

  final beratController = TextEditingController();
  final hargaController = TextEditingController();
  final namaPemesanController = TextEditingController();
  final catatanController = TextEditingController();

  /// 🔗 GANTI DENGAN URL GOOGLE APPS SCRIPT
  final String sheetUrl =
      'https://script.google.com/macros/s/AKfycbzhsn3YEQYxRlaol4_yfKry1bUGT_PomIMWOFAPM0v8vSqNq8ZmMBYb_v9vj374O9lTWg/exec';

  @override
  void initState() {
    super.initState();
    loadPetugas();
  }

  @override
  void dispose() {
    petugasController.dispose();
    beratController.dispose();
    namaPemesanController.dispose();
    hargaController.dispose();
    catatanController.dispose();
    super.dispose();
  }

  /// LOAD PETUGAS
  Future<void> loadPetugas() async {
    final prefs = await SharedPreferences.getInstance();
    final nama = prefs.getString('namaPetugas') ?? 'Heri';

    setState(() {
      namaPetugas = nama;
      petugasController.text = nama; // 👉 hanya nama
    });
  }

  /// FORMAT RUPIAH (25.000)
  String formatRupiah(int angka) {
    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(angka);
  }

  /// KIRIM KE GOOGLE SHEET
  Future<void> kirimKeSheet() async {
    final hargaBersih = int.parse(hargaController.text.replaceAll('.', ''));

    final data = {
      'tanggal': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      'petugas': namaPetugas,
      'berat': beratController.text,
      'channel': channel,
      'nama_pemesan':
          (channel == 'ShopeeFood' || channel == 'GoFood') &&
              namaPetugas != 'Heri'
          ? namaPemesanController.text
          : '',
      'pembayaran': pembayaran,
      'harga': hargaBersih,
      'catatan': catatanController.text,
    };

    await http.post(
      Uri.parse(sheetUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
  }

  /// SIMPAN
  Future<void> simpan() async {
    if (_formKey.currentState!.validate()) {
      await kirimKeSheet();

      // ✅ Pop-up Sukses otomatis close
      showDialog(
        context: context,
        barrierDismissible: false, // tidak bisa ditutup dengan tap di luar
        builder: (context) {
          // Tutup otomatis setelah 5 detik
          Future.delayed(const Duration(seconds: 5), () {
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
          });

          return const AlertDialog(
            title: Text('Sukses'),
            content: Text('Data berhasil disimpan ke Sheet'),
          );
        },
      );

      beratController.clear();
      hargaController.clear();
      catatanController.clear();
      namaPemesanController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Penjualan Ubi')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              /// PETUGAS
              TextFormField(
                controller: petugasController,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Petugas',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              /// BERAT
              TextFormField(
                controller: beratController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Berat Ubi (kg)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Berat wajib diisi' : null,
              ),
              const SizedBox(height: 12),

              /// CHANNEL
              DropdownButtonFormField<String>(
                value: channel,
                items: (namaPetugas == 'Heri')
                    ? const [
                        DropdownMenuItem(value: 'Toko', child: Text('Toko')),
                      ]
                    : const [
                        DropdownMenuItem(value: 'Toko', child: Text('Toko')),
                        DropdownMenuItem(
                          value: 'GoFood',
                          child: Text('GoFood'),
                        ),
                        DropdownMenuItem(
                          value: 'ShopeeFood',
                          child: Text('ShopeeFood'),
                        ),
                      ],
                onChanged: (v) => setState(() => channel = v!),
                decoration: const InputDecoration(
                  labelText: 'Channel Penjualan',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              /// NAMA PEMESAN (hanya muncul jika ShopeeFood/GoFood dan bukan Heri)
              if ((channel == 'ShopeeFood' || channel == 'GoFood') &&
                  namaPetugas != 'Heri')
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: namaPemesanController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Pemesan',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if ((channel == 'ShopeeFood' || channel == 'GoFood') &&
                          (v == null || v.isEmpty)) {
                        return 'Nama pemesan wajib diisi';
                      }
                      return null;
                    },
                  ),
                ),

              /// PEMBAYARAN
              DropdownButtonFormField<String>(
                value: pembayaran,
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'QRIS', child: Text('QRIS')),
                  DropdownMenuItem(value: 'Transfer', child: Text('Transfer')),
                ],
                onChanged: (v) => setState(() => pembayaran = v!),
                decoration: const InputDecoration(
                  labelText: 'Metode Pembayaran',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              /// HARGA
              TextFormField(
                controller: hargaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga Total',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Harga wajib diisi' : null,
                onChanged: (value) {
                  final clean = value.replaceAll('.', '');
                  final angka = int.tryParse(clean) ?? 0;
                  final formatted = formatRupiah(angka);

                  hargaController.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(
                      offset: formatted.length,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              /// CATATAN
              TextFormField(
                controller: catatanController,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              /// SIMPAN
              ElevatedButton(onPressed: simpan, child: const Text('Simpan')),
            ],
          ),
        ),
      ),
    );
  }
}
