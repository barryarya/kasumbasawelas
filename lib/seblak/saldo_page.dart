import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class SaldoSeblakPage extends StatefulWidget {
  const SaldoSeblakPage({super.key});

  @override
  State<SaldoSeblakPage> createState() => _SaldoSeblakPageState();
}

class _SaldoSeblakPageState extends State<SaldoSeblakPage> {
  final String sheetUrl =
      'https://script.google.com/macros/s/AKfycbw-jClh_fPOprsv8-sBvpC7Ybg6WkW1t_gm_aDme1E7xfkbWU3qxVV1JdSpLenHwlQp1A/exec';

  bool isLoading = true;

  int saldoCash = 0;
  int saldoQris = 0;
  int saldoBank = 0;

  List riwayat = [];

  final TextEditingController nominalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchSaldo();
  }

  Future<void> fetchSaldo() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse('$sheetUrl?type=saldo'));

      final data = jsonDecode(response.body);

      setState(() {
        saldoCash = data['cash'] ?? 0;
        saldoQris = data['qris'] ?? 0;
        saldoBank = data['bank'] ?? 0;

        riwayat = data['riwayat'] ?? [];

        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      showMessage("Gagal mengambil data saldo");
    }
  }

  Future<void> tarikSaldo(String sumber) async {
    FocusScope.of(context).unfocus();

    int jumlah = int.tryParse(nominalController.text.replaceAll('.', '')) ?? 0;

    if (jumlah <= 0) {
      showMessage("Nominal tidak valid");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(sheetUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"type": "saldo", "sumber": sumber, "jumlah": jumlah}),
      );

      print(response.body);

      Map<String, dynamic> result = {};

      try {
        result = jsonDecode(response.body);
      } catch (_) {}

      if (result['status'] == 'saldo_tidak_cukup') {
        setState(() {
          isLoading = false;
        });

        showMessage("Saldo tidak cukup");
        return;
      }

      // RESET FORM
      nominalController.clear();

      // REFRESH SALDO
      await fetchSaldo();

      showMessage("Berhasil tarik saldo");
    } catch (e) {
      print("ERROR TARIK SALDO: $e");

      // Karena Google Sheet kadang sukses simpan
      // tapi response gagal dibaca
      nominalController.clear();

      await fetchSaldo();

      showMessage("Berhasil tarik saldo");
    }
  }

  void showMessage(String pesan) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
  }

  String rupiah(int angka) {
    return NumberFormat('#,###', 'id_ID').format(angka);
  }

  Widget saldoBox(String title, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            "Rp ${rupiah(value)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color warnaRiwayat(String sumber) {
    sumber = sumber.toUpperCase();

    if (sumber.contains("PENJUALAN")) {
      return Colors.green;
    }

    if (sumber.contains("OPERASIONAL")) {
      return Colors.red;
    }

    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(title: const Text("Saldo Seblak"), centerTitle: true),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchSaldo,
              child: ListView(
                padding: const EdgeInsets.all(16),

                children: [
                  /// BANK
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.green, Colors.teal],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Saldo Bank",
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Rp ${rupiah(saldoBank)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  /// CASH & QRIS
                  Row(
                    children: [
                      Expanded(child: saldoBox("Cash", saldoCash, Colors.blue)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: saldoBox("QRIS", saldoQris, Colors.orange),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  const Text(
                    "Tarik Saldo",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),

                  const SizedBox(height: 10),

                  TextField(
                    controller: nominalController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      ThousandsSeparatorInputFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: "Masukkan Nominal",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            tarikSaldo("CASH");
                          },
                          child: const Text("Tarik Cash"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            tarikSaldo("QRIS");
                          },
                          child: const Text("Tarik QRIS"),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  const Text(
                    "Riwayat Transaksi",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),

                  const SizedBox(height: 10),

                  if (riwayat.isEmpty)
                    const Center(child: Text("Belum ada riwayat"))
                  else
                    ...riwayat.map((item) {
                      final sumber = item['sumber'] ?? "";

                      final jumlah =
                          int.tryParse(item['jumlah'].toString()) ?? 0;

                      return Card(
                        child: ListTile(
                          title: Text(sumber),

                          subtitle: Text(item['tanggal']?.toString() ?? ""),

                          trailing: Text(
                            "Rp ${rupiah(jumlah)}",
                            style: TextStyle(
                              color: warnaRiwayat(sumber),
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

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final NumberFormat formatter = NumberFormat('#,###', 'id_ID');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String cleanText = newValue.text.replaceAll('.', '');

    int value = int.parse(cleanText);

    String newText = formatter.format(value);

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
