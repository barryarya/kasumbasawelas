import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kasumbasawelas/auth/setup_petugas_page.dart';
import 'dart:async';

import 'view_saldo_page.dart';
import 'package:kasumbasawelas/core/whatsapp_recap_service.dart';

class TransaksiDalungPage extends StatefulWidget {
  const TransaksiDalungPage({super.key});

  @override
  State<TransaksiDalungPage> createState() => _TransaksiDalungPageState();
}

class _TransaksiDalungPageState extends State<TransaksiDalungPage> {
  final String sheetUrl =
      'https://script.google.com/macros/s/AKfycbzYEwkgkVC5rIgxMkkHRvG1UOwtki_-WU0r3aoj2SuqJXVQ6e82CRsyMrkM3rrdX_KPzw/exec';

  List transaksi = [];
  bool isLoading = true;

  int totalPenjualan = 0;
  int totalCash = 0;
  int totalQrisBJB = 0;
  int totalGoPay = 0;
  int totalShopeePay = 0;
  int jumlahTransaksi = 0;

  double totalKgUngu = 0;
  int totalUangUngu = 0;
  int totalUngu = 0;

  double totalKg = 0;
  int totalBakar = 0;
  int totalMentah = 0;
  int totalUang = 0;
  int totalCilembu = 0;

  double totalKgYakon = 0;
  int totalUangYakon = 0;
  int totalYakon = 0;

  int totalPengeluaran = 0;
  List pengeluaran = [];

  String tanggalDipilih = DateFormat('yyyy-MM-dd').format(DateTime.now());
  bool isBulanan = false;
  String bulanDipilih = DateFormat('yyyy-MM').format(DateTime.now());

