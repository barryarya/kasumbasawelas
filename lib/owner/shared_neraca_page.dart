import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../core/store_registry.dart';
import '../core/kulakan_service.dart';
import '../core/whatsapp_recap_service.dart';
import 'form_kulakan_page.dart';

/// Halaman Neraca & Laba Rugi Terpusat untuk seluruh cabang
class SharedNeracaPage extends StatefulWidget {
  final StoreInfo? store;

  const SharedNeracaPage({super.key, this.store});

  @override
  State<SharedNeracaPage> createState() => _SharedNeracaPageState();
}

class _SharedNeracaPageState extends State<SharedNeracaPage> {
  late StoreInfo _currentStore;
  bool _isLoading = true;

  // Filter Periode
  bool _isBulanan = false;
  DateTime _selectedDate = DateTime.now();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  // Data Penjualan
  int _totalPenjualan = 0;
  int _totalCash = 0;
  int _totalQris = 0;
  double _totalKgTerjual = 0;

  // Data Operasional & Inventaris
  int _totalBiayaOperasional = 0;
  int _totalInventaris = 0;

  final currencyFormatter = NumberFormat('#,###', 'id_ID');

  @override
  void initState() {
    super.initState();
    _currentStore = widget.store ?? StoreRegistry.allStores.first;
    _fetchNeracaData();
  }

  String get _tanggalQuery => DateFormat('yyyy-MM-dd').format(_selectedDate);
  String get _bulanQuery =>
      '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';

