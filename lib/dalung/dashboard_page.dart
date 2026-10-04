import 'package:flutter/material.dart';

import 'neraca_page.dart';
import 'saldo_page.dart';
import 'transaksi_page.dart';
import 'operasional_page.dart';
import 'package:kasumbasawelas/core/shared_dashboard_view.dart';

class DashboardDalungPage extends StatelessWidget {
  const DashboardDalungPage({super.key});

  static const String defaultSheetUrl =
      'https://script.google.com/macros/s/AKfycbzYEwkgkVC5rIgxMkkHRvG1UOwtki_-WU0r3aoj2SuqJXVQ6e82CRsyMrkM3rrdX_KPzw/exec';

  @override
  Widget build(BuildContext context) {
    return SharedDashboardView(
      namaToko: 'Toko Dalung',
      sheetUrl: defaultSheetUrl,
      onOpenNeraca: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NeracaDalungPage()),
        );
      },
      onOpenSaldo: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SaldoDalungPage()),
        );
      },
      onOpenTransaksi: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TransaksiDalungPage()),
        );
      },
      onOpenOperasional: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OperasionalDalungPage()),
        );
      },
    );
  }
}
