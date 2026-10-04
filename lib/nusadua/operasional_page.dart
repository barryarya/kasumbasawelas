import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class OperasionalNusaDuaPage extends StatefulWidget {
  const OperasionalNusaDuaPage({super.key});

  @override
  State<OperasionalNusaDuaPage> createState() => _OperasionalNusaDuaPageState();
}

class _OperasionalNusaDuaPageState extends State<OperasionalNusaDuaPage> {
  final String sheetUrl =
      'https://script.google.com/macros/s/AKfycbzanDpa7SX5AUxUQVhHnELeMlmTYG_WGr1U7jLD9csiOmz68vQNGbK7Xh6UT3VHgqmL0Q/exec';

  List operasional = [];
  bool isLoading = true;
  int totalInventaris = 0;
  int totalBiayaOperasional = 0;
  int totalPengeluaran = 0;
  int jumlahData = 0;

  String tanggalDipilih = DateFormat('yyyy-MM-dd').format(DateTime.now());
  bool isBulanan = false;
  String bulanDipilih = DateFormat('yyyy-MM').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    ambilData();
  }

  Future<void> ambilData() async {
    try {
      String url;

      if (isBulanan) {
        url = '$sheetUrl?type=operasional&bulan=$bulanDipilih';
      } else {
        url = '$sheetUrl?type=operasional&tanggal=$tanggalDipilih';
      }

      final response = await http.get(Uri.parse(url));
      final json = jsonDecode(response.body);

      setState(() {
        operasional = List.from(json['data'].reversed);
        jumlahData = json['jumlah_data'];
        totalPengeluaran = json['total'];

        totalInventaris = 0;
        totalBiayaOperasional = 0;

        for (var item in operasional) {
          String nama = item['nama_barang'].toString();
          int harga = int.tryParse(item['harga'].toString()) ?? 0;
          String sumber = (item['sumber'] ?? '').toString().toUpperCase();

          if (sumber == 'CASH' || nama.contains('*')) {
            totalBiayaOperasional += harga;
          } else {
            totalInventaris += harga;
          }
        }

        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
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

  Future<void> pilihBulan() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse("$bulanDipilih-01"),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      helpText: 'Pilih Bulan',
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

  String generateLaporanOperasionalWA() {
    StringBuffer laporan = StringBuffer();

    String tanggalFormat;

    if (isBulanan) {
      DateTime bulan = DateTime.parse("$bulanDipilih-01");
      tanggalFormat = DateFormat('MMMM yyyy', 'id_ID').format(bulan);
    } else {
      DateTime tgl = DateTime.parse(tanggalDipilih);
      tanggalFormat = DateFormat('dd MMM yyyy', 'id_ID').format(tgl);
    }

    laporan.writeln("📌 REPORT OPERASIONAL");
    laporan.writeln("");
    laporan.writeln("Ubi Kasumba Sawelas Nusa Dua");
    laporan.writeln("Periode: $tanggalFormat");
    laporan.writeln("");
    laporan.writeln("━━━━━━━━━━━━━━");
    laporan.writeln("");

    int totalInventaris = 0;
    int totalBiayaOperasional = 0;
    int jumlahData = operasional.length;

    /// ================= INVENTARIS =================
    laporan.writeln("📦 INVENTARIS");
    laporan.writeln("");

    for (var item in operasional) {
      String nama = item['nama_barang'].toString();
      int harga = int.tryParse(item['harga'].toString()) ?? 0;
      String tanggal = item['tanggal'].toString();
      String sumber = (item['sumber'] ?? '').toString().toUpperCase();
      bool isCash = sumber == 'CASH' || nama.contains('*');

      if (!isCash) {
        totalInventaris += harga;

        laporan.writeln("• $nama");
        laporan.writeln("  Rp ${formatRupiah(harga)}");
        laporan.writeln("  ($tanggal)");
        laporan.writeln("");
      }
    }

    laporan.writeln("Total Inventaris: Rp ${formatRupiah(totalInventaris)}");
    laporan.writeln("");
    laporan.writeln("━━━━━━━━━━━━━━");
    laporan.writeln("");

    /// ================= BIAYA OPERASIONAL =================
    laporan.writeln("💰 BIAYA OPERASIONAL (DARI UANG PENJUALAN)");
    laporan.writeln("");

    for (var item in operasional) {
      String nama = item['nama_barang'].toString();
      int harga = int.tryParse(item['harga'].toString()) ?? 0;
      String tanggal = item['tanggal'].toString();
      String sumber = (item['sumber'] ?? '').toString().toUpperCase();
      bool isCash = sumber == 'CASH' || nama.contains('*');

      if (isCash) {
        totalBiayaOperasional += harga;

        laporan.writeln("• $nama");
        laporan.writeln("  Rp ${formatRupiah(harga)}");
        laporan.writeln("  ($tanggal)");
        laporan.writeln("");
      }
    }

    laporan.writeln(
      "Total Biaya Operasional: Rp ${formatRupiah(totalBiayaOperasional)}",
    );
    laporan.writeln("");
    laporan.writeln("━━━━━━━━━━━━━━");
    laporan.writeln("");

    /// ================= RINGKASAN =================
    laporan.writeln("📊 RINGKASAN");
    laporan.writeln("Jumlah Data : $jumlahData");
    laporan.writeln(
      "Total Pengeluaran : Rp ${formatRupiah(totalInventaris + totalBiayaOperasional)}",
    );
    laporan.writeln("━━━━━━━━━━━━━━");

    return laporan.toString();
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
              'Operasional',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF20251F),
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Laporan pengeluaran toko',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Color(0xFFE8E7E3)),
            ),
            child: IconButton(
              tooltip: 'Generate Laporan WA',
              icon: const Icon(
                Icons.description_outlined,
                size: 21,
                color: Color(0xFF20251F),
              ),
              onPressed: _showLaporanOperasional,
            ),
          ),
        ],
      ),

      // ============================================================
      // BODY
      // ============================================================
      body: RefreshIndicator(
        color: const Color(0xFFFF8A00),
        onRefresh: ambilData,

        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF8A00)),
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                children: [
                  // ==================================================
                  // FILTER
                  // ==================================================
                  _buildFilterSection(),

                  const SizedBox(height: 20),

                  // ==================================================
                  // TOTAL PENGELUARAN
                  // ==================================================
                  _buildTotalCard(),

                  const SizedBox(height: 24),

                  // ==================================================
                  // SUMMARY
                  // ==================================================
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          icon: Icons.inventory_2_outlined,
                          title: 'Inventaris',
                          value: 'Rp ${formatRupiah(totalInventaris)}',
                          color: const Color(0xFF3D8B55),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: _buildSummaryCard(
                          icon: Icons.payments_outlined,
                          title: 'Operasional',
                          value: 'Rp ${formatRupiah(totalBiayaOperasional)}',
                          color: const Color(0xFFFF8A00),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Riwayat Pengeluaran',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                color: Color(0xFF20251F),
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Daftar transaksi operasional',
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
                          '$jumlahData Data',
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
                  // DATA
                  // ==================================================
                  if (operasional.isEmpty)
                    _buildEmptyState()
                  else
                    ...operasional.map((item) => _buildOperationalItem(item)),
                ],
              ),
      ),
    );
  }

  // ================================================================
  // LAPORAN OPERASIONAL
  // ================================================================

  void _showLaporanOperasional() {
    if (isLoading) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Data masih dimuat...')));
      return;
    }

    if (operasional.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada data operasional untuk dibuat laporan'),
        ),
      );
      return;
    }

    final String text = generateLaporanOperasionalWA();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Laporan WA Operasional'),

          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(child: SelectableText(text)),
          ),

          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));

                if (!mounted) return;

                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Laporan berhasil disalin ✅')),
                );
              },
              child: const Text('Copy'),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  // ================================================================
  // FILTER SECTION
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
          // TANGGAL
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
  // TOTAL CARD
  // ================================================================

  Widget _buildTotalCard() {
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
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Text(
                  'Total Pengeluaran',
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
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'PENGELUARAN',
                  style: TextStyle(
                    color: Color(0xFFFF9B9B),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            'Rp ${formatRupiah(totalPengeluaran)}',
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

          Row(
            children: [
              Expanded(
                child: _buildTotalMiniItem('Inventaris', totalInventaris),
              ),

              Container(
                width: 1,
                height: 35,
                color: Colors.white.withValues(alpha: 0.10),
              ),

              Expanded(
                child: _buildTotalMiniItem(
                  'Operasional (*)',
                  totalBiayaOperasional,
                ),
              ),

              Container(
                width: 1,
                height: 35,
                color: Colors.white.withValues(alpha: 0.10),
              ),

              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$jumlahData',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      'Data',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalMiniItem(String title, dynamic value) {
    return Column(
      children: [
        Text(
          'Rp ${formatRupiah(value)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
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
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ================================================================
  // SUMMARY CARD
  // ================================================================

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
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
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // OPERATIONAL ITEM
  // ================================================================

  Widget _buildOperationalItem(dynamic item) {
    final String nama = item['nama_barang']?.toString() ?? '-';

    final String tanggal = item['tanggal']?.toString() ?? '-';

    final String sumber = (item['sumber'] ?? '').toString().toUpperCase();
    final bool dariUangPenjualan = sumber == 'CASH' || nama.contains('*');

    final int harga = int.tryParse(item['harga']?.toString() ?? '0') ?? 0;

    final Color warnaIcon = dariUangPenjualan
        ? const Color(0xFFFF8A00)
        : const Color(0xFF3D8B55);

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

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ==========================================================
          // ICON
          // ==========================================================
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: warnaIcon.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              dariUangPenjualan
                  ? Icons.payments_outlined
                  : Icons.inventory_2_outlined,
              color: warnaIcon,
              size: 21,
            ),
          ),

          const SizedBox(width: 13),

          // ==========================================================
          // DETAIL
          // ==========================================================
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        nama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    if (dariUangPenjualan)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFFF8A00,
                          ).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Uang Penjualan',
                          style: TextStyle(
                            color: Color(0xFFFF7800),
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
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
                        tanggal,
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

          // ==========================================================
          // HARGA
          // ==========================================================
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rp ${formatRupiah(harga)}',
                style: TextStyle(
                  color: dariUangPenjualan
                      ? const Color(0xFFFF7800)
                      : const Color(0xFF20251F),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'Pengeluaran',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================================================================
  // EMPTY STATE
  // ================================================================

  Widget _buildEmptyState() {
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
            'Belum ada data',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 5),

          Text(
            'Tidak ada pengeluaran pada periode ini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
