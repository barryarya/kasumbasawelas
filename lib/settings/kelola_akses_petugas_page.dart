import 'package:flutter/material.dart';
import 'package:kasumbasawelas/core/staff_access_config.dart';
import 'package:kasumbasawelas/core/store_registry.dart';

class KelolaAksesPetugasPage extends StatefulWidget {
  const KelolaAksesPetugasPage({super.key});

  @override
  State<KelolaAksesPetugasPage> createState() => _KelolaAksesPetugasPageState();
}

class _KelolaAksesPetugasPageState extends State<KelolaAksesPetugasPage> {
  List<StaffRule> _staffList = [];

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  void _loadRules() {
    setState(() {
      _staffList = StaffAccessConfig.getAllRules();
    });
  }

  void _showEditStaffModal({StaffRule? existingRule}) {
    final bool isNew = existingRule == null;
    final nameCtrl = TextEditingController(text: existingRule?.nama ?? '');
    String selectedRole = existingRule?.role ?? 'Karyawan';
    bool canInput = existingRule?.canInput ?? true;
    bool allStores = existingRule?.hasFullAccess ?? false;

    // Set of selected store names
    final Set<String> selectedStores = {};
    if (existingRule != null) {
      if (existingRule.hasFullAccess) {
        selectedStores.addAll(StoreRegistry.allStoreNames);
      } else {
        selectedStores.addAll(existingRule.allowedStores);
      }
    } else {
      selectedStores.addAll(StoreRegistry.allStoreNames);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          padding: EdgeInsets.fromLTRB(
            22,
            16,
            22,
            MediaQuery.of(context).viewInsets.bottom + 26,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isNew
                          ? 'Tambah Petugas Baru'
                          : 'Atur Hak Akses: ${existingRule.nama}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF20251F),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Nama Petugas
                const Text(
                  'Nama Petugas',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Rian / Sinta',
                    prefixIcon: const Icon(
                      Icons.person_outline_rounded,
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
                ),
                const SizedBox(height: 16),

                // Role Selector
                const Text(
                  'Peran / Role',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setModalState(() {
                            selectedRole = 'Karyawan';
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selectedRole == 'Karyawan'
                                ? const Color(
                                    0xFFFF8A00,
                                  ).withValues(alpha: 0.12)
                                : const Color(0xFFF7F8F9),
                            border: Border.all(
                              color: selectedRole == 'Karyawan'
                                  ? const Color(0xFFFF8A00)
                                  : Colors.grey.shade300,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.badge_outlined,
                                size: 18,
                                color: selectedRole == 'Karyawan'
                                    ? const Color(0xFFFF8A00)
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Karyawan',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: selectedRole == 'Karyawan'
                                      ? const Color(0xFFFF8A00)
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setModalState(() {
                            selectedRole = 'Admin';
                            allStores = true;
                            canInput = true;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selectedRole == 'Admin'
                                ? const Color(
                                    0xFF20251F,
                                  ).withValues(alpha: 0.10)
                                : const Color(0xFFF7F8F9),
                            border: Border.all(
                              color: selectedRole == 'Admin'
                                  ? const Color(0xFF20251F)
                                  : Colors.grey.shade300,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.admin_panel_settings_rounded,
                                size: 18,
                                color: selectedRole == 'Admin'
                                    ? const Color(0xFF20251F)
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Admin / Owner',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: selectedRole == 'Admin'
                                      ? const Color(0xFF20251F)
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Cabang yang diizinkan
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Cabang yang Boleh Diakses',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        setModalState(() {
                          if (allStores) {
                            allStores = false;
                            selectedStores.clear();
                          } else {
                            allStores = true;
                            selectedStores.addAll(StoreRegistry.allStoreNames);
                          }
                        });
                      },
                      child: Text(
                        allStores ? 'Pilih Manual' : 'Pilih Semua Cabang',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF8A00),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Store checklist
                ...StoreRegistry.allStores.map((store) {
                  final isChecked =
                      allStores || selectedStores.contains(store.nama);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isChecked
                          ? store.themeColor.withValues(alpha: 0.06)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isChecked
                            ? store.themeColor.withValues(alpha: 0.3)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: CheckboxListTile(
                      activeColor: store.themeColor,
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: Text(
                        store.nama,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isChecked
                              ? const Color(0xFF20251F)
                              : Colors.grey.shade600,
                        ),
                      ),
                      secondary: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: store.themeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          store.icon,
                          size: 18,
                          color: store.themeColor,
                        ),
                      ),
                      value: isChecked,
                      onChanged: (val) {
                        setModalState(() {
                          if (val == true) {
                            selectedStores.add(store.nama);
                            if (selectedStores.length >=
                                StoreRegistry.allStores.length) {
                              allStores = true;
                            }
                          } else {
                            allStores = false;
                            selectedStores.remove(store.nama);
                          }
                        });
                      },
                    ),
                  );
                }),

                const SizedBox(height: 10),

                // Izin Input Switch
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Izin Input Transaksi',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Jika nonaktif, petugas hanya bisa melihat laporan (View Only).',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        activeTrackColor: const Color(0xFF25D366),
                        value: canInput,
                        onChanged: (val) {
                          setModalState(() {
                            canInput = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Save Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF20251F),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nama petugas tidak boleh kosong!'),
                        ),
                      );
                      return;
                    }

                    final finalAllowedStores = allStores
                        ? ['ALL']
                        : selectedStores.toList();

                    if (finalAllowedStores.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Pilih minimal 1 cabang untuk petugas ini!',
                          ),
                        ),
                      );
                      return;
                    }

