import 'package:flutter/material.dart';

/// Informasi metadata sebuah cabang toko
class StoreInfo {
  final String id;
  final String nama;
  final String sheetUrl;
  final Color themeColor;
  final IconData icon;
  final bool isUbiStore;

  const StoreInfo({
    required this.id,
    required this.nama,
    required this.sheetUrl,
    required this.themeColor,
    required this.icon,
    this.isUbiStore = true,
  });
}

/// Pusat registri daftar seluruh cabang Kasumba Sawelas.
class StoreRegistry {
  StoreRegistry._();

  static const List<StoreInfo> allStores = [
    StoreInfo(
      id: 'keboiwa',
      nama: 'Toko Kebo Iwa',
      sheetUrl:
          'https://script.google.com/macros/s/AKfycbyvlc0WNpqtnSZLYfXyyYnt1YsfO_3Et7FUpOuakhJXQar9TkUeWAzJsVKmL0fr_XSpqg/exec',
      themeColor: Color(0xFFFF8A00),
      icon: Icons.storefront_rounded,
      isUbiStore: true,
    ),
    StoreInfo(
      id: 'dalung',
      nama: 'Toko Dalung',
      sheetUrl:
          'https://script.google.com/macros/s/AKfycbzYEwkgkVC5rIgxMkkHRvG1UOwtki_-WU0r3aoj2SuqJXVQ6e82CRsyMrkM3rrdX_KPzw/exec',
      themeColor: Color(0xFF2E7D32),
      icon: Icons.store_rounded,
      isUbiStore: true,
    ),
    StoreInfo(
      id: 'nusadua',
      nama: 'Toko Nusa Dua',
      sheetUrl:
          'https://script.google.com/macros/s/AKfycbzanDpa7SX5AUxUQVhHnELeMlmTYG_WGr1U7jLD9csiOmz68vQNGbK7Xh6UT3VHgqmL0Q/exec',
      themeColor: Color(0xFF1565C0),
      icon: Icons.beach_access_rounded,
      isUbiStore: true,
    ),
  ];

  static StoreInfo? getById(String id) {
    try {
      return allStores.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  static StoreInfo? getByName(String name) {
    try {
      final clean = name.toLowerCase().trim();
      return allStores.firstWhere(
        (s) =>
            s.nama.toLowerCase().trim() == clean ||
            s.nama.toLowerCase().contains(clean) ||
            clean.contains(s.id),
      );
    } catch (_) {
      return null;
    }
  }

  static List<String> get allStoreNames =>
      allStores.map((s) => s.nama).toList();
}
