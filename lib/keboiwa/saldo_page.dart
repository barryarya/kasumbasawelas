import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class SaldoPage extends StatefulWidget {
  const SaldoPage({super.key});

  @override
  State<SaldoPage> createState() => _SaldoPageState();
}

class _SaldoPageState extends State<SaldoPage> {
  final String sheetUrl =
      'https://script.google.com/macros/s/AKfycbyvlc0WNpqtnSZLYfXyyYnt1YsfO_3Et7FUpOuakhJXQar9TkUeWAzJsVKmL0fr_XSpqg/exec';

  bool isLoading = true;

  int saldoTerkumpul = 0;
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
        saldoTerkumpul = data['bank'] ?? 0;


        riwayat = data['riwayat'] ?? [];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> tarikSaldo(String sumber) async {
    FocusScope.of(context).unfocus();

    int jumlah = int.tryParse(nominalController.text.replaceAll('.', '')) ?? 0;

    if (jumlah <= 0) {
      showMessage("Nominal tidak valid");
      return;
    }

    setState(() => isLoading = true);

    try {
      await http.post(
        Uri.parse(sheetUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "type": "saldo",
          "aksi": "KURANG",
          "sumber": sumber,
          "jumlah": jumlah,
        }),
      );

      // 🔥 PAKSA ANGAP SUKSES TANPA CEK RESPONSE
      nominalController.clear();
      await fetchSaldo();
      showMessage("Berhasil tarik saldo");
    } catch (e) {
      setState(() => isLoading = false);
      showMessage("Koneksi gagal");
    }
  }

  void showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(title: const Text("Saldo Usaha"), centerTitle: true),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchSaldo,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  saldoBox("Saldo BANK BJB", saldoTerkumpul, Colors.green),
                  saldoBox("Cash Tersedia", saldoCash, Colors.blue),
                  saldoBox("QRIS Belum Dicairkan", saldoQris, Colors.orange),

                  const SizedBox(height: 20),

                  const Text(
                    "Tarik Saldo",
                    style: TextStyle(fontWeight: FontWeight.bold),
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
                          onPressed: () => tarikSaldo("Cash"),
                          child: const Text("Tarik dari Cash"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => tarikSaldo("QRIS"),
                          child: const Text("Tarik dari QRIS"),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    "Riwayat Transaksi",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  ...riwayat.map((item) {
                    return Card(
                      child: ListTile(
                        title: Text(item['sumber'] ?? ""),
                        subtitle: Text(item['tanggal'] ?? ""),
                        trailing: Text(
                          "Rp ${rupiah(int.tryParse(item['jumlah'].toString()) ?? 0)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
  final NumberFormat _formatter = NumberFormat('#,###', 'id_ID');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    String cleanText = newValue.text.replaceAll('.', '');
    int value = int.parse(cleanText);

    String newText = _formatter.format(value);

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
