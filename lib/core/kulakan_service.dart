import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'store_registry.dart';

/// Model pencatatan belanja / kulakan ubi
class KulakanRecord {
  final String id;
  final DateTime tanggal;
  final String storeId; // 'keboiwa', 'dalung', 'nusadua', 'semua'
  final String jenisUbi; // 'Ubi Cilembu', 'Ubi Ungu', 'Campur'
  final double beratKg;
  final int totalBiaya;
  final int hargaPerKg;
  final String catatan;

  KulakanRecord({
    required this.id,
    required this.tanggal,
    required this.storeId,
    required this.jenisUbi,
    required this.beratKg,
    required this.totalBiaya,
    int? hargaPerKg,
    this.catatan = '',
  }) : hargaPerKg = hargaPerKg ??
            (beratKg > 0 ? (totalBiaya / beratKg).round() : 13500);

  Map<String, dynamic> toJson() => {
        'id': id,
        'tanggal': tanggal.toIso8601String(),
        'storeId': storeId,
        'jenisUbi': jenisUbi,
        'beratKg': beratKg,
        'totalBiaya': totalBiaya,
        'hargaPerKg': hargaPerKg,
        'catatan': catatan,
      };

  factory KulakanRecord.fromJson(Map<String, dynamic> json) {
    return KulakanRecord(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      tanggal: DateTime.tryParse(json['tanggal'] ?? '') ?? DateTime.now(),
      storeId: json['storeId'] ?? 'semua',
      jenisUbi: json['jenisUbi'] ?? 'Ubi Cilembu',
      beratKg: (json['beratKg'] as num?)?.toDouble() ?? 0.0,
      totalBiaya: (json['totalBiaya'] as num?)?.toInt() ?? 0,
      hargaPerKg: (json['hargaPerKg'] as num?)?.toInt(),
      catatan: json['catatan'] ?? '',
    );
  }
}

/// Service penyimpan dan kalkulasi pembelian ubi (Kulakan)
class KulakanService {
  KulakanService._();

  static const String _keyKulakan = 'kulakan_history_v1';
  static final List<KulakanRecord> _records = [];
  static bool _isInitialized = false;

  /// Patokan harga beli rata-rata masa lalu (6 bulan lalu) yang disepakati Owner
  static const int defaultHistoricalHpp = 13500;

  /// Tanggal cut-off mulai berlakunya pencatatan kulakan baru
  static final DateTime cutOffDate = DateTime(2026, 3, 1);

  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyKulakan);
      _records.clear();
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        for (var item in list) {
          _records.add(KulakanRecord.fromJson(item as Map<String, dynamic>));
        }
      }
      _isInitialized = true;
    } catch (_) {
      _records.clear();
    }
  }

  /// Ambil semua riwayat kulakan
  static List<KulakanRecord> getAllRecords() {
    final list = List<KulakanRecord>.from(_records);
    list.sort((a, b) => b.tanggal.compareTo(a.tanggal));
    return list;
  }

  /// Ambil riwayat kulakan untuk cabang tertentu
  static List<KulakanRecord> getRecordsForStore(
    String storeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return getAllRecords().where((r) {
      final matchStore = r.storeId == 'semua' || r.storeId == storeId;
      if (!matchStore) return false;

      if (startDate != null && r.tanggal.isBefore(startDate)) return false;
      if (endDate != null && r.tanggal.isAfter(endDate)) return false;

      return true;
    }).toList();
  }

  /// Hitung HPP (Harga Pokok Penjualan) efektif untuk cabang & periode tertentu
  static int getEffectiveHpp(String storeId, {DateTime? date}) {
    // Jika melihat tanggal sebelum Cut-Off, pakai taksiran historis Rp 13.500
    final targetDate = date ?? DateTime.now();
    if (targetDate.isBefore(cutOffDate)) {
      return defaultHistoricalHpp;
    }

    // Ambil riwayat kulakan cabang tersebut (atau 'semua')
    final storeRecords = _records.where((r) {
      final matchStore = r.storeId == 'semua' || r.storeId == storeId;
      return matchStore && !r.tanggal.isAfter(targetDate);
    }).toList();

    if (storeRecords.isEmpty) {
      return defaultHistoricalHpp;
    }

    // Hitung rata-rata tertimbang: Total Rupiah / Total Kg
    double totalKg = 0;
    int totalBiaya = 0;
    for (var r in storeRecords) {
      totalKg += r.beratKg;
      totalBiaya += r.totalBiaya;
    }

    if (totalKg <= 0) return defaultHistoricalHpp;
    return (totalBiaya / totalKg).round();
  }

  /// Hitung total stok ubi masuk (Kg) yang dicatat
  static double getTotalStokMasuk(
    String storeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final records = getRecordsForStore(
      storeId,
      startDate: startDate,
      endDate: endDate,
    );
    double sum = 0;
    for (var r in records) {
      sum += r.beratKg;
    }
    return sum;
  }

  /// Simpan catatan pembelian ubi baru (ke penyimpanan lokal + sinkron ke Google Sheet)
  static Future<void> saveRecord(
    KulakanRecord record, {
    bool postToSheet = true,
  }) async {
    _records.removeWhere((r) => r.id == record.id);
    _records.add(record);
    await _persist();

    if (postToSheet) {
      // Kirim salinan ke Google Sheet cabang terkait sebagai operasional kulakan
      final targetStore = StoreRegistry.getById(record.storeId);
      if (targetStore != null && targetStore.isUbiStore) {
        try {
          final payload = {
            'type': 'operasional',
            'nama_barang':
                '[KULAKAN] ${record.jenisUbi} ${record.beratKg.toStringAsFixed(0)}Kg @${record.hargaPerKg}',
            'harga': record.totalBiaya,
          };
          await http.post(
            Uri.parse(targetStore.sheetUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          );
        } catch (_) {}
      }
    }
  }

  /// Hapus catatan kulakan
  static Future<void> deleteRecord(String id) async {
    _records.removeWhere((r) => r.id == id);
    await _persist();
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _records.map((r) => r.toJson()).toList();
      await prefs.setString(_keyKulakan, jsonEncode(list));
    } catch (_) {}
  }
}

