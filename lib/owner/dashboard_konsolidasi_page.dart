import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:kasumbasawelas/core/store_registry.dart';
import 'package:kasumbasawelas/core/whatsapp_recap_service.dart';
import 'package:kasumbasawelas/core/shared_dashboard_view.dart';
import 'package:kasumbasawelas/settings/kelola_akses_petugas_page.dart';
import 'package:kasumbasawelas/settings/pengaturan_harga_page.dart';

enum ConsolidationFilter { hariIni, tujuhHari, bulanIni, custom }

class _BranchMetric {
  final StoreInfo store;
  int omset = 0;
  int transaksi = 0;
  double volumeKg = 0;
  int cash = 0;
  int countCash = 0;
  int digital = 0;
  int countDigital = 0;
  int operasional = 0;
  bool isError = false;

  _BranchMetric({required this.store});

  int get kasBersih => omset - operasional;
}

class DashboardKonsolidasiPage extends StatefulWidget {
  const DashboardKonsolidasiPage({super.key});

  @override
  State<DashboardKonsolidasiPage> createState() =>
      _DashboardKonsolidasiPageState();
}

class _DashboardKonsolidasiPageState extends State<DashboardKonsolidasiPage> {
  ConsolidationFilter _filter = ConsolidationFilter.hariIni;
  final DateTime _selectedDate = DateTime.now();
  final int _selectedMonth = DateTime.now().month;
  final int _selectedYear = DateTime.now().year;

  bool _isLoading = true;
  final Map<String, _BranchMetric> _branchMetrics = {};

  // Grand Totals
  int _grandOmset = 0;
  int _grandTransaksi = 0;
  double _grandKg = 0;
  int _grandCash = 0;
  int _grandDigital = 0;
  int _grandOperasional = 0;

  @override
  void initState() {
    super.initState();
    _loadAllBranchData();
  }

