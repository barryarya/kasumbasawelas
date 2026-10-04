import 'package:flutter/material.dart';
import '../core/store_registry.dart';
import '../owner/shared_neraca_page.dart';

/// Halaman Neraca Toko Nusa Dua (Menggunakan SharedNeracaPage)
class NeracaNusaDuaPage extends StatelessWidget {
  const NeracaNusaDuaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SharedNeracaPage(store: StoreRegistry.getById('nusadua'));
  }
}
