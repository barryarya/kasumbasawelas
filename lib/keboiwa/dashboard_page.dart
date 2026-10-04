import 'package:flutter/material.dart';

import 'neraca_page.dart';
import 'saldo_page.dart';
import 'transaksi_page.dart';
import 'operasional_page.dart';
import 'package:kasumbasawelas/core/shared_dashboard_view.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const String defaultSheetUrl =
      'https://script.google.com/macros/s/AKfycbyvlc0WNpqtnSZLYfXyyYnt1YsfO_3Et7FUpOuakhJXQar9TkUeWAzJsVKmL0fr_XSpqg/exec';

  @override
  Widget build(BuildContext context) {
    return SharedDashboardView(
      namaToko: 'Toko Kebo Iwa',
      sheetUrl: defaultSheetUrl,
      onOpenNeraca: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NeracaPage()),
        );
      },
      onOpenSaldo: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SaldoPage()),
        );
      },
      onOpenTransaksi: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TransaksiPage()),
        );
      },
      onOpenOperasional: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OperasionalPage()),
        );
      },
    );
  }
}
