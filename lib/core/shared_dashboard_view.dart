import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kasumbasawelas/core/whatsapp_recap_service.dart';
import 'package:kasumbasawelas/settings/pengaturan_harga_page.dart';

enum DashboardFilterMode { hariIni, tujuhHari, bulanIni, custom }

enum DashboardChartMetric { omset, volume, transaksi }

enum DashboardChartPeriod { harian, bulanan }

class SharedDashboardView extends StatefulWidget {
  final String namaToko;
  final String sheetUrl;
  final VoidCallback? onOpenNeraca;
  final VoidCallback? onOpenSaldo;
  final VoidCallback? onOpenTransaksi;
  final VoidCallback? onOpenOperasional;

  const SharedDashboardView({
    super.key,
    required this.namaToko,
    required this.sheetUrl,
    this.onOpenNeraca,
    this.onOpenSaldo,
    this.onOpenTransaksi,
    this.onOpenOperasional,
  });

  @override
  State<SharedDashboardView> createState() => _SharedDashboardViewState();
}

class _SharedDashboardViewState extends State<SharedDashboardView> {
  bool isLoading = true;
  String? errorMessage;

  // Filter state
  DashboardFilterMode filterMode = DashboardFilterMode.bulanIni;
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  // Chart state
  DashboardChartMetric chartMetric = DashboardChartMetric.omset;
  DashboardChartPeriod chartPeriod = DashboardChartPeriod.bulanan;

  // Raw data from Apps Script
  List<dynamic> allSalesData = [];

  // Monthly aggregated data for selectedYear (Months 1..12)
  Map<int, double> monthlyOmset = {};
  Map<int, double> monthlyKg = {};
  Map<int, int> monthlyTrx = {};

  // Daily aggregated data for selectedMonth & selectedYear (Days 1..31)
  Map<int, double> dailyOmset = {};
  Map<int, double> dailyKg = {};
  Map<int, int> dailyTrx = {};

  // Selected Filter Metrics
  int totalPenjualan = 0;
  int jumlahTransaksi = 0;
  double totalKg = 0;
  int aov = 0;
  int avgHarian = 0;
  int hariAktif = 0;

  // Previous Period Metrics for MoM / Growth
  int prevPenjualan = 0;
  int prevTransaksi = 0;
  double prevKg = 0;
  double growthPenjualanPct = 0;

  // Target Omset (stored locally)
  int targetOmset = 40000000;

  // Payment Breakdown
  int totalCash = 0;
  int countCash = 0;
  int totalQrisBJB = 0;
  int countQris = 0;
  int totalGoPay = 0;
  int countGoPay = 0;
  int totalShopeePay = 0;
  int countShopeePay = 0;

  // Product Breakdown
  int totalCilembuMentah = 0;
  double kgCilembuMentah = 0;
  int countCilembuMentah = 0;
  int totalCilembuBakar = 0;
  double kgCilembuBakar = 0;
  int countCilembuBakar = 0;

  int totalUnguMentah = 0;
  double kgUnguMentah = 0;
  int countUnguMentah = 0;
  int totalUnguBakar = 0;
  double kgUnguBakar = 0;
  int countUnguBakar = 0;

  int totalYakon = 0;
  double kgYakon = 0;
  int countYakon = 0;

  // Peak Hours Distribution
  int trxPagi = 0; // 06:00 - 11:59
  int omsetPagi = 0;
  int trxSiang = 0; // 12:00 - 14:59
  int omsetSiang = 0;
  int trxSore = 0; // 15:00 - 17:59
  int omsetSore = 0;
  int trxMalam = 0; // 18:00 - 23:59
  int omsetMalam = 0;

  // Staff / Petugas Leaderboard
  Map<String, _StaffContribution> staffStats = {};

  // Recent 5 Transactions in Current Filter
  List<dynamic> recentTransactions = [];

  // Operasional data for selected month
  bool isLoadingOperasional = false;
  int totalOperasional = 0;