  String _formatRupiah(num val) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    ).format(val).trim();
  }

  String _getPeriodLabel() {
    switch (_filter) {
      case ConsolidationFilter.hariIni:
        return 'Hari Ini (${DateFormat('dd MMM yyyy', 'id_ID').format(_selectedDate)})';
      case ConsolidationFilter.tujuhHari:
        return '7 Hari Terakhir';
      case ConsolidationFilter.bulanIni:
        return DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now());
      case ConsolidationFilter.custom:
        return '${DateFormat('MMMM', 'id_ID').format(DateTime(_selectedYear, _selectedMonth))} $_selectedYear';
    }
  }

  Future<void> _loadAllBranchData() async {
    setState(() => _isLoading = true);

    final Map<String, _BranchMetric> metrics = {};
    for (var store in StoreRegistry.allStores) {
      metrics[store.id] = _BranchMetric(store: store);
    }

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final monthStr = _filter == ConsolidationFilter.custom
        ? '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}'
        : DateFormat('yyyy-MM').format(now);

    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    // Parallel fetch from all 4 branches simultaneously
    await Future.wait(
      StoreRegistry.allStores.map((store) async {
        final metric = metrics[store.id]!;
        try {
          // 1. Fetch Sales Data
          final salesUrl = Uri.parse('${store.sheetUrl}?type=penjualan');
          final salesResp = await http
              .get(salesUrl)
              .timeout(const Duration(seconds: 15));

          if (salesResp.statusCode == 200) {
            final salesBody = jsonDecode(salesResp.body);
            final List<dynamic> rawData =
                (salesBody is Map && salesBody.containsKey('data'))
                ? salesBody['data']
                : (salesBody is List ? salesBody : []);

            for (var item in rawData) {
              final tglStr = item['tanggal']?.toString() ?? '';
              DateTime? itemDate;
              try {
                itemDate = DateTime.tryParse(tglStr);
              } catch (_) {}

              // Filter check
              bool match = false;
              if (_filter == ConsolidationFilter.hariIni) {
                match = tglStr.startsWith(todayStr);
              } else if (_filter == ConsolidationFilter.tujuhHari) {
                if (itemDate != null && itemDate.isAfter(sevenDaysAgo)) {
                  match = true;
                }
              } else if (_filter == ConsolidationFilter.bulanIni ||
                  _filter == ConsolidationFilter.custom) {
                match = tglStr.startsWith(monthStr);
              }

              if (!match) continue;

              final int harga =
                  int.tryParse(item['harga']?.toString() ?? '0') ?? 0;
              final String metode =
                  item['pembayaran']?.toString().toLowerCase() ?? '';
              final double berat =
                  double.tryParse(
                    item['berat']?.toString().replaceAll(',', '.') ?? '0',
                  ) ??
                  0;

              metric.omset += harga;
              metric.transaksi += 1;
              metric.volumeKg += berat;

              if (metode.contains('cash') || metode.contains('tunai')) {
                metric.cash += harga;
                metric.countCash += 1;
              } else {
                metric.digital += harga;
                metric.countDigital += 1;
              }
            }
          }

          // 2. Fetch Operational Expenses
          final opsUrl = Uri.parse(
            '${store.sheetUrl}?type=operasional&bulan=$monthStr',
          );
          final opsResp = await http
              .get(opsUrl)
              .timeout(const Duration(seconds: 15));
          if (opsResp.statusCode == 200) {
            final opsBody = jsonDecode(opsResp.body);
            if (opsBody is Map && opsBody.containsKey('data')) {
              final List<dynamic> opsData = opsBody['data'];
              for (var op in opsData) {
                final opTgl = op['tanggal']?.toString() ?? '';
                bool matchOp = false;
                if (_filter == ConsolidationFilter.hariIni) {
                  matchOp = opTgl.startsWith(todayStr);
                } else if (_filter == ConsolidationFilter.tujuhHari) {
                  final d = DateTime.tryParse(opTgl);
                  if (d != null && d.isAfter(sevenDaysAgo)) matchOp = true;
                } else {
                  matchOp = opTgl.startsWith(monthStr);
                }

                if (matchOp) {
                  final int h =
                      int.tryParse(op['harga']?.toString() ?? '0') ?? 0;
                  metric.operasional += h;
                }
              }
            } else if (opsBody is Map &&
                opsBody.containsKey('total') &&
                _filter == ConsolidationFilter.bulanIni) {
              metric.operasional =
                  int.tryParse(opsBody['total']?.toString() ?? '0') ?? 0;
            }
          }
        } catch (e) {
          metric.isError = true;
        }
      }),
    );

    // Compute grand totals
    int gOmset = 0;
    int gTrx = 0;
    double gKg = 0;
    int gCash = 0;
    int gDigital = 0;
    int gOps = 0;

    for (var m in metrics.values) {
      gOmset += m.omset;
      gTrx += m.transaksi;
      gKg += m.volumeKg;
      gCash += m.cash;
      gDigital += m.digital;
      gOps += m.operasional;
    }

    if (mounted) {
      setState(() {
        _branchMetrics.clear();
        _branchMetrics.addAll(metrics);
        _grandOmset = gOmset;
        _grandTransaksi = gTrx;
        _grandKg = gKg;
        _grandCash = gCash;
        _grandDigital = gDigital;
        _grandOperasional = gOps;
        _isLoading = false;
      });
    }
  }

  void _shareConsolidatedRecap() {
    final buffer = StringBuffer();
    buffer.writeln('📊 *REKAP KONSOLIDASI SEMUA CABANG* 📊');
    buffer.writeln('🏪 *Kasumba Sawelas Group*');
    buffer.writeln('📅 *Periode:* ${_getPeriodLabel()}');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln(
      '💰 *TOTAL OMSET GABUNGAN:* Rp ${_formatRupiah(_grandOmset)}',
    );
    buffer.writeln('🧾 *Total Transaksi:* $_grandTransaksi Struk');
    if (_grandKg > 0) {
      buffer.writeln(
        '📦 *Total Volume Terjual:* ${_grandKg.toStringAsFixed(1)} Kg',
      );
    }
    buffer.writeln('');

    buffer.writeln('🏆 *PERFORMA TIAP CABANG:*');
    final sortedBranches = _branchMetrics.values.toList()
      ..sort((a, b) => b.omset.compareTo(a.omset));

    for (var b in sortedBranches) {
      final pct = _grandOmset > 0
          ? (b.omset / _grandOmset * 100).toStringAsFixed(1)
          : '0';
      buffer.writeln(
        '• *${b.store.nama}:* Rp ${_formatRupiah(b.omset)} ($pct% / ${b.transaksi} trx)',
      );
    }
    buffer.writeln('');

    buffer.writeln('💳 *METODE PEMBAYARAN:*');
    final cashPct = _grandOmset > 0
        ? (_grandCash / _grandOmset * 100).toStringAsFixed(1)
        : '0';
    buffer.writeln(
      '• Tunai (Cash): Rp ${_formatRupiah(_grandCash)} ($cashPct%)',
    );
    final digPct = _grandOmset > 0
        ? (_grandDigital / _grandOmset * 100).toStringAsFixed(1)
        : '0';
    buffer.writeln(
      '• Non-Tunai / Digital: Rp ${_formatRupiah(_grandDigital)} ($digPct%)',
    );
    buffer.writeln('');

    buffer.writeln('💼 *ARUS KAS GABUNGAN:*');
    buffer.writeln('• Penerimaan Omset: Rp ${_formatRupiah(_grandOmset)}');
    buffer.writeln(
      '• Pengeluaran Operasional: Rp ${_formatRupiah(_grandOperasional)}',
    );
    final net = _grandOmset - _grandOperasional;
    final isSurplus = net >= 0;
    buffer.writeln(
      '• Estimasi Kas Bersih: Rp ${_formatRupiah(net)} (${isSurplus ? "SURPLUS ✅" : "DEFISIT ⚠️"})',
    );
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('_Laporan Eksekutif Konsolidasi Kasumba Sawelas_');

    WhatsAppRecapService.showCustomRecapModal(
      context,
      storeName: 'Kasumba Sawelas (Semua Cabang)',
      reportText: buffer.toString().trim(),
    );
  }

  void _openStoreDashboard(StoreInfo store) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFFF8F7F4),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF20251F),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              store.nama,
              style: const TextStyle(
                color: Color(0xFF20251F),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          body: SharedDashboardView(
            namaToko: store.nama,
            sheetUrl: store.sheetUrl,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, ConsolidationFilter mode) {
    final isSelected = _filter == mode;
    return InkWell(
      onTap: () {
        setState(() => _filter = mode);
        _loadAllBranchData();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF8A00) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF8A00) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF20251F),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grandKasBersih = _grandOmset - _grandOperasional;
    final isSurplus = grandKasBersih >= 0;

    final sortedBranches = _branchMetrics.values.toList()
      ..sort((a, b) => b.omset.compareTo(a.omset));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F7F4),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF20251F),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard Konsolidasi',
              style: TextStyle(
                color: Color(0xFF20251F),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Rekap performa seluruh cabang toko',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          // WhatsApp Share
          IconButton(
            tooltip: 'Kirim Rekap Gabungan ke WA',
            icon: const Icon(
              Icons.chat_rounded,
              color: Color(0xFF25D366),
              size: 21,
            ),
            onPressed: _shareConsolidatedRecap,
          ),
          // Refresh
          IconButton(
            tooltip: 'Muat Ulang',
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF20251F),
              size: 21,
            ),
            onPressed: _loadAllBranchData,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFFF8A00),
          onRefresh: _loadAllBranchData,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            children: [
              // Filter Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Hari Ini', ConsolidationFilter.hariIni),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      '7 Hari Terakhir',
                      ConsolidationFilter.tujuhHari,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip('Bulan Ini', ConsolidationFilter.bulanIni),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // =======================================================
              // GRAND TOTAL CARD (Executive Summary)
              // =======================================================
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF20251F), Color(0xFF384337)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF20251F).withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
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
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF8A00),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.pie_chart_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'TOTAL OMSET GABUNGAN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: Color(0xFFFFB74D),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _getPeriodLabel(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Amount
                    _isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                color: Color(0xFFFF8A00),
                                strokeWidth: 2.5,
                              ),
                            ),
                          )
                        : Text(
                            'Rp ${_formatRupiah(_grandOmset)}',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                              color: Colors.white,
                            ),
                          ),
                    const SizedBox(height: 18),

                    // Metrics Grid (Trx, Kg, Net)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Transaksi',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white60,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$_grandTransaksi Trx',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_grandKg > 0)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Volume Terjual',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white60,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_grandKg.toStringAsFixed(1)} Kg',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Estimasi Bersih',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white60,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Rp ${_formatRupiah(grandKasBersih)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isSurplus
                                      ? const Color(0xFF5BE37A)
                                      : Colors.red.shade300,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // =======================================================
              // SECTION TITLE: PERFORMA CABANG
              // =======================================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Performa Tiap Cabang',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF20251F),
                    ),
                  ),
                  Text(
                    '${StoreRegistry.allStores.length} Cabang',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Branch Cards
              ...sortedBranches.map((metric) {
                final double pct = _grandOmset > 0
                    ? (metric.omset / _grandOmset)
                    : 0;
                final pctLabel = (pct * 100).toStringAsFixed(1);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: metric.store.themeColor.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  metric.store.icon,
                                  color: metric.store.themeColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    metric.store.nama,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF20251F),
                                    ),
                                  ),
                                  Text(
                                    '${metric.transaksi} transaksi ${metric.volumeKg > 0 ? "• ${metric.volumeKg.toStringAsFixed(1)} kg" : ""}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Rp ${_formatRupiah(metric.omset)}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: metric.store.themeColor,
                                ),
                              ),
                              Text(
                                '$pctLabel% kontribusi',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 7,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation(
                            metric.store.themeColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Bottom actions & info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tunai: Rp ${_formatRupiah(metric.cash)} • Digital: Rp ${_formatRupiah(metric.digital)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (metric.store.isUbiStore)
                            InkWell(
                              onTap: () => _openStoreDashboard(metric.store),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'Buka Toko',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: metric.store.themeColor,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 10,
                                      color: metric.store.themeColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),

              // =======================================================
              // METODE PEMBAYARAN KONSOLIDASI
              // =======================================================
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Konsolidasi Pembayaran',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF20251F),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF2E7D32,
                              ).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.payments_rounded,
                                      size: 16,
                                      color: Color(0xFF2E7D32),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Tunai (Cash)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2E7D32),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Rp ${_formatRupiah(_grandCash)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF20251F),
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
                              color: const Color(
                                0xFF1565C0,
                              ).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.qr_code_rounded,
                                      size: 16,
                                      color: Color(0xFF1565C0),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Digital / QRIS',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1565C0),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Rp ${_formatRupiah(_grandDigital)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF20251F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Share Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: _shareConsolidatedRecap,
                icon: const Icon(Icons.share_rounded, size: 20),
                label: const Text(
                  'Kirim Rekap Konsolidasi ke WhatsApp',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),

              const SizedBox(height: 12),

              // Owner Quick Shortcuts to Settings
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const KelolaAksesPetugasPage(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.security_rounded,
                      size: 16,
                      color: Color(0xFFFF8A00),
                    ),
                    label: const Text(
                      'Kelola Hak Akses',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFF8A00),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Text(' • ', style: TextStyle(color: Colors.grey)),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PengaturanHargaPage(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: Color(0xFFFF8A00),
                    ),
                    label: const Text(
                      'Pengaturan Harga',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFF8A00),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
