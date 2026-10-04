import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ViewSaldoPage extends StatefulWidget {
  const ViewSaldoPage({super.key});

  @override
  State<ViewSaldoPage> createState() => _ViewSaldoPageState();
}

class _ViewSaldoPageState extends State<ViewSaldoPage> {
  final String sheetUrl =
      'https://script.google.com/macros/s/AKfycbyvlc0WNpqtnSZLYfXyyYnt1YsfO_3Et7FUpOuakhJXQar9TkUeWAzJsVKmL0fr_XSpqg/exec';

  bool isLoading = true;

  int saldoCash = 0;
  int saldoQris = 0;

  List riwayat = [];

  @override
  void initState() {
    super.initState();
    fetchSaldo();
  }

  Future<void> fetchSaldo() async {
    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$sheetUrl?type=saldo'),
        headers: {"Cache-Control": "no-cache"},
      );

      final data = jsonDecode(response.body);

      setState(() {
        saldoCash = data['cash'] ?? 0;
        saldoQris = data['qris'] ?? 0;
        riwayat = data['riwayat'] ?? [];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  String rupiah(int value) => NumberFormat('#,###', 'id_ID').format(value);

  Widget saldoBox(String title, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            "Rp ${rupiah(value)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget riwayatItem(item) {
    int jumlah = int.tryParse(item['jumlah'].toString()) ?? 0;

    return Card(
      child: ListTile(
        title: Text(item['sumber'] ?? ""),
        subtitle: Text(item['tanggal'] ?? ""),
        trailing: Text(
          "Rp ${rupiah(jumlah)}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Saldo Usaha"),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchSaldo,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  saldoBox("Cash Tersedia", saldoCash, Colors.blue),
                  // saldoBox("QRIS Belum Dicairkan", saldoQris, Colors.orange),

                  const SizedBox(height: 30),

                  const Text(
                    "Riwayat Transaksi",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  ...riwayat.map((item) => riwayatItem(item)),
                ],
              ),
            ),
    );
  }
}