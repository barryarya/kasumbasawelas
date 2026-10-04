import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pusat konfigurasi harga ubi untuk semua cabang Kasumba Sawelas.
/// Menyimpan harga di SharedPreferences dan menyediakan akses cepat (synchronous)
/// di seluruh form penjualan dan scanner OCR.
class PriceConfig {
  PriceConfig._();

  // Keys SharedPreferences
  static const String keyMentah = 'harga_mentah';
  static const String keyBakar = 'harga_bakar';
  static const String keyUnguMentah = 'harga_ungu_mentah';
  static const String keyUnguBakar = 'harga_ungu_bakar';
  static const String keyYakon = 'harga_yakon';

  // Default Standard Prices (Rp / Kg)
  static const int defaultMentah = 26000;
  static const int defaultBakar = 36000;
  static const int defaultUnguMentah = 25000;
  static const int defaultUnguBakar = 35000;
  static const int defaultYakon = 35000;

  // In-Memory Cache (agar pemanggilan getHargaPerKg selalu synchronous & instan)
  static int _mentah = defaultMentah;
  static int _bakar = defaultBakar;
  static int _unguMentah = defaultUnguMentah;
  static int _unguBakar = defaultUnguBakar;
  static int _yakon = defaultYakon;

  static bool _initialized = false;

  /// Inisialisasi saat aplikasi pertama kali dibuka (di main.dart)
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _mentah = prefs.getInt(keyMentah) ?? defaultMentah;
      _bakar = prefs.getInt(keyBakar) ?? defaultBakar;
      _unguMentah = prefs.getInt(keyUnguMentah) ?? defaultUnguMentah;
      _unguBakar = prefs.getInt(keyUnguBakar) ?? defaultUnguBakar;
      _yakon = prefs.getInt(keyYakon) ?? defaultYakon;
      _initialized = true;
    } catch (_) {
      // Fallback ke default jika SharedPreferences belum siap
      _mentah = defaultMentah;
      _bakar = defaultBakar;
      _unguMentah = defaultUnguMentah;
      _unguBakar = defaultUnguBakar;
      _yakon = defaultYakon;
    }
  }

  // Getters
  static int get hargaMentah => _mentah;
  static int get hargaBakar => _bakar;
  static int get hargaUnguMentah => _unguMentah;
  static int get hargaUnguBakar => _unguBakar;
  static int get hargaYakon => _yakon;

  /// Dapatkan harga per kg berdasarkan nama varian ubi.
  /// Bersifat synchronous sehingga tidak mengubah arsitektur form penjualan / OCR.
  static int getHargaPerKg(String? jenis) {
    switch (jenis) {
      case 'Mentah':
      case 'Cilembu Mentah':
      case 'Ubi Cilembu Mentah':
        return _mentah;

      case 'Bakar':
      case 'Cilembu Bakar':
      case 'Ubi Cilembu Bakar':
        return _bakar;

      case 'Ubi Ungu Mentah':
        return _unguMentah;

      case 'Ubi Ungu Bakar':
        return _unguBakar;

      case 'Ubi Yakon':
      case 'Yakon':
        return _yakon;

      default:
        return _bakar;
    }
  }

  /// Simpan pembaruan harga ke SharedPreferences dan update cache memori
  static Future<void> savePrices({
    required int mentah,
    required int bakar,
    required int unguMentah,
    required int unguBakar,
    required int yakon,
  }) async {
    _mentah = mentah;
    _bakar = bakar;
    _unguMentah = unguMentah;
    _unguBakar = unguBakar;
    _yakon = yakon;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyMentah, mentah);
    await prefs.setInt(keyBakar, bakar);
    await prefs.setInt(keyUnguMentah, unguMentah);
    await prefs.setInt(keyUnguBakar, unguBakar);
    await prefs.setInt(keyYakon, yakon);
  }

  /// Reset semua harga ke standar bawaan
  static Future<void> resetToDefault() async {
    await savePrices(
      mentah: defaultMentah,
      bakar: defaultBakar,
      unguMentah: defaultUnguMentah,
      unguBakar: defaultUnguBakar,
      yakon: defaultYakon,
    );
  }

  /// Format angka ke representasi Rupiah (contoh: 36000 -> 36.000)
  static String formatRupiah(int amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    ).format(amount).trim();
  }
}
