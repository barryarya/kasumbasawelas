import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'saldo_page.dart';

class TransaksiSeblakPage extends StatefulWidget {
  const TransaksiSeblakPage({super.key});

  @override
  State<TransaksiSeblakPage> createState() => _TransaksiSeblakPageState();
}

class _TransaksiSeblakPageState extends State<TransaksiSeblakPage> {
  final String sheetUrl =
      'https://script.google.com/macros/s/AKfycbw-jClh_fPOprsv8-sBvpC7Ybg6WkW1t_gm_aDme1E7xfkbWU3qxVV1JdSpLenHwlQp1A/exec';

  List transaksi = [];

  bool isLoading = true;

  int totalPenjualan = 0;
  int totalCash = 0;
  int totalQris = 0;
  int jumlahTransaksi = 0;

  List operasionalHariIni = [];
  int totalOperasional = 0;

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

    await ambilOperasional();

    try {
      final url = '$sheetUrl?type=penjualan&tanggal=$tanggalDipilih';

      print("REQUEST: $url");

      final response = await http.get(Uri.parse(url));

      print("STATUS: ${response.statusCode}");
      print("BODY: ${response.body}");

      final Map<String, dynamic> json = jsonDecode(response.body);

      List data = List.from(json['data'] ?? []).reversed.toList();

      int cash = 0;
      int qris = 0;

      for (var item in data) {
        int harga = int.tryParse(item['harga'].toString()) ?? 0;

        String metode = item['pembayaran'].toString().trim().toLowerCase();

        if (metode == "cash") {
          cash += harga;
        } else {
          qris += harga;
        }
      }

      setState(() {
        transaksi = data;

        totalCash = cash;
        totalQris = qris;

        totalPenjualan = cash + qris;

        jumlahTransaksi = data.length;

        isLoading = false;
      });
    } catch (e, stack) {
      print("ERROR: $e");
      print(stack);

      setState(() {
        isLoading = false;
      });
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

        isLoading = true;
      });

      ambilData();
    }
  }

  String formatRupiah(int angka) {
    return NumberFormat('#,###', 'id_ID').format(angka);
  }

  Widget summaryBox(String title, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text(
              "Rp ${formatRupiah(value)}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> ambilOperasional() async {
    try {
      final response = await http.get(
        Uri.parse('$sheetUrl?type=operasional&tanggal=$tanggalDipilih'),
      );

      final json = jsonDecode(response.body);

      List data = List.from(json['data'] ?? []);

      int total = 0;

      for (var item in data) {
        total += int.tryParse(item['harga'].toString()) ?? 0;
      }

      operasionalHariIni = data;
      totalOperasional = total;
    } catch (e) {
      print("ERROR OPERASIONAL: $e");
    }
  }

  Future<String> generateLaporanWA() async {
    StringBuffer laporan = StringBuffer();

    laporan.writeln("📌 REPORT SALES");
    laporan.writeln("");
    laporan.writeln("Seblak Kasumba");
    laporan.writeln("Tanggal : $tanggalDipilih");
    laporan.writeln("");

    laporan.writeln("━━━━━━━━━━━━━━");
    laporan.writeln("🧾 PENJUALAN");

    for (var item in transaksi) {
      final nama = item['nama_pemesan'].toString();

      final metode = item['pembayaran'].toString();

      final harga = (item['harga'] as num?)?.toInt() ?? 0;

      laporan.writeln("• $nama - ${formatRupiah(harga)} ($metode)");
    }

    laporan.writeln("");
    laporan.writeln("━━━━━━━━━━━━━━");

    laporan.writeln("Jumlah Transaksi : $jumlahTransaksi");
    laporan.writeln("Cash : ${formatRupiah(totalCash)}");
    laporan.writeln("QRIS : ${formatRupiah(totalQris)}");

    laporan.writeln("");
    laporan.writeln("💵 TOTAL PENJUALAN : ${formatRupiah(totalPenjualan)}");

    laporan.writeln("");
    laporan.writeln("━━━━━━━━━━━━━━");
    laporan.writeln("📦 OPERASIONAL");

    if (operasionalHariIni.isEmpty) {
      laporan.writeln("Tidak ada pengeluaran");
    } else {
      for (var item in operasionalHariIni) {
        laporan.writeln(
          "• ${item['nama_barang']} - ${formatRupiah(item['harga'])}",
        );
      }
    }

    laporan.writeln("");

    laporan.writeln("💸 TOTAL OPERASIONAL : ${formatRupiah(totalOperasional)}");

    laporan.writeln("");
    laporan.writeln("━━━━━━━━━━━━━━");
    laporan.writeln("NOTE : ");


    return laporan.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(
        title: const Text("Transaksi Seblak"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: "Lihat Saldo",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SaldoSeblakPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.description),
            onPressed: () async {
              String laporan = await generateLaporanWA();

              showDialog(
                context: context,
                builder: (_) {
                  return AlertDialog(
                    title: const Text("Laporan WA"),
                    content: SingleChildScrollView(
                      child: SelectableText(laporan),
                    ),
                    actions: [
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
                        colors: [Colors.green, Colors.teal],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Total Penjualan",
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Rp ${formatRupiah(totalPenjualan)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Jumlah Transaksi : $jumlahTransaksi",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  Row(
                    children: [
                      summaryBox("Cash", totalCash, Colors.blue),
                      summaryBox("QRIS", totalQris, Colors.orange),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (transaksi.isEmpty)
                    const Center(child: Text("Belum ada transaksi"))
                  else
                    ...transaksi.map((item) {
                      final nama = item['nama_pemesan'].toString();

                      final petugas = item['petugas'] ?? "";

                      final pembayaran = item['pembayaran'].toString();

                      final harga = int.tryParse(item['harga'].toString()) ?? 0;

                      String tanggal = item['tanggal'].toString();
                      String tanggalJam = tanggal;

                      try {
                        DateTime parsed = DateTime.parse(tanggal);

                        tanggalJam = DateFormat(
                          'dd/MM/yyyy HH:mm',
                          'id_ID',
                        ).format(parsed);
                      } catch (e) {
                        tanggalJam = tanggal;
                      }

                      return Card(
                        child: ListTile(
                          title: Text(nama),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Petugas : $petugas"),
                              Text("Pembayaran : $pembayaran"),
                              Text("Tanggal : $tanggalJam"),
                            ],
                          ),
                          trailing: Text(
                            "Rp ${formatRupiah(harga)}",
                            style: const TextStyle(
                              color: Colors.green,
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