  static const List<String> monthNames = [
    '',
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static const List<String> monthShortNames = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Ags',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  @override
  void initState() {
    super.initState();
    _loadTargetOmset();
    fetchAllData();
  }

  Future<void> _loadTargetOmset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt('target_omset_${widget.namaToko}');
      if (saved != null && saved > 0) {
        if (mounted) setState(() => targetOmset = saved);
      }
    } catch (_) {}
  }

  Future<void> _saveTargetOmset(int newTarget) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('target_omset_${widget.namaToko}', newTarget);
      if (mounted) {
        setState(() => targetOmset = newTarget);
      }
    } catch (_) {}
  }

  String formatRupiah(num value) {
    return NumberFormat('#,###', 'id_ID').format(value.round());
  }

  DateTime? _parseDate(dynamic dateRaw) {
    if (dateRaw == null) return null;
    if (dateRaw is DateTime) return dateRaw;
    final str = dateRaw.toString().trim();
    if (str.isEmpty) return null;

    try {
      return DateTime.parse(str).toLocal();
    } catch (_) {
      try {
        final clean = str.replaceAll('/', '-');
        final datePart = clean.contains(' ')
            ? clean.split(' ')[0]
            : clean.split('T')[0];
        final parts = datePart.split('-');
        if (parts.length == 3) {
          int y = int.parse(parts[0]);
          int m = int.parse(parts[1]);
          int d = int.parse(parts[2]);
          int h = 0, min = 0, sec = 0;
          if (clean.contains(' ')) {
            final timePart = clean.split(' ')[1];
            final tParts = timePart.split(':');
            if (tParts.isNotEmpty) h = int.tryParse(tParts[0]) ?? 0;
            if (tParts.length > 1) min = int.tryParse(tParts[1]) ?? 0;
            if (tParts.length > 2) sec = int.tryParse(tParts[2]) ?? 0;
          }
          return DateTime(y, m, d, h, min, sec);
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> fetchAllData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http
          .get(
            Uri.parse('${widget.sheetUrl}?type=penjualan'),
            headers: {'Cache-Control': 'no-cache'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        allSalesData = List.from(decoded['data'] ?? []);
        _calculateAllMetrics();
        setState(() => isLoading = false);
        _fetchOperasional();
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Gagal memuat data server (${response.statusCode})';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Koneksi terputus. Silakan coba lagi.';
      });
    }
  }

  Future<void> _fetchOperasional() async {
    if (!mounted) return;
    setState(() => isLoadingOperasional = true);

    try {
      final monthStr =
          '$selectedYear-${selectedMonth.toString().padLeft(2, '0')}';
      final url = '${widget.sheetUrl}?type=operasional&bulan=$monthStr';
      final response = await http
          .get(Uri.parse(url), headers: {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            totalOperasional =
                int.tryParse(decoded['total']?.toString() ?? '0') ?? 0;
            isLoadingOperasional = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoadingOperasional = false);
      }
    } catch (_) {
      if (mounted) setState(() => isLoadingOperasional = false);
    }
  }

  bool _isItemInCurrentFilter(DateTime date, DateTime now) {
    switch (filterMode) {
      case DashboardFilterMode.hariIni:
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      case DashboardFilterMode.tujuhHari:
        final start7 = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6));
        final endToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return date.isAfter(start7.subtract(const Duration(seconds: 1))) &&
            date.isBefore(endToday.add(const Duration(seconds: 1)));
      case DashboardFilterMode.bulanIni:
        return date.year == now.year && date.month == now.month;
      case DashboardFilterMode.custom:
        return date.year == selectedYear && date.month == selectedMonth;
    }
  }

  bool _isItemInPreviousFilter(DateTime date, DateTime now) {
    switch (filterMode) {
      case DashboardFilterMode.hariIni:
        final yesterday = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 1));
        return date.year == yesterday.year &&
            date.month == yesterday.month &&
            date.day == yesterday.day;
      case DashboardFilterMode.tujuhHari:
        final startPrev = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 13));
        final endPrev = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 7));
        final endPrevFull = DateTime(
          endPrev.year,
          endPrev.month,
          endPrev.day,
          23,
          59,
          59,
        );
        return date.isAfter(startPrev.subtract(const Duration(seconds: 1))) &&
            date.isBefore(endPrevFull.add(const Duration(seconds: 1)));
      case DashboardFilterMode.bulanIni:
      case DashboardFilterMode.custom:
        final prevM = selectedMonth == 1 ? 12 : selectedMonth - 1;
        final prevY = selectedMonth == 1 ? selectedYear - 1 : selectedYear;
        return date.year == prevY && date.month == prevM;
    }
  }

  void _calculateAllMetrics() {
    final now = DateTime.now();

    // Reset series for selectedYear (Months 1..12)
    final Map<int, double> tempMOmset = {};
    final Map<int, double> tempMKg = {};
    final Map<int, int> tempMTrx = {};
    for (int i = 1; i <= 12; i++) {
      tempMOmset[i] = 0;
      tempMKg[i] = 0;
      tempMTrx[i] = 0;
    }

    // Reset daily series for selectedMonth (Days 1..31)
    final int daysInMonth = DateTime(selectedYear, selectedMonth + 1, 0).day;
    final Map<int, double> tempDOmset = {};
    final Map<int, double> tempDKg = {};
    final Map<int, int> tempDTrx = {};
    for (int i = 1; i <= daysInMonth; i++) {
      tempDOmset[i] = 0;
      tempDKg[i] = 0;
      tempDTrx[i] = 0;
    }

    // Reset filter metrics
    int sales = 0;
    int trx = 0;
    double kg = 0;
    final Set<int> distinctDays = {};

    int pSales = 0;
    int pTrx = 0;
    double pKg = 0;

    int cash = 0, cCash = 0;
    int qris = 0, cQris = 0;
    int gopay = 0, cGopay = 0;
    int shopee = 0, cShopee = 0;

    int cilembuMentah = 0, cCilembuMentah = 0;
    double kgCilMentah = 0;
    int cilembuBakar = 0, cCilembuBakar = 0;
    double kgCilBakar = 0;

    int unguMentah = 0, cUnguMentah = 0;
    double kgUngMentah = 0;
    int unguBakar = 0, cUnguBakar = 0;
    double kgUngBakar = 0;

    int yakon = 0, cYakon = 0;
    double kgYak = 0;

    int pagTrx = 0, pagRp = 0;
    int siaTrx = 0, siaRp = 0;
    int sorTrx = 0, sorRp = 0;
    int malTrx = 0, malRp = 0;

    final Map<String, _StaffContribution> tempStaff = {};
    final List<dynamic> matchedTransactions = [];

    for (var item in allSalesData) {
      final date = _parseDate(item['tanggal']);
      if (date == null) continue;

      final harga = int.tryParse(item['harga']?.toString() ?? '0') ?? 0;
      final berat = double.tryParse(item['berat']?.toString() ?? '0') ?? 0;
      final jenis = (item['jenis'] ?? '').toString().trim().toLowerCase();
      final metode = (item['pembayaran'] ?? '').toString().trim().toLowerCase();
      final rawPetugas = (item['petugas'] ?? '').toString().trim();
      final petugas = rawPetugas.isEmpty ? 'Kasir' : rawPetugas;

      // Aggregations for Year charts
      if (date.year == selectedYear) {
        final m = date.month;
        tempMOmset[m] = (tempMOmset[m] ?? 0) + harga;
        tempMKg[m] = (tempMKg[m] ?? 0) + berat;
        tempMTrx[m] = (tempMTrx[m] ?? 0) + 1;

        if (date.month == selectedMonth) {
          final d = date.day;
          tempDOmset[d] = (tempDOmset[d] ?? 0) + harga;
          tempDKg[d] = (tempDKg[d] ?? 0) + berat;
          tempDTrx[d] = (tempDTrx[d] ?? 0) + 1;
        }
      }

      // Check if item falls in Current Filter
      if (_isItemInCurrentFilter(date, now)) {
        sales += harga;
        kg += berat;
        trx++;
        distinctDays.add(date.day);
        matchedTransactions.add(item);

        // Metode Pembayaran
        if (metode == 'cash') {
          cash += harga;
          cCash++;
        } else if (metode.contains('qris')) {
          qris += harga;
          cQris++;
        } else if (metode.contains('gopay')) {
          gopay += harga;
          cGopay++;
        } else if (metode.contains('shopee')) {
          shopee += harga;
          cShopee++;
        } else {
          cash += harga;
          cCash++;
        }

        // Produk & Varian
        if (jenis.contains('ungu')) {
          if (jenis.contains('mentah')) {
            unguMentah += harga;
            kgUngMentah += berat;
            cUnguMentah++;
          } else {
            unguBakar += harga;
            kgUngBakar += berat;
            cUnguBakar++;
          }
        } else if (jenis.contains('yakon')) {
          yakon += harga;
          kgYak += berat;
          cYakon++;
        } else if (jenis.contains('mentah')) {
          cilembuMentah += harga;
          kgCilMentah += berat;
          cCilembuMentah++;
        } else {
          cilembuBakar += harga;
          kgCilBakar += berat;
          cCilembuBakar++;
        }

        // Peak Hours Distribution
        final hour = date.hour;
        if (hour >= 6 && hour < 12) {
          pagTrx++;
          pagRp += harga;
        } else if (hour >= 12 && hour < 15) {
          siaTrx++;
          siaRp += harga;
        } else if (hour >= 15 && hour < 18) {
          sorTrx++;
          sorRp += harga;
        } else {
          malTrx++;
          malRp += harga;
        }

        // Staff Contribution
        if (!tempStaff.containsKey(petugas)) {
          tempStaff[petugas] = _StaffContribution(name: petugas);
        }
        tempStaff[petugas]!.totalOmset += harga;
        tempStaff[petugas]!.totalTrx += 1;
        tempStaff[petugas]!.totalKg += berat;
      }

      // Check Previous Filter for MoM / Growth
      if (_isItemInPreviousFilter(date, now)) {
        pSales += harga;
        pTrx += 1;
        pKg += berat;
      }
    }

    monthlyOmset = tempMOmset;
    monthlyKg = tempMKg;
    monthlyTrx = tempMTrx;

    dailyOmset = tempDOmset;
    dailyKg = tempDKg;
    dailyTrx = tempDTrx;

    totalPenjualan = sales;
    totalKg = kg;
    jumlahTransaksi = trx;
    hariAktif = distinctDays.length;
    aov = trx > 0 ? (sales / trx).round() : 0;
    avgHarian = distinctDays.isNotEmpty
        ? (sales / distinctDays.length).round()
        : 0;

    prevPenjualan = pSales;
    prevTransaksi = pTrx;
    prevKg = pKg;
    if (pSales > 0) {
      growthPenjualanPct = ((sales - pSales) / pSales) * 100;
    } else {
      growthPenjualanPct = sales > 0 ? 100 : 0;
    }

    totalCash = cash;
    countCash = cCash;
    totalQrisBJB = qris;
    countQris = cQris;
    totalGoPay = gopay;
    countGoPay = cGopay;
    totalShopeePay = shopee;
    countShopeePay = cShopee;

    totalCilembuMentah = cilembuMentah;
    kgCilembuMentah = kgCilMentah;
    countCilembuMentah = cCilembuMentah;
    totalCilembuBakar = cilembuBakar;
    kgCilembuBakar = kgCilBakar;
    countCilembuBakar = cCilembuBakar;

    totalUnguMentah = unguMentah;
    kgUnguMentah = kgUngMentah;
    countUnguMentah = cUnguMentah;
    totalUnguBakar = unguBakar;
    kgUnguBakar = kgUngBakar;
    countUnguBakar = cUnguBakar;

    totalYakon = yakon;
    kgYakon = kgYak;
    countYakon = cYakon;

    trxPagi = pagTrx;
    omsetPagi = pagRp;
    trxSiang = siaTrx;
    omsetSiang = siaRp;
    trxSore = sorTrx;
    omsetSore = sorRp;
    trxMalam = malTrx;
    omsetMalam = malRp;

    staffStats = tempStaff;

    // Sort recent transactions descending
    matchedTransactions.sort((a, b) {
      final da = _parseDate(a['tanggal']) ?? DateTime(2000);
      final db = _parseDate(b['tanggal']) ?? DateTime(2000);
      return db.compareTo(da);
    });
    recentTransactions = matchedTransactions.take(5).toList();
  }

  void _onFilterModeChanged(DashboardFilterMode mode) {
    if (mode == filterMode) return;
    setState(() {
      filterMode = mode;
      if (mode == DashboardFilterMode.bulanIni) {
        selectedMonth = DateTime.now().month;
        selectedYear = DateTime.now().year;
      }
      _calculateAllMetrics();
    });
    _fetchOperasional();
  }

  void _onMonthChanged(int newMonth) {
    if (newMonth == selectedMonth) return;
    setState(() {
      selectedMonth = newMonth;
      filterMode = DashboardFilterMode.custom;
      _calculateAllMetrics();
    });
    _fetchOperasional();
  }

  void _onYearChanged(int newYear) {
    if (newYear == selectedYear) return;
    setState(() {
      selectedYear = newYear;
      filterMode = DashboardFilterMode.custom;
      _calculateAllMetrics();
    });
    _fetchOperasional();
  }

  String _getPeriodTitle() {
    switch (filterMode) {
      case DashboardFilterMode.hariIni:
        final now = DateTime.now();
        return 'Hari Ini, ${DateFormat('d MMMM yyyy', 'id_ID').format(now)}';
      case DashboardFilterMode.tujuhHari:
        return '7 Hari Terakhir';
      case DashboardFilterMode.bulanIni:
        final now = DateTime.now();
        return '${monthNames[now.month]} ${now.year}';
      case DashboardFilterMode.custom:
        return '${monthNames[selectedMonth]} $selectedYear';
    }
  }

  // ==============================================================
  // SHARE REPORT MODAL
  // ==============================================================
  void _showShareReportModal() {
    final data = WhatsAppRecapData(
      namaToko: widget.namaToko,
      periode: _getPeriodTitle(),
      totalPenjualan: totalPenjualan,
      jumlahTransaksi: jumlahTransaksi,
      totalCash: totalCash,
      countCash: countCash,
      totalQrisBJB: totalQrisBJB,
      countQris: countQris,
      totalGoPay: totalGoPay,
      countGoPay: countGoPay,
      totalShopeePay: totalShopeePay,
      countShopeePay: countShopeePay,
      totalKg: totalKg,
      kgCilembuBakar: kgCilembuBakar,
      totalCilembuBakar: totalCilembuBakar,
      kgCilembuMentah: kgCilembuMentah,
      totalCilembuMentah: totalCilembuMentah,
      kgUngu: kgUnguBakar + kgUnguMentah,
      totalUngu: totalUnguBakar + totalUnguMentah,
      kgYakon: kgYakon,
      totalYakon: totalYakon,
      totalPengeluaran: totalOperasional,
    );

    WhatsAppRecapService.showRecapModal(context, data);
  }

  // ==============================================================
  // TARGET OMSET EDIT DIALOG
  // ==============================================================
  void _showEditTargetDialog() {
    final controller = TextEditingController(text: targetOmset.toString());
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8A00).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: Color(0xFFFF8A00),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Target Omset Toko',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF20251F),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tentukan target penjualan bulanan untuk ${widget.namaToko}:',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  prefixStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF20251F),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFFFF8A00),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Batal',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8A00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final val =
                    int.tryParse(
                      controller.text.replaceAll(RegExp(r'[^0-9]'), ''),
                    ) ??
                    0;
                if (val > 0) {
                  _saveTargetOmset(val);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Simpan Target'),
            ),
          ],
        );
      },
    );
  }

  // ==============================================================
  // MONTH & YEAR PICKER MODAL
  // ==============================================================
  void _showMonthYearPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        int tempYear = selectedYear;
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pilih Periode',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF20251F),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F3F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.chevron_left_rounded,
                                size: 20,
                              ),
                              onPressed: () {
                                setModalState(() => tempYear--);
                              },
                            ),
                            Text(
                              '$tempYear',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Color(0xFF20251F),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                              ),
                              onPressed: () {
                                setModalState(() => tempYear++);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final monthIndex = index + 1;
                      final isSelected =
                          monthIndex == selectedMonth &&
                          tempYear == selectedYear;
                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          if (tempYear != selectedYear) {
                            _onYearChanged(tempYear);
                          }
                          _onMonthChanged(monthIndex);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF8A00)
                                : const Color(0xFFF8F7F4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFF8A00)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            monthNames[monthIndex],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF20251F),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==============================================================
  // WIDGET BUILD MAIN
  // ==============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Color(0xFF20251F),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard Bisnis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF20251F),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E7D32),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  widget.namaToko,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Share Report Button
          Container(
            margin: const EdgeInsets.only(right: 8),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: IconButton(
              tooltip: 'Bagikan Laporan (WhatsApp)',
              icon: const Icon(
                Icons.share_outlined,
                size: 19,
                color: Color(0xFF25D366),
              ),
              onPressed: _showShareReportModal,
            ),
          ),

          // Pengaturan Harga Button
          Container(
            margin: const EdgeInsets.only(right: 8),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: IconButton(
              tooltip: 'Pengaturan Harga Ubi',
              icon: const Icon(
                Icons.tune_rounded,
                size: 19,
                color: Color(0xFFFF8A00),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PengaturanHargaPage(),
                  ),
                );
              },
            ),
          ),

          // Refresh Button
          Container(
            margin: const EdgeInsets.only(right: 8),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: IconButton(
              tooltip: 'Muat Ulang',
              icon: const Icon(
                Icons.refresh_rounded,
                size: 20,
                color: Color(0xFF20251F),
              ),
              onPressed: fetchAllData,
            ),
          ),

          // Saldo Shortcut
          if (widget.onOpenSaldo != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: IconButton(
                tooltip: 'Saldo Kasir',
                icon: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 19,
                  color: Color(0xFF20251F),
                ),
                onPressed: widget.onOpenSaldo,
              ),
            ),

          // Neraca Shortcut
          if (widget.onOpenNeraca != null)
            Container(
              margin: const EdgeInsets.only(right: 14),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: IconButton(
                tooltip: 'Neraca Keuangan',
                icon: const Icon(
                  Icons.account_balance_outlined,
                  size: 19,
                  color: Color(0xFF20251F),
                ),
                onPressed: widget.onOpenNeraca,
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFFFF8A00),
        onRefresh: fetchAllData,
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF8A00)),
              )
            : errorMessage != null
            ? _buildErrorState()
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // 1. FILTER PERIODE CEPAT
                  _buildQuickFilterSection(),

                  const SizedBox(height: 16),

                  // 2. HERO REVENUE CARD (Executive Obsidian Theme)
                  _buildHeroRevenueCard(),

                  const SizedBox(height: 14),

                  // 3. TARGET OMSET TOKO & PROGRESS
                  _buildTargetOmsetCard(),

                  const SizedBox(height: 14),

                  // 4. CASH FLOW & PROFIT MARGIN CARD
                  _buildCashFlowCard(),

                  const SizedBox(height: 20),

                  // 5. CHART SECTION (DUAL MODE: HARIAN / BULANAN)
                  _buildInteractiveChartSection(),

                  const SizedBox(height: 20),

                  // 6. JAM RAMAI (PEAK HOURS) & KONTRIBUSI KASIR
                  _buildPeakHoursAndStaffSection(),

                  const SizedBox(height: 20),

                  // 7. METODE PEMBAYARAN DISTRIBUTION
                  _buildPaymentSection(),

                  const SizedBox(height: 20),

                  // 8. PERFORMA PRODUK & VARIAN
                  _buildProductBreakdownSection(),

                  const SizedBox(height: 20),

                  // 9. PRATINJAU TRANSAKSI TERAKHIR
                  _buildRecentTransactionsSection(),

                  const SizedBox(height: 24),

                  // 10. QUICK HUB & NAVIGASI FITUR
                  _buildQuickHubSection(),
                ],
              ),
      ),
    );
  }

  // ==============================================================
  // 1. QUICK FILTER SECTION
  // ==============================================================
  Widget _buildQuickFilterSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: Color(0xFFFF8A00),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getPeriodTitle(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF20251F),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _showMonthYearPicker,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F3F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Pilih Bulan',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF20251F),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 4 Filter Pills
          Row(
            children: [
              _buildFilterPill('Hari Ini', DashboardFilterMode.hariIni),
              const SizedBox(width: 6),
              _buildFilterPill('7 Hari', DashboardFilterMode.tujuhHari),
              const SizedBox(width: 6),
              _buildFilterPill('Bulan Ini', DashboardFilterMode.bulanIni),
              const SizedBox(width: 6),
              _buildFilterPill(
                'Kustom',
                DashboardFilterMode.custom,
                onTap: _showMonthYearPicker,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(
    String label,
    DashboardFilterMode mode, {
    VoidCallback? onTap,
  }) {
    final isSelected = filterMode == mode;
    return Expanded(
      child: InkWell(
        onTap: onTap ?? () => _onFilterModeChanged(mode),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFF8A00)
                : const Color(0xFFF5F6F8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFFFF8A00) : Colors.transparent,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF4A5568),
            ),
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // 2. HERO REVENUE CARD (Executive Theme)
  // ==============================================================
  Widget _buildHeroRevenueCard() {
    final bool isGrowthPositive = growthPenjualanPct >= 0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF14191F), Color(0xFF222933)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14191F).withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL OMSET PENJUALAN',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        _getPeriodTitle(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Growth Indicator Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color:
                      (isGrowthPositive
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444))
                          .withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGrowthPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: isGrowthPositive
                          ? const Color(0xFF34D399)
                          : const Color(0xFFF87171),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isGrowthPositive ? '+' : ''}${growthPenjualanPct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: isGrowthPositive
                            ? const Color(0xFF34D399)
                            : const Color(0xFFF87171),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Main Revenue Number
          Text(
            'Rp ${formatRupiah(totalPenjualan)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),

          const SizedBox(height: 18),

          Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),

          const SizedBox(height: 16),

          // 4 KPI Sub-Items
          Row(
            children: [
              Expanded(
                child: _buildHeroMetricPill(
                  icon: Icons.receipt_long_rounded,
                  label: 'Transaksi',
                  value: '$jumlahTransaksi Trx',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHeroMetricPill(
                  icon: Icons.scale_rounded,
                  label: 'Volume Terjual',
                  value: '${totalKg.toStringAsFixed(1)} Kg',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildHeroMetricPill(
                  icon: Icons.pie_chart_rounded,
                  label: 'Rata-rata Order (AOV)',
                  value: 'Rp ${formatRupiah(aov)}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHeroMetricPill(
                  icon: Icons.calendar_today_rounded,
                  label: 'Rata-rata / Hari',
                  value: 'Rp ${formatRupiah(avgHarian)}',
                  subtitle: '$hariAktif hari aktif',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetricPill({
    required IconData icon,
    required String label,
    required String value,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.50),
                fontSize: 9,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==============================================================
  // 3. TARGET OMSET TOKO CARD
  // ==============================================================
  Widget _buildTargetOmsetCard() {
    final double pct = targetOmset > 0
        ? (totalPenjualan / targetOmset).clamp(0.0, 1.0)
        : 0;
    final int sisaTarget = targetOmset - totalPenjualan;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8A00).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.flag_rounded,
                      size: 18,
                      color: Color(0xFFFF8A00),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Target Penjualan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF20251F),
                        ),
                      ),
                      Text(
                        'Target: Rp ${formatRupiah(targetOmset)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              InkWell(
                onTap: _showEditTargetDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8A00).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        size: 12,
                        color: Color(0xFFFF8A00),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Ubah',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF8A00),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: Colors.grey.shade100,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFF8A00)),
            ),
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(pct * 100).toStringAsFixed(1)}% Tercapai',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFF8A00),
                ),
              ),
              Text(
                sisaTarget > 0
                    ? 'Sisa target: Rp ${formatRupiah(sisaTarget)}'
                    : 'Target Terlampaui! 🎉',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: sisaTarget > 0
                      ? Colors.grey.shade600
                      : const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // 4. CASH FLOW & PROFIT MARGIN CARD
  // ==============================================================
  Widget _buildCashFlowCard() {
    final int kasBersih = totalPenjualan - totalOperasional;
    final bool isPositif = kasBersih >= 0;
    final double marginPct = totalPenjualan > 0
        ? (kasBersih / totalPenjualan) * 100
        : 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 20,
                    color: Color(0xFF2E7D32),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Arus Kas & Operasional',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF20251F),
                    ),
                  ),
                ],
              ),
              if (widget.onOpenNeraca != null)
                InkWell(
                  onTap: widget.onOpenNeraca,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          'Lihat Neraca',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFF8A00),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: Color(0xFFFF8A00),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Flow 2 Column
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Omset Masuk',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rp ${formatRupiah(totalPenjualan)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Beban Operasional',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE53935),
                            ),
                          ),
                          if (isLoadingOperasional) ...[
                            const SizedBox(width: 4),
                            const SizedBox(
                              width: 8,
                              height: 8,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Color(0xFFE53935),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rp ${formatRupiah(totalOperasional)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB71C1C),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Kas Bersih Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estimasi Kas Bersih (Omset - Beban)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rp ${formatRupiah(kasBersih)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isPositif
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFE53935),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isPositif
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFE53935))
                            .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isPositif ? 'SURPLUS' : 'DEFISIT',
                        style: TextStyle(
                          color: isPositif
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFE53935),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${marginPct.toStringAsFixed(0)}%)',
                        style: TextStyle(
                          color: isPositif
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFE53935),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // 5. INTERACTIVE CHART SECTION (DUAL MODE)
  // ==============================================================
  Widget _buildInteractiveChartSection() {
    final bool isHarian = chartPeriod == DashboardChartPeriod.harian;
    final int countItems = isHarian
        ? DateTime(selectedYear, selectedMonth + 1, 0).day
        : 12;

    double highestVal = 0;
    for (int i = 1; i <= countItems; i++) {
      double val = 0;
      if (isHarian) {
        if (chartMetric == DashboardChartMetric.omset) {
          val = dailyOmset[i] ?? 0;
        } else if (chartMetric == DashboardChartMetric.volume) {
          val = dailyKg[i] ?? 0;
        } else {
          val = (dailyTrx[i] ?? 0).toDouble();
        }
      } else {
        if (chartMetric == DashboardChartMetric.omset) {
          val = monthlyOmset[i] ?? 0;
        } else if (chartMetric == DashboardChartMetric.volume) {
          val = monthlyKg[i] ?? 0;
        } else {
          val = (monthlyTrx[i] ?? 0).toDouble();
        }
      }
      if (val > highestVal) highestVal = val;
    }

    final double maxY = highestVal > 0 ? highestVal * 1.25 : 10;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isHarian
                        ? 'Tren Penjualan Harian'
                        : 'Tren Penjualan Tahunan',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF20251F),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isHarian
                        ? 'Grafik harian ${monthNames[selectedMonth]} $selectedYear'
                        : 'Grafik 12 bulan tahun $selectedYear',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F3F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildPeriodToggleTab(
                      'Bulan',
                      DashboardChartPeriod.bulanan,
                    ),
                    _buildPeriodToggleTab('Hari', DashboardChartPeriod.harian),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Segmented Control Metric Toggle
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F3F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildMetricTab('Omset (Rp)', DashboardChartMetric.omset),
                _buildMetricTab('Volume (Kg)', DashboardChartMetric.volume),
                _buildMetricTab('Transaksi', DashboardChartMetric.transaksi),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Bar Chart
          SizedBox(
            height: 210,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF20251F),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      String label = isHarian
                          ? 'Tgl ${group.x}'
                          : monthShortNames[group.x];
                      String valStr = '';
                      if (chartMetric == DashboardChartMetric.omset) {
                        valStr = 'Rp ${formatRupiah(rod.toY)}';
                      } else if (chartMetric == DashboardChartMetric.volume) {
                        valStr = '${rod.toY.toStringAsFixed(1)} Kg';
                      } else {
                        valStr = '${rod.toY.toInt()} Trx';
                      }
                      return BarTooltipItem(
                        '$label\n$valStr',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value == meta.max) {
                          return const SizedBox();
                        }
                        String text = '';
                        if (chartMetric == DashboardChartMetric.omset) {
                          if (value >= 1000000) {
                            text = '${(value / 1000000).toStringAsFixed(0)}jt';
                          } else if (value >= 1000) {
                            text = '${(value / 1000).toInt()}k';
                          } else {
                            text = '${value.toInt()}';
                          }
                        } else if (chartMetric == DashboardChartMetric.volume) {
                          text = '${value.toInt()}kg';
                        } else {
                          text = '${value.toInt()}';
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            text,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (isHarian) {
                          if (idx % 5 != 0 && idx != 1 && idx != countItems) {
                            return const SizedBox();
                          }
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              '$idx',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          );
                        } else {
                          if (idx < 1 || idx > 12) return const SizedBox();
                          final isCur = idx == selectedMonth;
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              monthShortNames[idx],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isCur
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isCur
                                    ? const Color(0xFFFF8A00)
                                    : Colors.grey.shade600,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                barGroups: List.generate(countItems, (index) {
                  final itemIndex = index + 1;
                  double val = 0;
                  if (isHarian) {
                    if (chartMetric == DashboardChartMetric.omset) {
                      val = dailyOmset[itemIndex] ?? 0;
                    } else if (chartMetric == DashboardChartMetric.volume) {
                      val = dailyKg[itemIndex] ?? 0;
                    } else {
                      val = (dailyTrx[itemIndex] ?? 0).toDouble();
                    }
                  } else {
                    if (chartMetric == DashboardChartMetric.omset) {
                      val = monthlyOmset[itemIndex] ?? 0;
                    } else if (chartMetric == DashboardChartMetric.volume) {
                      val = monthlyKg[itemIndex] ?? 0;
                    } else {
                      val = (monthlyTrx[itemIndex] ?? 0).toDouble();
                    }
                  }

                  final bool isHighlight = isHarian
                      ? (itemIndex == DateTime.now().day &&
                            selectedMonth == DateTime.now().month &&
                            selectedYear == DateTime.now().year)
                      : (itemIndex == selectedMonth);

                  return BarChartGroupData(
                    x: itemIndex,
                    barRods: [
                      BarChartRodData(
                        toY: val,
                        width: isHarian ? (countItems > 28 ? 6 : 8) : 14,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        color: isHighlight
                            ? const Color(0xFFFF8A00)
                            : const Color(0xFF20251F).withValues(alpha: 0.22),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodToggleTab(String label, DashboardChartPeriod period) {
    final isSelected = chartPeriod == period;
    return GestureDetector(
      onTap: () => setState(() => chartPeriod = period),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFFFF8A00) : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTab(String label, DashboardChartMetric metric) {
    final isSelected = chartMetric == metric;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => chartMetric = metric),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFFFF8A00)
                    : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // 6. JAM RAMAI (PEAK HOURS) & KONTRIBUSI KASIR
  // ==============================================================
  Widget _buildPeakHoursAndStaffSection() {
    final slots = [
      {
        'name': 'Pagi (06-12)',
        'trx': trxPagi,
        'rp': omsetPagi,
        'icon': Icons.wb_sunny_outlined,
      },
      {
        'name': 'Siang (12-15)',
        'trx': trxSiang,
        'rp': omsetSiang,
        'icon': Icons.light_mode_outlined,
      },
      {
        'name': 'Sore (15-18)',
        'trx': trxSore,
        'rp': omsetSore,
        'icon': Icons.wb_twilight_rounded,
      },
      {
        'name': 'Malam (18-24)',
        'trx': trxMalam,
        'rp': omsetMalam,
        'icon': Icons.nightlight_round,
      },
    ];

    int maxTrxSlot = 0;
    int maxTrxIdx = 0;
    for (int i = 0; i < slots.length; i++) {
      if ((slots[i]['trx'] as int) > maxTrxSlot) {
        maxTrxSlot = slots[i]['trx'] as int;
        maxTrxIdx = i;
      }
    }

    final sortedStaff = staffStats.values.toList()
      ..sort((a, b) => b.totalOmset.compareTo(a.totalOmset));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Peak Hours Container
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 19,
                        color: Color(0xFFFF8A00),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Waktu Transaksi Ramai',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF20251F),
                        ),
                      ),
                    ],
                  ),
                  if (maxTrxSlot > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8A00).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Puncak: ${slots[maxTrxIdx]['name']!.toString().split(' ')[0]} 🔥',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF8A00),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: slots.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final isPeak = idx == maxTrxIdx && maxTrxSlot > 0;
                  final trxCount = item['trx'] as int;

                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: idx < 3 ? 6 : 0),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isPeak
                            ? const Color(0xFFFF8A00).withValues(alpha: 0.08)
                            : const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPeak
                              ? const Color(0xFFFF8A00).withValues(alpha: 0.35)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            item['icon'] as IconData,
                            size: 18,
                            color: isPeak
                                ? const Color(0xFFFF8A00)
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['name']!.toString().split(' ')[0],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isPeak
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isPeak
                                  ? const Color(0xFFFF8A00)
                                  : const Color(0xFF20251F),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$trxCount Trx',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF20251F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        if (sortedStaff.isNotEmpty) ...[
          const SizedBox(height: 14),
          // Leaderboard Kasir Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 19,
                      color: Color(0xFF2474E5),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Kontribusi Staf / Kasir',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF20251F),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  children: sortedStaff.take(4).map((st) {
                    final double pct = totalPenjualan > 0
                        ? (st.totalOmset / totalPenjualan) * 100
                        : 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(
                              0xFF2474E5,
                            ).withValues(alpha: 0.12),
                            child: Text(
                              st.name.isNotEmpty
                                  ? st.name[0].toUpperCase()
                                  : 'K',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2474E5),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  st.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF20251F),
                                  ),
                                ),
                                Text(
                                  '${st.totalTrx} transaksi • ${st.totalKg.toStringAsFixed(1)} Kg',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Rp ${formatRupiah(st.totalOmset)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF20251F),
                                ),
                              ),
                              Text(
                                '${pct.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2474E5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ==============================================================
  // 7. PAYMENT METHOD DISTRIBUTION
  // ==============================================================
  Widget _buildPaymentSection() {
    final int totalDigital = totalQrisBJB + totalGoPay + totalShopeePay;
    final double digitalPct = totalPenjualan > 0
        ? (totalDigital / totalPenjualan) * 100
        : 0;
    final double cashPct = totalPenjualan > 0
        ? (totalCash / totalPenjualan) * 100
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Metode Pembayaran',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF20251F),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Penerimaan kas tunai vs non-tunai (digital)',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),

        // Visual Ratio Bar
        if (totalPenjualan > 0) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.money_rounded,
                          size: 15,
                          color: Color(0xFF2E7D32),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Tunai: ${cashPct.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.qr_code_2_rounded,
                          size: 15,
                          color: Color(0xFFFF8A00),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Digital: ${digitalPct.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFF8A00),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: (cashPct * 10).round().clamp(1, 1000),
                        child: Container(
                          height: 8,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        flex: (digitalPct * 10).round().clamp(1, 1000),
                        child: Container(
                          height: 8,
                          color: const Color(0xFFFF8A00),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 4 Payment Cards
        Row(
          children: [
            Expanded(
              child: _buildPaymentCard(
                title: 'Cash',
                value: totalCash,
                count: countCash,
                icon: Icons.payments_outlined,
                color: const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildPaymentCard(
                title: 'QRIS BJB',
                value: totalQrisBJB,
                count: countQris,
                icon: Icons.qr_code_2_rounded,
                color: const Color(0xFFFF8A00),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildPaymentCard(
                title: 'GoPay',
                value: totalGoPay,
                count: countGoPay,
                icon: Icons.account_balance_wallet_outlined,
                color: const Color(0xFF2474E5),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildPaymentCard(
                title: 'ShopeePay',
                value: totalShopeePay,
                count: countShopeePay,
                icon: Icons.shopping_bag_outlined,
                color: const Color(0xFFEE6C4D),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentCard({
    required String title,
    required int value,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    final double pct = totalPenjualan > 0 ? (value / totalPenjualan) * 100 : 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF20251F),
                      ),
                    ),
                    Text(
                      '$count transaksi',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Rp ${formatRupiah(value)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF20251F),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${pct.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // 8. PRODUCT & VARIANT BREAKDOWN
  // ==============================================================
  Widget _buildProductBreakdownSection() {
    final int totalCilembu = totalCilembuMentah + totalCilembuBakar;
    final double kgCilembu = kgCilembuMentah + kgCilembuBakar;

    final int totalUngu = totalUnguMentah + totalUnguBakar;
    final double kgUngu = kgUnguMentah + kgUnguBakar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performa Produk & Varian',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF20251F),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Kontribusi penjualan ubi cilembu, ungu, dan yakon',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildProductCategoryItem(
                title: 'Ubi Cilembu',
                subtitle: 'Varian Unggulan Kasumba',
                icon: Icons.eco_rounded,
                accentColor: const Color(0xFFFF8A00),
                totalRp: totalCilembu,
                totalKg: kgCilembu,
                subItems: [
                  ProductSubItem(
                    label: 'Bakar',
                    rp: totalCilembuBakar,
                    kg: kgCilembuBakar,
                    count: countCilembuBakar,
                  ),
                  ProductSubItem(
                    label: 'Mentah',
                    rp: totalCilembuMentah,
                    kg: kgCilembuMentah,
                    count: countCilembuMentah,
                  ),
                ],
              ),

              const Divider(height: 26),

              _buildProductCategoryItem(
                title: 'Ubi Ungu',
                subtitle: 'Varian Manis Ubi Ungu',
                icon: Icons.eco_outlined,
                accentColor: const Color(0xFF7E57C2),
                totalRp: totalUngu,
                totalKg: kgUngu,
                subItems: [
                  ProductSubItem(
                    label: 'Bakar',
                    rp: totalUnguBakar,
                    kg: kgUnguBakar,
                    count: countUnguBakar,
                  ),
                  ProductSubItem(
                    label: 'Mentah',
                    rp: totalUnguMentah,
                    kg: kgUnguMentah,
                    count: countUnguMentah,
                  ),
                ],
              ),

              const Divider(height: 26),

              _buildProductCategoryItem(
                title: 'Ubi Yakon',
                subtitle: 'Varian Herbal Yakon',
                icon: Icons.spa_outlined,
                accentColor: const Color(0xFFE67E22),
                totalRp: totalYakon,
                totalKg: kgYakon,
                subItems: [
                  ProductSubItem(
                    label: 'Penjualan',
                    rp: totalYakon,
                    kg: kgYakon,
                    count: countYakon,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductCategoryItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required int totalRp,
    required double totalKg,
    required List<ProductSubItem> subItems,
  }) {
    final double pct = totalPenjualan > 0
        ? (totalRp / totalPenjualan) * 100
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF20251F),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rp ${formatRupiah(totalRp)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF20251F),
                  ),
                ),
                Text(
                  '${totalKg.toStringAsFixed(1)} Kg',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: subItems.map((item) {
              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF20251F),
                            ),
                          ),
                          Text(
                            'Rp ${formatRupiah(item.rp)} • ${item.kg.toStringAsFixed(1)} Kg',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ==============================================================
  // 9. RECENT TRANSACTIONS PREVIEW
  // ==============================================================
  Widget _buildRecentTransactionsSection() {
    if (recentTransactions.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Transaksi Terakhir',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF20251F),
                letterSpacing: -0.4,
              ),
            ),
            if (widget.onOpenTransaksi != null)
              InkWell(
                onTap: widget.onOpenTransaksi,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'Lihat Semua',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF8A00),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: Color(0xFFFF8A00),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentTransactions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = recentTransactions[index];
              final date = _parseDate(item['tanggal']);
              final harga = int.tryParse(item['harga']?.toString() ?? '0') ?? 0;
              final berat =
                  double.tryParse(item['berat']?.toString() ?? '0') ?? 0;
              final jenis = (item['jenis'] ?? '-').toString();
              final metode = (item['pembayaran'] ?? '-').toString();
              final isCash = metode.toLowerCase() == 'cash';

              String timeStr = '-';
              if (date != null) {
                timeStr = DateFormat('dd MMM, HH:mm').format(date);
              }

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            (isCash
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFFF8A00))
                                .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isCash ? Icons.money_rounded : Icons.qr_code_rounded,
                        size: 16,
                        color: isCash
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFFF8A00),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            jenis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF20251F),
                            ),
                          ),
                          Text(
                            '$timeStr • ${berat.toStringAsFixed(1)} Kg • $metode',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Rp ${formatRupiah(harga)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF20251F),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==============================================================
  // 10. QUICK HUB & NAVIGASI FITUR
  // ==============================================================
  Widget _buildQuickHubSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Navigasi Cepat',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF20251F),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Akses fitur manajemen, kasir & pembukuan toko',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            if (widget.onOpenTransaksi != null)
              Expanded(
                child: _buildQuickActionCard(
                  title: 'Transaksi',
                  subtitle: 'Riwayat Penjualan',
                  icon: Icons.receipt_long_rounded,
                  color: const Color(0xFFFF8A00),
                  onTap: widget.onOpenTransaksi!,
                ),
              ),
            if (widget.onOpenTransaksi != null &&
                widget.onOpenOperasional != null)
              const SizedBox(width: 10),
            if (widget.onOpenOperasional != null)
              Expanded(
                child: _buildQuickActionCard(
                  title: 'Operasional',
                  subtitle: 'Catatan Pengeluaran',
                  icon: Icons.assignment_outlined,
                  color: const Color(0xFFE53935),
                  onTap: widget.onOpenOperasional!,
                ),
              ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            if (widget.onOpenSaldo != null)
              Expanded(
                child: _buildQuickActionCard(
                  title: 'Saldo Kas',
                  subtitle: 'Tarik / Cek Saldo',
                  icon: Icons.account_balance_wallet_outlined,
                  color: const Color(0xFF2E7D32),
                  onTap: widget.onOpenSaldo!,
                ),
              ),
            if (widget.onOpenSaldo != null && widget.onOpenNeraca != null)
              const SizedBox(width: 10),
            if (widget.onOpenNeraca != null)
              Expanded(
                child: _buildQuickActionCard(
                  title: 'Neraca Toko',
                  subtitle: 'Aset & Laba Rugi',
                  icon: Icons.account_balance_outlined,
                  color: const Color(0xFF2474E5),
                  onTap: widget.onOpenNeraca!,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF20251F),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // ERROR STATE
  // ==============================================================
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 30,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Gagal Memuat Dashboard',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF20251F),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              errorMessage ?? 'Terjadi kesalahan saat memproses data.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: fetchAllData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8A00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Coba Lagi',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductSubItem {
  final String label;
  final int rp;
  final double kg;
  final int count;

  ProductSubItem({
    required this.label,
    required this.rp,
    required this.kg,
    required this.count,
  });
}

class _StaffContribution {
  final String name;
  int totalOmset = 0;
  int totalTrx = 0;
  double totalKg = 0;

  _StaffContribution({required this.name});
}
