import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'store_registry.dart';

/// Aturan hak akses untuk seorang petugas kasir
class StaffRule {
  final String nama;
  final String role; // 'Admin' atau 'Karyawan'
  final List<String> allowedStores; // Nama cabang yang diizinkan atau ['ALL']
  final bool canInput; // true: boleh simpan transaksi, false: view-only

  const StaffRule({
    required this.nama,
    required this.role,
    required this.allowedStores,
    required this.canInput,
  });

  bool get hasFullAccess =>
      role.toLowerCase() == 'admin' ||
      allowedStores.contains('ALL') ||
      allowedStores.length >= StoreRegistry.allStores.length;

  bool isStoreAllowed(String storeName) {
    if (hasFullAccess) return true;
    final target = storeName.toLowerCase().trim();
    return allowedStores.any((s) {
      final item = s.toLowerCase().trim();
      return item == target || item.contains(target) || target.contains(item);
    });
  }

  Map<String, dynamic> toJson() => {
    'nama': nama,
    'role': role,
    'allowedStores': allowedStores,
    'canInput': canInput,
  };

  factory StaffRule.fromJson(Map<String, dynamic> json) {
    return StaffRule(
      nama: json['nama'] ?? '',
      role: json['role'] ?? 'Karyawan',
      allowedStores:
          (json['allowedStores'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['ALL'],
      canInput: json['canInput'] ?? true,
    );
  }

  StaffRule copyWith({
    String? nama,
    String? role,
    List<String>? allowedStores,
    bool? canInput,
  }) {
    return StaffRule(
      nama: nama ?? this.nama,
      role: role ?? this.role,
      allowedStores: allowedStores ?? this.allowedStores,
      canInput: canInput ?? this.canInput,
    );
  }
}

/// Pusat pengelolaan aturan akses petugas (StaffAccessConfig)
class StaffAccessConfig {
  StaffAccessConfig._();

  static const String _keyStaffRules = 'staff_access_rules_v1';

  // In-memory cache map: Nama Petugas (lowercase) -> StaffRule
  static final Map<String, StaffRule> _rules = {};
  static bool _isInitialized = false;

  /// Default bawaan sistem (hanya Admin utama)
  static final List<StaffRule> defaultRules = [
    const StaffRule(
      nama: 'Admin',
      role: 'Admin',
      allowedStores: ['ALL'],
      canInput: true,
    ),
  ];

  /// Inisialisasi saat startup aplikasi (main.dart)
  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_keyStaffRules);

      _rules.clear();

      if (savedJson != null && savedJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(savedJson);
        for (var item in list) {
          final rule = StaffRule.fromJson(item as Map<String, dynamic>);
          final key = rule.nama.toLowerCase().trim();
          // Bersihkan mantan karyawan (Dhani, Eza, Yudi) jika masih tersimpan di cache lama
          if (key == 'dhani' ||
              key == 'eza' ||
              key == 'yudi' ||
              key == 'dani') {
            continue;
          }
          _rules[key] = rule;
        }
        // Pastikan Admin selalu ada
        if (!_rules.containsKey('admin')) {
          _rules['admin'] = defaultRules.first;
        }
        await _persist();
      } else {
        // Isi default (hanya Admin) jika belum pernah ada data tersimpan
        for (var def in defaultRules) {
          final key = def.nama.toLowerCase().trim();
          _rules[key] = def;
        }
        await _persist();
      }

      _isInitialized = true;
    } catch (_) {
      // Fallback ke default
      _rules.clear();
      for (var def in defaultRules) {
        _rules[def.nama.toLowerCase().trim()] = def;
      }
    }
  }

  /// Periksa apakah petugas boleh mengakses cabang tertentu
  static bool isStoreAllowed(String? namaPetugas, String toko) {
    if (namaPetugas == null || namaPetugas.isEmpty) return true;
    final key = namaPetugas.toLowerCase().trim();
    final rule = _rules[key];
    if (rule == null) {
      // Petugas baru yang belum terdaftar: jika bukan Admin, default izinkan semua atau cek role
      return true;
    }
    return rule.isStoreAllowed(toko);
  }

  /// Periksa apakah petugas diizinkan menginput transaksi
  static bool canInput(String? namaPetugas) {
    if (namaPetugas == null || namaPetugas.isEmpty) return true;
    final key = namaPetugas.toLowerCase().trim();
    final rule = _rules[key];
    if (rule == null) return true;
    return rule.canInput;
  }

  /// Cek apakah petugas adalah staff/karyawan (bukan Admin)
  static bool isStaff(String? namaPetugas) {
    if (namaPetugas == null || namaPetugas.isEmpty) return false;
    final key = namaPetugas.toLowerCase().trim();
    if (key == 'admin') return false;
    final rule = _rules[key];
    if (rule != null) {
      return rule.role.toLowerCase() != 'admin';
    }
    return true;
  }

  /// Cek apakah petugas adalah Admin (atau Owner)
  static bool isAdmin(String? namaPetugas, [String? rolePetugas]) {
    if (rolePetugas != null && rolePetugas.toLowerCase() == 'admin') {
      return true;
    }
    if (namaPetugas == null || namaPetugas.isEmpty) {
      return false;
    }
    final key = namaPetugas.toLowerCase().trim();
    if (key == 'admin') {
      return true;
    }
    return !isStaff(namaPetugas);
  }

  /// Dapatkan daftar nama cabang yang diizinkan untuk petugas
  static List<String> getAllowedStores(String namaPetugas) {
    final key = namaPetugas.toLowerCase().trim();
    final rule = _rules[key];
    if (rule == null || rule.hasFullAccess) {
      return StoreRegistry.allStoreNames;
    }
    return rule.allowedStores;
  }

  /// Dapatkan pesan teks izin cabang untuk pesan error/peringatan
  static String getAllowedStoresMessage(String namaPetugas) {
    final stores = getAllowedStores(namaPetugas);
    if (stores.length >= StoreRegistry.allStores.length) {
      return '$namaPetugas memiliki akses penuh ke semua cabang.';
    }
    return '$namaPetugas hanya memiliki akses ke: ${stores.join(", ")}';
  }

  /// Ambil seluruh daftar aturan petugas
  static List<StaffRule> getAllRules() {
    return _rules.values.toList();
  }

  /// Ambil aturan petugas berdasarkan nama
  static StaffRule? getRule(String nama) {
    return _rules[nama.toLowerCase().trim()];
  }

  /// Simpan atau perbarui aturan petugas (mendukung perubahan nama)
  static Future<void> saveRule(StaffRule rule, [String? oldNama]) async {
    if (oldNama != null && oldNama.trim().isNotEmpty) {
      final oldKey = oldNama.toLowerCase().trim();
      final newKey = rule.nama.toLowerCase().trim();
      if (oldKey != newKey) {
        _rules.remove(oldKey);
      }
    }
    _rules[rule.nama.toLowerCase().trim()] = rule;
    await _persist();
  }

  /// Hapus aturan petugas (akun Admin utama dilindungi dari penghapusan)
  static Future<bool> deleteRule(String nama) async {
    final key = nama.toLowerCase().trim();
    if (key == 'admin') return false;
    _rules.remove(key);
    await _persist();
    return true;
  }

  /// Reset seluruh aturan hak akses ke bawaan standar
  static Future<void> resetToDefault() async {
    _rules.clear();
    for (var def in defaultRules) {
      _rules[def.nama.toLowerCase().trim()] = def;
    }
    await _persist();
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _rules.values.map((r) => r.toJson()).toList();
      await prefs.setString(_keyStaffRules, jsonEncode(list));
    } catch (_) {}
  }

  /// Memeriksa status akun kasir secara aman ke Google Sheet (hanya saat splash screen / refresh).
  /// Mengembalikan false HANYA jika server secara eksplisit membalas "NONAKTIF".
  static Future<bool> checkAccountActiveOnline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nama = prefs.getString('namaPetugas');
      final role = prefs.getString('rolePetugas');
      final password = prefs.getString('passwordPetugas');

      if (nama == null || role == null || password == null || nama.isEmpty) {
        return true;
      }

      // Jangan cek Admin ke server
      if (nama.toLowerCase().trim() == 'admin' ||
          role.toLowerCase().trim() == 'admin') {
        return true;
      }

      final url = Uri.parse(
        "https://script.google.com/macros/s/AKfycbxIusc8pC9My8OX7o3rFnueXR2OdNO0R67pwIqkInSUKgdzN4DOtOSHDMeufYwyTUCV/exec"
        "?nama=$nama&role=$role&password=$password",
      );

      final response = await http.get(url).timeout(const Duration(seconds: 7));
      final status = response.body.trim();

      if (status == "NONAKTIF") {
        // Hapus HANYA sesi login petugas ini, JANGAN pernah panggil prefs.clear()!
        await prefs.remove('isPetugasSet');
        await prefs.remove('namaPetugas');
        await prefs.remove('rolePetugas');
        await prefs.remove('passwordPetugas');
        await prefs.remove('bolehInput');
        await prefs.remove('aksesToko');
        return false; // Akun telah dinonaktifkan di Google Sheet
      }

      return true;
    } catch (_) {
      // Jika jaringan offline, timeout, atau server gangguan, kasir TETAP AMAN bekerja
      return true;
    }
  }
}
