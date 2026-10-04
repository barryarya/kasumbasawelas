import 'package:flutter/material.dart';

import 'neraca_page.dart';
import 'saldo_page.dart';
import 'transaksi_page.dart';
import 'operasional_page.dart';
import 'package:kasumbasawelas/core/shared_dashboard_view.dart';

class DashboardNusaDuaPage extends StatelessWidget {
  const DashboardNusaDuaPage({super.key});

  static const String defaultSheetUrl =
      'https://script.google.com/macros/s/AKfycbzanDpa7SX5AUxUQVhHnELeMlmTYG_WGr1U7jLD9csiOmz68vQNGbK7Xh6UT3VHgqmL0Q/exec';

  @override
  Widget build(BuildContext context) {
    return SharedDashboardView(
      namaToko: 'Toko Nusa Dua',
      sheetUrl: defaultSheetUrl,
      onOpenNeraca: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NeracaNusaDuaPage()),
        );
      },
      onOpenSaldo: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SaldoNusaDuaPage()),
        );
      },
      onOpenTransaksi: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TransaksiNusaDuaPage()),
        );
      },
      onOpenOperasional: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OperasionalNusaDuaPage()),
        );
      },
    );
  }
}