                    final newRule = StaffRule(
                      nama: name,
                      role: selectedRole,
                      allowedStores: finalAllowedStores,
                      canInput: canInput,
                    );

                    await StaffAccessConfig.saveRule(
                      newRule,
                      existingRule?.nama,
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!mounted) return;
                    _loadRules();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF20251F),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        content: Text(
                          'Hak akses untuk "$name" berhasil disimpan!',
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Simpan Hak Akses',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                if (!isNew && existingRule.nama.toLowerCase() != 'admin') ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text(
                        'Hapus Petugas "${existingRule.nama}"',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleDeleteStaff(existingRule.nama);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleDeleteStaff(String nama) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Hapus Petugas "$nama"?'),
        content: const Text(
          'Petugas ini akan dihapus dari konfigurasi hak akses aplikasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StaffAccessConfig.deleteRule(nama);
      _loadRules();
    }
  }

  Future<void> _handleReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset ke Pengaturan Awal?'),
        content: const Text(
          'Seluruh aturan hak akses petugas akan dikembalikan ke setting bawaan (hanya Admin).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8A00),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StaffAccessConfig.resetToDefault();
      _loadRules();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F7F4),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF20251F),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Hak Akses Petugas',
          style: TextStyle(
            color: Color(0xFF20251F),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Reset ke Bawaan',
            onPressed: _handleReset,
            icon: const Icon(
              Icons.restart_alt_rounded,
              color: Color(0xFFFF8A00),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
          children: [
            // Info Header Banner
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF20251F), Color(0xFF374151)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.security_rounded,
                    color: Color(0xFFFF8A00),
                    size: 30,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kelola Hak Akses Kasir',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Tentukan cabang mana saja yang boleh dibuka oleh setiap kasir & izin input penjualan.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Staff Cards List
            ..._staffList.map((rule) {
              final isAdmin = rule.role.toLowerCase() == 'admin';
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: isAdmin
                                    ? const Color(
                                        0xFF20251F,
                                      ).withValues(alpha: 0.1)
                                    : const Color(
                                        0xFFFF8A00,
                                      ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                isAdmin
                                    ? Icons.admin_panel_settings_rounded
                                    : Icons.person_rounded,
                                color: isAdmin
                                    ? const Color(0xFF20251F)
                                    : const Color(0xFFFF8A00),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rule.nama,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF20251F),
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isAdmin
                                        ? const Color(0xFF20251F)
                                        : const Color(
                                            0xFFFF8A00,
                                          ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    rule.role.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: isAdmin
                                          ? Colors.white
                                          : const Color(0xFFFF8A00),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Edit Akses',
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 20,
                                color: Color(0xFF20251F),
                              ),
                              onPressed: () =>
                                  _showEditStaffModal(existingRule: rule),
                            ),
                            if (!isAdmin && rule.nama.toLowerCase() != 'admin')
                              IconButton(
                                tooltip: 'Hapus Petugas',
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                onPressed: () => _handleDeleteStaff(rule.nama),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 22),

                    // Allowed branches badges
                    const Text(
                      'Cabang yang diizinkan:',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: rule.hasFullAccess
                          ? [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF2E7D32,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 14,
                                      color: Color(0xFF2E7D32),
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      'Semua Cabang Toko',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2E7D32),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ]
                          : rule.allowedStores.map((store) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F4F8),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  store,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF20251F),
                                  ),
                                ),
                              );
                            }).toList(),
                    ),
                    const SizedBox(height: 10),

                    // Input permission badge
                    Row(
                      children: [
                        Icon(
                          rule.canInput
                              ? Icons.edit_note_rounded
                              : Icons.visibility_outlined,
                          size: 16,
                          color: rule.canInput
                              ? const Color(0xFF2E7D32)
                              : Colors.orange.shade800,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          rule.canInput
                              ? 'Boleh input penjualan'
                              : 'Mode lihat saja (View Only)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: rule.canInput
                                ? const Color(0xFF2E7D32)
                                : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFF8A00),
        foregroundColor: Colors.white,
        elevation: 3,
        onPressed: () => _showEditStaffModal(),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text(
          'Tambah Petugas',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
