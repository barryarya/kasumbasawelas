import 'package:flutter/material.dart';
import '../core/store_registry.dart';
import '../owner/shared_neraca_page.dart';

/// Halaman Neraca Toko Kebo Iwa (Menggunakan SharedNeracaPage)
class NeracaPage extends StatelessWidget {
  const NeracaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SharedNeracaPage(store: StoreRegistry.getById('keboiwa'));
  }
}