  Future<void> cekStatusPetugas() async {
    final prefs = await SharedPreferences.getInstance();
    final nama = prefs.getString('namaPetugas');
    if (nama == null || nama.isEmpty) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SetupPetugasPage()),
        (route) => false,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    ambilData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> ambilData() async {
    try {
      final response = await http.get(
        Uri.parse(
          isBulanan
              ? '$sheetUrl?type=penjualan&bulan=$bulanDipilih'
              : '$sheetUrl?type=penjualan&tanggal=$tanggalDipilih',
        ),
      );

      final json = jsonDecode(response.body);
      List data = List.from(json['data'] ?? []).reversed.toList();

      int cash = 0;
      int qrisBjb = 0;
      int gopay = 0;
      int shopeepay = 0;

      double kg = 0;
      int bakar = 0;
      int mentah = 0;
      int uang = 0;
      int cilembu = 0;

      double kgUngu = 0;
      int uangUngu = 0;
      int ungu = 0;

      double kgYakon = 0;
      int uangYakon = 0;
      int yakon = 0;

      for (var item in data) {
        int harga = int.tryParse(item['harga'].toString()) ?? 0;
        double berat = double.tryParse(item['berat'].toString()) ?? 0;

        String jenis = item['jenis'].toString().toLowerCase();

        if (jenis.contains('ungu')) {
          kgUngu += berat;
          uangUngu += harga;
          ungu++;
        } else if (jenis.contains('yakon')) {
          kgYakon += berat;
          uangYakon += harga;
          yakon++;
        } else if (jenis.contains('bakar')) {
          bakar++;
          uang += harga;
          cilembu++;
        } else if (jenis.contains('mentah')) {
          mentah++;
          uang += harga;
          cilembu++;
        }

        // 🔥 HITUNG BERAT UBI (paket ikut dihitung)
        if (jenis.contains('bakar') ||
            jenis.contains('mentah') ||
            jenis.contains('ungu') ||
            jenis.contains('yakon')) {
          kg += berat;
        }

        // 🔥 METODE PEMBAYARAN
        String metode = item['pembayaran'].toString().trim().toLowerCase();

        if (metode == 'cash') {
          cash += harga;
        } else if (metode == 'qris bjb') {
          qrisBjb += harga;
        } else if (metode == 'gopay') {
          gopay += harga;
        } else if (metode == 'shopeepay') {
          shopeepay += harga;
        }
      }

      if (!mounted) return;
      setState(() {
        transaksi = data;

        totalCash = cash;
        totalQrisBJB = qrisBjb;
        totalGoPay = gopay;
        totalShopeePay = shopeepay;

        totalPenjualan = cash + qrisBjb + gopay + shopeepay;

        jumlahTransaksi = json['jumlah_transaksi'];
        totalKg = kg;

        totalKgUngu = kgUngu;
        totalUangUngu = uangUngu;
        totalUngu = ungu;

        totalKgYakon = kgYakon;
        totalUangYakon = uangYakon;
        totalYakon = yakon;

        totalUang = uang;

        totalBakar = bakar;
        totalMentah = mentah;
        totalCilembu = cilembu;

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> ambilPengeluaranHarian(String tanggal) async {
    try {
      final url = "$sheetUrl?type=operasional&tanggal=$tanggal";

      final response = await http.get(Uri.parse(url));

      final json = jsonDecode(response.body);

      setState(() {
        totalPengeluaran = json['total'];

        pengeluaran = List.from(json['data'] ?? []).reversed.toList();
      });
    } catch (e) {
      print("Gagal ambil pengeluaran $e");
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
        isBulanan = false;
        isLoading = true;
      });
      ambilData();
      ambilPengeluaranHarian(tanggalDipilih);
    }
  }

  Future<void> pilihBulan() async {
    DateTime initialDate;

    if (isBulanan) {
      initialDate = DateTime.parse("$bulanDipilih-01");
    } else {
      initialDate = DateTime.now();
    }

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      helpText: "Pilih Bulan",
    );

    if (picked != null) {
      setState(() {
        bulanDipilih = DateFormat('yyyy-MM').format(picked);
        isBulanan = true;
        isLoading = true;
      });
      ambilData();
    }
  }

  String formatRupiah(int angka) {
    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(angka);
  }

  Future<String> generateLaporanWA() async {
    StringBuffer laporan = StringBuffer();

    String tanggalFormat;

    if (isBulanan) {
      DateTime bulan = DateTime.parse("$bulanDipilih-01");
      tanggalFormat = DateFormat('MMMM yyyy', 'id_ID').format(bulan);
    } else {
      DateTime tgl = DateTime.parse(tanggalDipilih);
      tanggalFormat = DateFormat('dd MMM yyyy', 'id_ID').format(tgl);
    }

    await ambilPengeluaranHarian(tanggalDipilih);

    // 🔥 COUNTER JENIS
    int totalBakar = 0;
    int totalMentah = 0;
    int totalUngu = 0;
    int totalYakon = 0;

    laporan.writeln("📌 REPORT SALES");
    laporan.writeln("");
    laporan.writeln("Ubi Kasumba Sawelas Dalung");
    laporan.writeln("Tanggal: $tanggalFormat");
    laporan.writeln("");
    laporan.writeln("━━━━━━━━━━━━━━");
    laporan.writeln("🧾 DETAIL TRANSAKSI");

    for (var item in transaksi) {
      int harga = int.tryParse(item['harga'].toString()) ?? 0;
      String berat = item['berat'].toString();
      String metode = item['pembayaran'].toString();
      String jenis = item['jenis'].toString().toLowerCase();

      if (jenis.contains('ungu')) {
        totalUngu++;
      } else if (jenis.contains('yakon')) {
        totalYakon++;
      } else if (jenis.contains('bakar')) {
        totalBakar++;
      } else if (jenis.contains('mentah')) {
        totalMentah++;
      }

      laporan.writeln(
        "• $jenis - $berat kg  - ${formatRupiah(harga)} ($metode)",
      );
    }
    laporan.writeln("━━━━━━━━━━━━━━");
    laporan.writeln("");
    laporan.writeln("⚖ Total Berat Ubi : ${totalKg.toStringAsFixed(2)} Kg");
    laporan.writeln(
      "🥔 Ubi Cilembu    : ${(totalKg - totalKgUngu - totalKgYakon).toStringAsFixed(2)} Kg",
    );
    laporan.writeln("🍠 Ubi Ungu       : ${totalKgUngu.toStringAsFixed(2)} Kg");
    laporan.writeln(
      "🍠 Ubi Yakon      : ${totalKgYakon.toStringAsFixed(2)} Kg",
    );
    laporan.writeln("");
    laporan.writeln("🛒 Total Transaksi: $jumlahTransaksi");
    laporan.writeln("🔥 Ubi Bakar      : $totalBakar");
    laporan.writeln("🥔 Ubi Mentah     : $totalMentah");
    laporan.writeln("🍠 Ubi Ungu     : $totalUngu");
    laporan.writeln("🍠 Ubi Yakon      : $totalYakon");
    laporan.writeln("");
    laporan.writeln("💳 METODE PEMBAYARAN");

    laporan.writeln("Cash       : ${formatRupiah(totalCash)}");
    laporan.writeln("QRIS BJB   : ${formatRupiah(totalQrisBJB)}");
    laporan.writeln("GoPay      : ${formatRupiah(totalGoPay)}");
    laporan.writeln("ShopeePay  : ${formatRupiah(totalShopeePay)}");

    laporan.writeln("");
    laporan.writeln("━━━━━━━━━━━━━━");
    laporan.writeln("💰 TOTAL OMZET");

    laporan.writeln("🥔 Ubi Cilembu     : ${formatRupiah(totalUang)}");
    laporan.writeln("🍠 Ubi Ungu        : ${formatRupiah(totalUangUngu)}");
    laporan.writeln("🍠 Ubi Yakon       : ${formatRupiah(totalUangYakon)}");
    laporan.writeln("");
    laporan.writeln("💵 TOTAL PENJUALAN : ${formatRupiah(totalPenjualan)}");
    laporan.writeln("━━━━━━━━━━━━━━");
    laporan.writeln("");
    laporan.writeln("💸 LAPORAN PENGELUARAN");
    laporan.writeln("");

    for (var item in pengeluaran) {
      String nama = item['nama_barang'].toString();

      int harga = int.tryParse(item['harga'].toString()) ?? 0;

      laporan.writeln("• $nama - ${formatRupiah(harga)}");
    }

    laporan.writeln("");

    laporan.writeln("Total Pengeluaran : ${formatRupiah(totalPengeluaran)}");
    laporan.writeln("━━━━━━━━━━━━━━");
    laporan.writeln("NOTES:");

    return laporan.toString();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),

      // ============================================================
      // APP BAR
      // ============================================================
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F7F4),
        elevation: 0,
        scrolledUnderElevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Color(0xFF20251F),
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaksi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF20251F),
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Laporan penjualan toko',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        actions: [
          // ========================================================
          // SALDO
          // ========================================================
          Container(
            margin: const EdgeInsets.only(right: 8),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: IconButton(
              tooltip: 'Lihat Saldo',
              icon: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 20,
                color: Color(0xFF20251F),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ViewSaldoDalungPage(),
                  ),
                );
              },
            ),
          ),

          // ========================================================
          // LAPORAN WA (1-Click)
          // ========================================================
          Container(
            margin: const EdgeInsets.only(right: 12),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: IconButton(
              tooltip: 'Kirim Rekap WhatsApp',
              icon: const Icon(
                Icons.chat_rounded,
                size: 20,
                color: Color(0xFF25D366),
              ),
              onPressed: _showLaporanWA,
            ),
          ),
        ],
      ),

      // ============================================================
      // BODY
      // ============================================================
      body: RefreshIndicator(
        color: const Color(0xFFFF8A00),

        onRefresh: () async {
          await cekStatusPetugas();
          await ambilData();
        },

        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF8A00)),
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                children: [
                  // ==================================================
                  // FILTER PERIODE
                  // ==================================================
                  _buildFilterSection(),

                  const SizedBox(height: 20),

                  // ==================================================
                  // TOTAL PENJUALAN
                  // ==================================================
                  _buildTotalCard(),

                  const SizedBox(height: 20),

                  // ==================================================
                  // PEMBAYARAN
                  // ==================================================
                  const Text(
                    'Ringkasan Pembayaran',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF20251F),
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    'Total berdasarkan metode pembayaran',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildPaymentSummaryCard(
                          title: 'Cash',
                          value: totalCash,
                          icon: Icons.payments_outlined,
                          color: const Color(0xFF3D8B55),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: _buildPaymentSummaryCard(
                          title: 'QRIS BJB',
                          value: totalQrisBJB,
                          icon: Icons.qr_code_2_rounded,
                          color: const Color(0xFFFF8A00),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildPaymentSummaryCard(
                          title: 'GoPay',
                          value: totalGoPay,
                          icon: Icons.account_balance_wallet_outlined,
                          color: const Color(0xFF4776E6),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: _buildPaymentSummaryCard(
                          title: 'ShopeePay',
                          value: totalShopeePay,
                          icon: Icons.shopping_bag_outlined,
                          color: const Color(0xFFEE6C4D),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ==================================================
                  // HEADER RIWAYAT
                  // ==================================================
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Riwayat Transaksi',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                color: Color(0xFF20251F),
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Daftar penjualan pada periode ini',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF20251F),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$jumlahTransaksi Data',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // ==================================================
                  // LIST TRANSAKSI
                  // ==================================================
                  if (transaksi.isEmpty)
                    _buildEmptyTransaction()
                  else
                    ...transaksi.map((item) => _buildTransactionItem(item)),
                ],
              ),
      ),
    );
  }

  // ================================================================
  // FILTER PERIODE
  // ================================================================

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.filter_alt_outlined,
                size: 20,
                color: Color(0xFFFF8A00),
              ),
              SizedBox(width: 8),
              Text(
                'Periode Laporan',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ==========================================================
          // HARIAN / BULANAN
          // ==========================================================
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F3F0),
              borderRadius: BorderRadius.circular(14),
            ),

            child: Row(
              children: [
                // ----------------------------------------------------
                // HARIAN
                // ----------------------------------------------------
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (isBulanan) {
                        setState(() {
                          isBulanan = false;
                        });

                        ambilData();
                      }
                    },

                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: !isBulanan ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: !isBulanan
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),

                      child: Center(
                        child: Text(
                          'Harian',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: !isBulanan
                                ? const Color(0xFFFF8A00)
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ----------------------------------------------------
                // BULANAN
                // ----------------------------------------------------
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: pilihBulan,

                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: isBulanan ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: isBulanan
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),

                      child: Center(
                        child: Text(
                          'Bulanan',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isBulanan
                                ? const Color(0xFFFF8A00)
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ==========================================================
          // TANGGAL / BULAN
          // ==========================================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F7F4),
              borderRadius: BorderRadius.circular(15),
            ),

            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8A00).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: Color(0xFFFF8A00),
                    size: 20,
                  ),
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBulanan ? 'Bulan terpilih' : 'Tanggal terpilih',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        isBulanan ? bulanDipilih : tanggalDipilih,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: isBulanan ? pilihBulan : pilihTanggal,

                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF20251F),
                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_calendar_outlined,
                          size: 15,
                          color: Colors.white,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Pilih',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
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
      ),
    );
  }

  // ================================================================
  // TOTAL PENJUALAN
  // ================================================================

  Widget _buildTotalCard() {
    final double totalKgCilembu = totalKg - totalKgUngu - totalKgYakon;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF20251F), Color(0xFF343B32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==========================================================
          // HEADER
          // ==========================================================
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.point_of_sale_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Text(
                  'Total Penjualan',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D8B55).withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'PENJUALAN',
                  style: TextStyle(
                    color: Color(0xFF9FE0AE),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ==========================================================
          // TOTAL
          // ==========================================================
          Text(
            'Rp ${formatRupiah(totalPenjualan)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),

          const SizedBox(height: 18),

          Container(height: 1, color: Colors.white.withValues(alpha: 0.10)),

          const SizedBox(height: 15),

          // ==========================================================
          // JUMLAH TRANSAKSI
          // ==========================================================
          Row(
            children: [
              Expanded(
                child: _buildTotalMiniItem(
                  'Transaksi',
                  '$jumlahTransaksi',
                  isRupiah: false,
                ),
              ),

              Container(
                width: 1,
                height: 35,
                color: Colors.white.withValues(alpha: 0.10),
              ),

              Expanded(
                child: _buildTotalMiniItem(
                  'Ubi Bakar',
                  '$totalBakar',
                  isRupiah: false,
                ),
              ),

              Container(
                width: 1,
                height: 35,
                color: Colors.white.withValues(alpha: 0.10),
              ),

              Expanded(
                child: _buildTotalMiniItem(
                  'Ubi Mentah',
                  '$totalMentah',
                  isRupiah: false,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Container(height: 1, color: Colors.white.withValues(alpha: 0.10)),

          const SizedBox(height: 15),

          // ==========================================================
          // CILEMBU
          // ==========================================================
          _buildProductSummary(
            title: 'Ubi Cilembu',
            count: 'Bakar $totalBakar • Mentah $totalMentah',
            weight: '${totalKgCilembu.toStringAsFixed(2)} Kg',
            omzet: 'Rp ${formatRupiah(totalUang)}',
          ),

          const SizedBox(height: 13),

          // ==========================================================
          // UBI UNGU
          // ==========================================================
          _buildProductSummary(
            title: 'Ubi Ungu',
            count: '$totalUngu transaksi',
            weight: '${totalKgUngu.toStringAsFixed(2)} Kg',
            omzet: 'Rp ${formatRupiah(totalUangUngu)}',
          ),

          const SizedBox(height: 13),

          // ==========================================================
          // UBI YAKON
          // ==========================================================
          _buildProductSummary(
            title: 'Ubi Yakon',
            count: '$totalYakon transaksi',
            weight: '${totalKgYakon.toStringAsFixed(2)} Kg',
            omzet: 'Rp ${formatRupiah(totalUangYakon)}',
          ),
        ],
      ),
    );
  }

  // ================================================================
  // MINI ITEM TOTAL
  // ================================================================

  Widget _buildTotalMiniItem(
    String title,
    String value, {
    bool isRupiah = true,
  }) {
    return Column(
      children: [
        Text(
          isRupiah ? 'Rp $value' : value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // ================================================================
  // PRODUCT SUMMARY
  // ================================================================

  Widget _buildProductSummary({
    required String title,
    required String count,
    required String weight,
    required String omzet,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),

      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFF8A00).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.eco_outlined,
              color: Color(0xFFFFA43A),
              size: 18,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  count,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                weight,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                omzet,
                style: const TextStyle(
                  color: Color(0xFFFFA43A),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================================================================
  // PAYMENT SUMMARY CARD
  // ================================================================

  Widget _buildPaymentSummaryCard({
    required String title,
    required dynamic value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),

          const SizedBox(height: 12),

          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Rp ${formatRupiah(value)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF20251F),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // ITEM TRANSAKSI
  // ================================================================

  Widget _buildTransactionItem(dynamic item) {
    final String jenis = item['jenis']?.toString() ?? '-';

    final String tanggal = item['tanggal']?.toString() ?? '-';

    final String petugas = item['petugas']?.toString() ?? '-';

    final String berat = item['berat']?.toString() ?? '0';

    final String channel = item['channel']?.toString() ?? '-';

    final String pembayaran = item['pembayaran']?.toString() ?? '-';

    final int harga = int.tryParse(item['harga']?.toString() ?? '0') ?? 0;

    String tanggalJam = tanggal;

    try {
      final DateTime parsed = DateTime.parse(tanggal);

      tanggalJam = DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(parsed);
    } catch (_) {
      tanggalJam = tanggal;
    }

    // ==============================================================
    // WARNA BERDASARKAN JENIS
    // ==============================================================
    Color jenisColor = const Color(0xFF3D8B55);

    IconData jenisIcon = Icons.eco_outlined;

    final String jenisLower = jenis.toLowerCase();

    if (jenisLower.contains('ungu')) {
      jenisColor = const Color(0xFF8E5BA6);
      jenisIcon = Icons.spa_outlined;
    } else if (jenisLower.contains('yakon')) {
      jenisColor = const Color(0xFF4776E6);
      jenisIcon = Icons.grass_outlined;
    } else if (jenisLower.contains('bakar')) {
      jenisColor = const Color(0xFFFF7800);
      jenisIcon = Icons.local_fire_department_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==========================================================
          // HEADER TRANSAKSI
          // ==========================================================
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: jenisColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(jenisIcon, color: jenisColor, size: 21),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jenis,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF20251F),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 13,
                          color: Colors.grey.shade500,
                        ),

                        const SizedBox(width: 4),

                        Expanded(
                          child: Text(
                            tanggalJam,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rp ${formatRupiah(harga)}',
                    style: TextStyle(
                      color: jenisColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    'Penjualan',
                    style: TextStyle(color: Colors.grey, fontSize: 9),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          Container(height: 1, color: Colors.grey.shade100),

          const SizedBox(height: 12),

          // ==========================================================
          // DETAIL
          // ==========================================================
          Row(
            children: [
              Expanded(
                child: _buildTransactionDetail(
                  Icons.person_outline,
                  'Petugas',
                  petugas,
                ),
              ),

              Expanded(
                child: _buildTransactionDetail(
                  Icons.scale_outlined,
                  'Berat',
                  '$berat Kg',
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildTransactionDetail(
                  Icons.storefront_outlined,
                  'Channel',
                  channel,
                ),
              ),

              Expanded(
                child: _buildTransactionDetail(
                  Icons.payments_outlined,
                  'Metode',
                  pembayaran,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================================================================
  // DETAIL TRANSAKSI
  // ================================================================

  Widget _buildTransactionDetail(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),

        const SizedBox(width: 6),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 9),
              ),

              const SizedBox(height: 2),

              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF20251F),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================================================================
  // EMPTY TRANSACTION
  // ================================================================

  Widget _buildEmptyTransaction() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 45, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),

      child: Column(
        children: [
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F1EE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 30,
              color: Colors.grey.shade500,
            ),
          ),

          const SizedBox(height: 15),

          const Text(
            'Belum ada transaksi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 5),

          Text(
            'Tidak ada transaksi pada periode ini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // DIALOG LAPORAN WA
  // ================================================================

  void _showLaporanWA() async {
    if (isLoading) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Data masih dimuat...')));
      return;
    }

    if (transaksi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada transaksi untuk dibuat laporan'),
        ),
      );
      return;
    }

    final String text = await generateLaporanWA();

    if (!mounted) return;

    WhatsAppRecapService.showCustomRecapModal(
      context,
      storeName: 'Toko Dalung',
      reportText: text,
    );
  }
}
