import 'package:flutter/material.dart';
import '../core/store_registry.dart';
import '../owner/shared_neraca_page.dart';

/// Halaman Neraca Toko Dalung (Menggunakan SharedNeracaPage)
class NeracaDalungPage extends StatelessWidget {
  const NeracaDalungPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SharedNeracaPage(store: StoreRegistry.getById('dalung'));
  }
}
