import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/kulakan_service.dart';
import '../core/store_registry.dart';

class FormKulakanPage extends StatefulWidget {
  final String? preselectedStoreId;

  const FormKulakanPage({super.key, this.preselectedStoreId});

  @override
  State<FormKulakanPage> createState() => _FormKulakanPageState();
}

class _FormKulakanPageState extends State<FormKulakanPage> {
  final _formKey = GlobalKey<FormState>();
  final _beratController = TextEditingController();
  final _totalBiayaController = TextEditingController();
  final _catatanController = TextEditingController();

  late String _selectedStoreId;
  String _selectedJenisUbi = 'Ubi Cilembu';
  DateTime _selectedDate = DateTime.now();
  bool _postToSheet = true;
  bool _isSaving = false;

  final currencyFormatter = NumberFormat('#,###', 'id_ID');

  @override
  void initState() {
    super.initState();
    _selectedStoreId = widget.preselectedStoreId ?? 'dalung';
  }

  @override
  void dispose() {
    _beratController.dispose();
    _totalBiayaController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  int get _calculatedHargaPerKg {
    final berat =
        double.tryParse(_beratController.text.replaceAll(',', '.')) ?? 0;
    final biaya =
        int.tryParse(_totalBiayaController.text.replaceAll('.', '')) ?? 0;
    if (berat <= 0 || biaya <= 0) return 0;
    return (biaya / berat).round();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      helpText: 'Pilih Tanggal Kulakan',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _simpanKulakan() async {
    if (!_formKey.currentState!.validate()) return;

    final berat =
        double.tryParse(_beratController.text.replaceAll(',', '.')) ?? 0;
    final biaya =
        int.tryParse(_totalBiayaController.text.replaceAll('.', '')) ?? 0;

    if (berat <= 0 || biaya <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Berat dan total biaya harus lebih dari 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final newRecord = KulakanRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        tanggal: _selectedDate,
        storeId: _selectedStoreId,
        jenisUbi: _selectedJenisUbi,
        beratKg: berat,
        totalBiaya: biaya,
        catatan: _catatanController.text.trim(),
      );

      await KulakanService.saveRecord(newRecord, postToSheet: _postToSheet);

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _beratController.clear();
        _totalBiayaController.clear();
        _catatanController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kulakan ubi berhasil disimpan! Modal: Rp ${currencyFormatter.format(newRecord.hargaPerKg)}/Kg',
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _formatBiayaInput(String value) {
    String clean = value.replaceAll('.', '');
    if (clean.isEmpty) return;
    int? number = int.tryParse(clean);
    if (number != null) {
      String formatted = currencyFormatter.format(number);
      _totalBiayaController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final recentRecords = KulakanService.getAllRecords().take(5).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        title: const Text(
          'Catat Kulakan Ubi',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF20251F),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Banner Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8A00).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFF8A00).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8A00),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Catat Belanja Bahan Baku',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF20251F),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Setiap kali Anda belanja ubi, masukkan jumlah kg dan total biaya untuk menghitung HPP & laba riil di Neraca.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // FORM KULAKAN
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabang Tujuan
                    const Text(
                      'Cabang Tujuan Pasokan',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedStoreId,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.storefront_rounded,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'dalung',
                          child: Text('Toko Dalung'),
                        ),
                        DropdownMenuItem(
                          value: 'keboiwa',
                          child: Text('Toko Kebo Iwa'),
                        ),
                        DropdownMenuItem(
                          value: 'nusadua',
                          child: Text('Toko Nusa Dua'),
                        ),
                        DropdownMenuItem(
                          value: 'semua',
                          child: Text('Semua Cabang / Gudang Pusat'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStoreId = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Jenis Ubi
                    const Text(
                      'Jenis Ubi',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildJenisChip('Ubi Cilembu'),
                        const SizedBox(width: 8),
                        _buildJenisChip('Ubi Ungu'),
                        const SizedBox(width: 8),
                        _buildJenisChip('Campur'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tanggal Pembelian
                    const Text(
                      'Tanggal Pembelian',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 18,
                                  color: Color(0xFFFF8A00),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  DateFormat(
                                    'EEEE, dd MMMM yyyy',
                                    'id_ID',
                                  ).format(_selectedDate),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'Ubah',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFFF8A00),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Input Berat (Kg)
                    const Text(
                      'Total Berat Ubi (Kg)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _beratController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\,?\d*'),
                        ),
                      ],
                      decoration: InputDecoration(
                        hintText: 'Contoh: 300 atau 500.5',
                        suffixText: 'Kg',
                        prefixIcon: const Icon(Icons.scale_rounded, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Berat ubi wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Input Total Biaya (Rp)
                    const Text(
                      'Total Uang Dikeluarkan (Rp)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _totalBiayaController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: 'Contoh: 3.900.000',
                        prefixText: 'Rp ',
                        prefixIcon: const Icon(
                          Icons.payments_rounded,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onChanged: _formatBiayaInput,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Total biaya pembelian wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Kalkulator Modal / Kg Card
                    if (_calculatedHargaPerKg > 0)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF2E7D32,
                          ).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(
                              0xFF2E7D32,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calculate_rounded,
                              color: Color(0xFF2E7D32),
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'HARGA MODAL (HPP) TERHITUNG:',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                  Text(
                                    'Rp ${currencyFormatter.format(_calculatedHargaPerKg)} / Kg',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF20251F),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Catatan
                    const Text(
                      'Catat Pemasok / Keterangan (Opsional)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _catatanController,
                      decoration: InputDecoration(
                        hintText: 'Misal: Petani Sumedang / Kiriman Gudang',
                        prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Switch post to sheet
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _postToSheet,
                      activeThumbColor: const Color(0xFFFF8A00),
                      title: const Text(
                        'Rekam ke Google Sheet Toko',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        'Simpan juga sebagai pengeluaran operasional kulakan di spreadsheet cabang',
                        style: TextStyle(fontSize: 11),
                      ),
                      onChanged: (val) => setState(() => _postToSheet = val),
                    ),
                    const SizedBox(height: 20),

                    // Tombol Simpan
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _simpanKulakan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8A00),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Simpan Pembelian Ubi',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Riwayat Kulakan Terakhir
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Riwayat Kulakan Terakhir',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF20251F),
                  ),
                ),
                Text(
                  '${recentRecords.length} Catatan',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (recentRecords.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  'Belum ada riwayat kulakan yang dicatat.\nSetiap pembelian ubi baru akan muncul di sini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              )
            else
              ...recentRecords.map((rec) => _buildRecentKulakanCard(rec)),
          ],
        ),
      ),
    );
  }

  Widget _buildJenisChip(String label) {
    final isSelected = _selectedJenisUbi == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedJenisUbi = label),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF8A00) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFFF8A00)
                  : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentKulakanCard(KulakanRecord rec) {
    final store = StoreRegistry.getById(rec.storeId);
    final storeName = store?.nama ?? 'Semua Cabang';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFF8A00).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inventory_rounded,
              color: Color(0xFFFF8A00),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${rec.beratKg.toStringAsFixed(0)} Kg ${rec.jenisUbi}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Rp ${currencyFormatter.format(rec.totalBiaya)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '$storeName • @Rp ${currencyFormatter.format(rec.hargaPerKg)}/Kg',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('dd MMM yyyy').format(rec.tanggal),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                if (rec.catatan.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    rec.catatan,
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: Colors.red.shade400,
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dCtx) => AlertDialog(
                  title: const Text('Hapus Catatan Kulakan?'),
                  content: Text(
                    'Hapus catatan ${rec.beratKg} Kg ubi ini dari riwayat?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dCtx, false),
                      child: const Text('Batal'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(dCtx, true),
                      child: const Text('Hapus'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await KulakanService.deleteRecord(rec.id);
                setState(() {});
              }
            },
          ),
        ],
      ),
    );
  }
}
