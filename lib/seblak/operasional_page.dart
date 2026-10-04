import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class OperasionalSeblakPage extends StatefulWidget {
  const OperasionalSeblakPage({super.key});

  @override
  State<OperasionalSeblakPage> createState() => _OperasionalSeblakPageState();
}

class _OperasionalSeblakPageState extends State<OperasionalSeblakPage> {
  final String sheetUrl =
      'https://script.google.com/macros/s/AKfycbw-jClh_fPOprsv8-sBvpC7Ybg6WkW1t_gm_aDme1E7xfkbWU3qxVV1JdSpLenHwlQp1A/exec';

  List operasional = [];

  bool isLoading = true;

  int totalPengeluaran = 0;
  int jumlahData = 0;

  String tanggalDipilih = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    ambilData();
  }

  Future<void> ambilData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$sheetUrl?type=operasional&tanggal=$tanggalDipilih'),
      );

      final json = jsonDecode(response.body);

      List data = List.from(json['data'] ?? []).reversed.toList();

      int total = 0;

      for (var item in data) {
        total += int.tryParse(item['harga'].toString()) ?? 0;
      }

      setState(() {
        operasional = data;
        jumlahData = data.length;
        totalPengeluaran = total;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal mengambil data: $e")));
    }
  }

  Future<void> pilihTanggal() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(tanggalDipilih),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        tanggalDipilih = DateFormat('yyyy-MM-dd').format(picked);
      });

      ambilData();
    }
  }

  String formatRupiah(int angka) {
    return NumberFormat('#,###', 'id_ID').format(angka);
  }

  String generateLaporanWA() {
    StringBuffer laporan = StringBuffer();

    laporan.writeln("📌 REPORT OPERASIONAL");
    laporan.writeln("");
    laporan.writeln("Seblak Kasumba");
    laporan.writeln("Tanggal : $tanggalDipilih");
    laporan.writeln("");
    laporan.writeln("━━━━━━━━━━━━━━");
    laporan.writeln("🧾 DETAIL");
    laporan.writeln("");

    for (var item in operasional) {
      laporan.writeln(
        "• ${item['nama_barang']} - Rp ${formatRupiah(int.tryParse(item['harga'].toString()) ?? 0)}",
      );
    }

    laporan.writeln("");
    laporan.writeln("━━━━━━━━━━━━━━");
    laporan.writeln("");
    laporan.writeln("Jumlah Data : $jumlahData");
    laporan.writeln(
      "💸 Total Pengeluaran : Rp ${formatRupiah(totalPengeluaran)}",
    );

    return laporan.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(
        title: const Text("Operasional Seblak"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.description),
            onPressed: () {
              if (operasional.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Belum ada data operasional")),
                );
                return;
              }

              String laporan = generateLaporanWA();

              showDialog(
                context: context,
                builder: (_) {
                  return AlertDialog(
                    title: const Text("Laporan Operasional"),
                    content: SingleChildScrollView(
                      child: SelectableText(laporan),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: laporan));

                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Laporan berhasil disalin"),
                            ),
                          );
                        },
                        child: const Text("Copy"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text("Tutup"),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: ambilData,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Tanggal : $tanggalDipilih",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton(
                        onPressed: pilihTanggal,
                        child: const Text("Pilih"),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.red, Colors.orange],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Total Pengeluaran",
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Rp ${formatRupiah(totalPengeluaran)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Jumlah Data : $jumlahData",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (operasional.isEmpty)
                    const Center(child: Text("Belum ada data operasional"))
                  else
                    ...operasional.map((item) {
                      final nama = item['nama_barang'].toString();

                      final harga = int.tryParse(item['harga'].toString()) ?? 0;

                      String tanggal = item['tanggal'].toString();

                      try {
                        DateTime parsed = DateTime.parse(tanggal);

                        tanggal = DateFormat(
                          'dd/MM/yyyy HH:mm',
                          'id_ID',
                        ).format(parsed);
                      } catch (_) {}

                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.shopping_cart,
                            color: Colors.red,
                          ),
                          title: Text(nama),
                          subtitle: Text("Tanggal : $tanggal"),
                          trailing: Text(
                            "Rp ${formatRupiah(harga)}",
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
      ),
    );
  }
}