  String get _displayPeriodLabel {
    if (_isBulanan) {
      final dt = DateTime(_selectedYear, _selectedMonth, 1);
      return DateFormat('MMMM yyyy', 'id_ID').format(dt);
    }
    return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_selectedDate);
  }

  bool get _isHistoricalPeriod {
    final targetDate = _isBulanan
        ? DateTime(_selectedYear, _selectedMonth, 1)
        : _selectedDate;
    return targetDate.isBefore(KulakanService.cutOffDate);
  }

  int get _effectiveHpp {
    final targetDate = _isBulanan
        ? DateTime(_selectedYear, _selectedMonth, 1)
        : _selectedDate;
    return KulakanService.getEffectiveHpp(_currentStore.id, date: targetDate);
  }

  int get _modalUbiTerpakai => (_totalKgTerjual * _effectiveHpp).round();
  int get _labaKotor => _totalPenjualan - _modalUbiTerpakai;
  int get _labaBersih => _labaKotor - _totalBiayaOperasional;
  int get _kasBersih => _totalPenjualan - _totalBiayaOperasional;

  double get _marginPersen =>
      _totalPenjualan > 0 ? (_labaBersih / _totalPenjualan * 100) : 0.0;

  double get _stokMasukKg {
    DateTime start;
    DateTime end;
    if (_isBulanan) {
      start = DateTime(_selectedYear, _selectedMonth, 1);
      end = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);
    } else {
      start = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      end = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        23,
        59,
        59,
      );
    }
    return KulakanService.getTotalStokMasuk(
      _currentStore.id,
      startDate: start,
      endDate: end,
    );
  }

  double get _sisaStokKg {
    if (_stokMasukKg <= 0) return 0;
    final sisa = _stokMasukKg - _totalKgTerjual;
    return sisa > 0 ? sisa : 0;
  }

  int get _nilaiAsetStok => (_sisaStokKg * _effectiveHpp).round();

  Future<void> _fetchNeracaData() async {
    setState(() => _isLoading = true);

    try {
      final storeUrl = _currentStore.sheetUrl;

      final salesUrl = _isBulanan
          ? '$storeUrl?penjualan&bulan=$_bulanQuery'
          : '$storeUrl?penjualan&tanggal=$_tanggalQuery';

      final opUrl = _isBulanan
          ? '$storeUrl?type=operasional&bulan=$_bulanQuery'
          : '$storeUrl?type=operasional&tanggal=$_tanggalQuery';

      final results = await Future.wait([
        http.get(Uri.parse(salesUrl)).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse(opUrl)).timeout(const Duration(seconds: 15)),
      ]);

      // Parse Penjualan
      int cash = 0;
      int qris = 0;
      double totalKg = 0;
      int totalJual = 0;

      if (results[0].statusCode == 200) {
        final jData = jsonDecode(results[0].body);
        final List list = (jData is Map && jData['data'] is List)
            ? jData['data']
            : (jData is List ? jData : []);

        for (var item in list) {
          final harga = int.tryParse(item['harga'].toString()) ?? 0;
          final berat = double.tryParse(item['berat'].toString()) ?? 0.0;
          final metode = (item['pembayaran'] ?? '').toString().toLowerCase();

          totalJual += harga;
          totalKg += berat;

          if (metode.contains('cash') || metode.contains('tunai')) {
            cash += harga;
          } else {
            qris += harga;
          }
        }
      }

      // Parse Operasional
      int biayaOp = 0;
      int inventaris = 0;

      if (results[1].statusCode == 200) {
        final jData = jsonDecode(results[1].body);
        final List list = (jData is Map && jData['data'] is List)
            ? jData['data']
            : (jData is List ? jData : []);

        for (var item in list) {
          final nama = (item['nama_barang'] ?? '').toString();
          final harga = int.tryParse(item['harga'].toString()) ?? 0;

          if (nama.toUpperCase().contains('[KULAKAN]')) {
            // Belanja kulakan tercatat di sheet
          } else if (nama.contains('*')) {
            biayaOp += harga;
          } else {
            inventaris += harga;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _totalPenjualan = totalJual;
        _totalCash = cash;
        _totalQris = qris;
        _totalKgTerjual = totalKg;
        _totalBiayaOperasional = biayaOp;
        _totalInventaris = inventaris;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      helpText: 'Pilih Tanggal Laporan',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _isBulanan = false;
      });
      _fetchNeracaData();
    }
  }

  Future<void> _pickMonth() async {
    final months = [
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

    int tempMonth = _selectedMonth;
    int tempYear = _selectedYear;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setMState(() => tempYear--),
                  ),
                  Text(
                    '$tempYear',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setMState(() => tempYear++),
                  ),
                ],
              ),
              const Divider(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(12, (index) {
                  final mIdx = index + 1;
                  final isSelected = tempMonth == mIdx;
                  return ChoiceChip(
                    label: Text(months[index]),
                    selected: isSelected,
                    selectedColor: const Color(0xFFFF8A00),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) {
                      Navigator.pop(ctx);
                      setState(() {
                        _selectedMonth = mIdx;
                        _selectedYear = tempYear;
                        _isBulanan = true;
                      });
                      _fetchNeracaData();
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareNeracaToWhatsApp() {
    final lines = [
      '📊 *LAPORAN LABA RUGI & NERACA*',
      '🏢 Cabang: *${_currentStore.nama}*',
      '📅 Periode: $_displayPeriodLabel',
      '🏷️ Status HPP: ${_isHistoricalPeriod ? "Estimasi Historis (@Rp ${currencyFormatter.format(_effectiveHpp)})" : "Riil Kulakan (@Rp ${currencyFormatter.format(_effectiveHpp)})"}',
      '',
      '━━━━━━━━━━━━━━━━━━━━',
      '📈 *1. LABA RUGI (INCOME STATEMENT)*',
      '• Total Omset: *Rp ${currencyFormatter.format(_totalPenjualan)}*',
      if (_currentStore.isUbiStore)
        '• Volume Terjual: ${_totalKgTerjual.toStringAsFixed(1)} Kg',
      if (_currentStore.isUbiStore)
        '• Modal Ubi Terjual (HPP): Rp ${currencyFormatter.format(_modalUbiTerpakai)}',
      if (_currentStore.isUbiStore)
        '• Laba Kotor: Rp ${currencyFormatter.format(_labaKotor)}',
      '• Biaya Operasional Toko: Rp ${currencyFormatter.format(_totalBiayaOperasional)}',
      '• *LABA BERSIH:* *Rp ${currencyFormatter.format(_labaBersih)}*',
      '• Margin Keuntungan: *${_marginPersen.toStringAsFixed(1)}%*',
      '',
      '━━━━━━━━━━━━━━━━━━━━',
      '💰 *2. ARUS KAS TOKO*',
      '• Kas Tunai (Cash): Rp ${currencyFormatter.format(_totalCash)}',
      '• Kas Digital (QRIS): Rp ${currencyFormatter.format(_totalQris)}',
      '• Total Kas Bersih: *Rp ${currencyFormatter.format(_kasBersih)}*',
      '',
      if (_currentStore.isUbiStore) ...[
        '━━━━━━━━━━━━━━━━━━━━',
        '🥔 *3. STOK & ASET UBI*',
        '• Total Ubi Masuk: ${_stokMasukKg.toStringAsFixed(0)} Kg',
        '• Total Terjual: ${_totalKgTerjual.toStringAsFixed(1)} Kg',
        '• Estimasi Sisa Stok: ${_sisaStokKg.toStringAsFixed(1)} Kg',
        '• Nilai Aset Sisa Ubi: *Rp ${currencyFormatter.format(_nilaiAsetStok)}*',
        '',
      ],
      '━━━━━━━━━━━━━━━━━━━━',
      'Generated via Kasumba Sawelas POS App',
    ];

    WhatsAppRecapService.showCustomRecapModal(
      context,
      storeName: _currentStore.nama,
      reportText: lines.join('\n'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _currentStore.themeColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        title: Text(
          'Neraca ${_currentStore.nama}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF20251F),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Bagikan ke WhatsApp',
            icon: const Icon(Icons.share_rounded, color: Color(0xFF25D366)),
            onPressed: _shareNeracaToWhatsApp,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchNeracaData,
        color: const Color(0xFFFF8A00),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            // PILIH CABANG (Jika dibuka secara global)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(_currentStore.icon, color: themeColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _currentStore.id,
                        isExpanded: true,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF20251F),
                        ),
                        items: StoreRegistry.allStores.map((s) {
                          return DropdownMenuItem(
                            value: s.id,
                            child: Text(s.nama),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final target = StoreRegistry.getById(val);
                            if (target != null) {
                              setState(() => _currentStore = target);
                              _fetchNeracaData();
                            }
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // FILTER PERIODE (Harian vs Bulanan)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (_isBulanan) {
                          setState(() => _isBulanan = false);
                          _fetchNeracaData();
                        } else {
                          _pickDate();
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: !_isBulanan
                              ? const Color(0xFFFF8A00)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          !_isBulanan
                              ? DateFormat('dd MMM yyyy').format(_selectedDate)
                              : 'Harian',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: !_isBulanan ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (!_isBulanan) {
                          setState(() => _isBulanan = true);
                          _fetchNeracaData();
                        } else {
                          _pickMonth();
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _isBulanan
                              ? const Color(0xFFFF8A00)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _isBulanan
                              ? DateFormat('MMM yyyy').format(
                                  DateTime(_selectedYear, _selectedMonth, 1),
                                )
                              : 'Bulanan',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _isBulanan ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // BANNER HPP & CUT-OFF
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isHistoricalPeriod
                    ? Colors.amber.shade50
                    : const Color(0xFF2E7D32).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isHistoricalPeriod
                      ? Colors.amber.shade300
                      : const Color(0xFF2E7D32).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isHistoricalPeriod
                        ? Icons.history_rounded
                        : Icons.check_circle_rounded,
                    color: _isHistoricalPeriod
                        ? Colors.amber.shade800
                        : const Color(0xFF2E7D32),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isHistoricalPeriod
                              ? 'Periode Historis (Sebelum Cut-Off)'
                              : 'Periode Berjalan (Data Riil)',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: _isHistoricalPeriod
                                ? Colors.amber.shade900
                                : const Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isHistoricalPeriod
                              ? 'HPP menggunakan taksiran modal rata-rata Rp ${currencyFormatter.format(_effectiveHpp)}/Kg.'
                              : 'HPP dihitung otomatis dari catatan belanja ubi baru (@Rp ${currencyFormatter.format(_effectiveHpp)}/Kg).',
                          style: const TextStyle(fontSize: 11, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Color(0xFFFF8A00)),
                ),
              )
            else ...[
              // ==========================================
              // 1. KARTU LABA BERSIH UTAMA
              // ==========================================
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _labaBersih >= 0
                        ? [const Color(0xFF2E7D32), const Color(0xFF1B5E20)]
                        : [const Color(0xFFD32F2F), const Color(0xFFB71C1C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: (_labaBersih >= 0 ? Colors.green : Colors.red)
                          .withValues(alpha: 0.3),
                      blurRadius: 16,
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
                        const Text(
                          'ESTIMASI LABA BERSIH RIIL',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Margin ${_marginPersen.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _labaBersih >= 0
                          ? 'Rp ${currencyFormatter.format(_labaBersih)}'
                          : '- Rp ${currencyFormatter.format(_labaBersih.abs())}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _labaBersih >= 0
                          ? 'Keuntungan bersih setelah modal bahan baku & operasional toko'
                          : 'Operasional melebihi hasil penjualan periode ini',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ==========================================
              // 2. RINCIAN LABA RUGI (INCOME STATEMENT)
              // ==========================================
              _buildSectionTitle('Rincian Laba Rugi (Income Statement)'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildRowItem(
                      icon: Icons.trending_up_rounded,
                      iconColor: Colors.green,
                      title: 'Total Omset Penjualan (+)',
                      subtitle: _currentStore.isUbiStore
                          ? '${_totalKgTerjual.toStringAsFixed(1)} Kg terjual'
                          : 'Seluruh pesanan',
                      value: 'Rp ${currencyFormatter.format(_totalPenjualan)}',
                      valueColor: Colors.green.shade800,
                    ),
                    const Divider(height: 1),
                    if (_currentStore.isUbiStore) ...[
                      _buildRowItem(
                        icon: Icons.inventory_2_rounded,
                        iconColor: Colors.brown,
                        title: 'Modal Ubi Terjual / HPP (-)',
                        subtitle:
                            '${_totalKgTerjual.toStringAsFixed(1)} Kg @Rp ${currencyFormatter.format(_effectiveHpp)}',
                        value:
                            'Rp ${currencyFormatter.format(_modalUbiTerpakai)}',
                        valueColor: Colors.brown.shade800,
                      ),
                      const Divider(height: 1),
                      _buildRowItem(
                        icon: Icons.pie_chart_rounded,
                        iconColor: Colors.blue,
                        title: 'Laba Kotor (Gross Profit)',
                        subtitle: 'Omset - Modal Ubi Terjual',
                        value: 'Rp ${currencyFormatter.format(_labaKotor)}',
                        valueColor: Colors.blue.shade900,
                        isBold: true,
                      ),
                      const Divider(height: 1),
                    ],
                    _buildRowItem(
                      icon: Icons.receipt_long_rounded,
                      iconColor: Colors.red,
                      title: 'Biaya Operasional Toko (-)',
                      subtitle: 'Gas, plastik, es, perlengkapan kasir',
                      value:
                          'Rp ${currencyFormatter.format(_totalBiayaOperasional)}',
                      valueColor: Colors.red.shade800,
                    ),
                    if (_totalInventaris > 0) ...[
                      const Divider(height: 1),
                      _buildRowItem(
                        icon: Icons.inventory_rounded,
                        iconColor: Colors.orange,
                        title: 'Belanja Inventaris (Aset Tetap)',
                        subtitle: 'Peralatan & perlengkapan toko',
                        value:
                            'Rp ${currencyFormatter.format(_totalInventaris)}',
                        valueColor: Colors.orange.shade800,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ==========================================
              // 3. ARUS KAS & PEMBAYARAN
              // ==========================================
              _buildSectionTitle('Arus Kas Masuk & Keluar'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildCashBox(
                            title: 'Kas Tunai (Cash)',
                            value: 'Rp ${currencyFormatter.format(_totalCash)}',
                            icon: Icons.payments_rounded,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCashBox(
                            title: 'Kas Digital (QRIS)',
                            value: 'Rp ${currencyFormatter.format(_totalQris)}',
                            icon: Icons.qr_code_rounded,
                            color: const Color(0xFF1565C0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Sisa Kas Bersih Toko:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Rp ${currencyFormatter.format(_kasBersih)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFF8A00),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ==========================================
              // 4. POSISI STOK & ASET UBI (Hanya untuk Toko Ubi)
              // ==========================================
              if (_currentStore.isUbiStore) ...[
                _buildSectionTitle('Stok Bahan Baku & Aset Toko'),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStokMetric(
                            title: 'Stok Masuk',
                            value: '${_stokMasukKg.toStringAsFixed(0)} Kg',
                            color: Colors.black87,
                          ),
                          _buildStokMetric(
                            title: 'Ubi Terjual',
                            value: '${_totalKgTerjual.toStringAsFixed(1)} Kg',
                            color: Colors.green.shade800,
                          ),
                          _buildStokMetric(
                            title: 'Sisa Stok Toko',
                            value: '${_sisaStokKg.toStringAsFixed(1)} Kg',
                            color: const Color(0xFFFF8A00),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFFF8A00,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(
                              0xFFFF8A00,
                            ).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Nilai Rupiah Sisa Ubi di Toko:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Rp ${currencyFormatter.format(_nilaiAsetStok)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF20251F),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // TOMBOL AKSI OWNER
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FormKulakanPage(
                              preselectedStoreId: _currentStore.id,
                            ),
                          ),
                        );
                        _fetchNeracaData();
                      },
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: const Text('Catat Beli Ubi'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF8A00),
                        side: const BorderSide(color: Color(0xFFFF8A00)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _shareNeracaToWhatsApp,
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share Rekap WA'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Color(0xFF20251F),
        ),
      ),
    );
  }

  Widget _buildRowItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String value,
    required Color valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                    color: const Color(0xFF20251F),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashBox({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF20251F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStokMetric({
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
