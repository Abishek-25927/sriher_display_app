import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../widgets/animated_heading.dart';
import '../../widgets/stylish_dialog.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Privilege definitions
// Each entry: { id: menuId, name: display, type: subId }
// The API expects "previliges": ["menuId,subId", ...]
// ──────────────────────────────────────────────────────────────────────────────
class _Priv {
  final String id; // "menuId,subId"  e.g. "1,1"
  final String name; // display label
  const _Priv(this.id, this.name);
}

const List<_Priv> _allPrivileges = [
  _Priv("1,1", "Dashboard"),
  _Priv("2,1", "Add User"),
  _Priv("3,1", "Role"),
  _Priv("3,2", "Device Master"),
  _Priv("3,3", "Department"),
  _Priv("3,4", "Location"),
  _Priv("3,5", "Mapping"),
  _Priv("4,1", "File Upload"),
  _Priv("5,1", "Create Template"),
  _Priv("5,2", "Default Template"),
  _Priv("5,3", "Select Template"),
  _Priv("6,1", "Schedule Allocate"),
  _Priv("6,2", "Assign Device"),
  _Priv("6,3", "Schedule List"),
  _Priv("6,4", "Specific Ranges"),
  _Priv("6,5", "Copy and Wipe Off"),
];

class RoleView extends StatefulWidget {
  const RoleView({super.key});

  @override
  State<RoleView> createState() => _RoleViewState();
}

class _RoleViewState extends State<RoleView>
    with SingleTickerProviderStateMixin {
  static const String _apiKey =
      "933cdb13cb54e31e694f82bf7f75f0144a9495036db0243b85dd855be53c06f2";

  // ── list state ──
  List<dynamic> allRoles = [];
  bool isLoading = true;
  String entriesValue = "10";
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // ── form state ──
  int? editingId; // null = create, non-null = update
  bool isSubmitting = false;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _roleNameController = TextEditingController();
  final Set<String> _selectedPrivs = {}; // e.g. {"1,1", "3,2"}

  @override
  void initState() {
    super.initState();
    fetchRoles();
  }

  @override
  void dispose() {
    _roleNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ──────────────────────────── API CALLS ──────────────────────────────────

  /// GET /roleview — fetch all roles
  Future<void> fetchRoles() async {
    setState(() => isLoading = true);
    try {
      final res = await http
          .post(
            Uri.parse('https://display.sriher.com/roleview'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"api_key": _apiKey}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final payload = data is Map && data.containsKey('data')
            ? data['data']
            : data;
        if (!mounted) return;
        setState(() {
          allRoles =
              (payload is List
                      ? payload
                      : (payload['roles'] ?? payload['data'] ?? []))
                  as List;
          isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => isLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _snack("Failed to load roles. Check connection.", isError: true);
    }
  }

  /// POST /roleUpdateFormview — load a single role into the form for editing
  Future<void> loadForEdit(dynamic role) async {
    final id = int.tryParse(role['id']?.toString() ?? '');
    if (id == null) return;

    setState(() => isLoading = true); // Added loading state for fetch
    try {
      final res = await http
          .post(
            Uri.parse('https://display.sriher.com/roleUpdateFormview'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"api_key": _apiKey, "id": id}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final payload = data is Map && data.containsKey('data')
            ? data['data']
            : data;
        final r = (payload is List && payload.isNotEmpty)
            ? payload[0]
            : payload;

        // Parse privileges — may come as List<String>, List<Map>, or comma-separated string
        final rawPrivs = r['previliges'] ?? r['privileges'] ?? [];
        final Set<String> privSet = {};
        if (rawPrivs is List) {
          for (final p in rawPrivs) {
            if (p is Map) {
              final mId = p['menu_id']?.toString() ?? p['menuId']?.toString();
              final sId =
                  p['sub_menu_id']?.toString() ??
                  p['subMenuId']?.toString() ??
                  p['sub_id']?.toString() ??
                  p['type']?.toString();
              if (mId != null && sId != null) {
                privSet.add("$mId,$sId");
              }
            } else {
              privSet.add(p.toString());
            }
          }
        } else if (rawPrivs is String && rawPrivs.isNotEmpty) {
          final parts = rawPrivs.split(',').map((s) => s.trim()).toList();
          if (parts.length > 1 && !parts[0].contains(',')) {
            for (int i = 0; i < parts.length - 1; i += 2) {
              privSet.add("${parts[i]},${parts[i + 1]}");
            }
          } else {
            privSet.addAll(parts);
          }
        }

        if (!mounted) return;
        setState(() {
          editingId = id;
          _roleNameController.text =
              r['role_name']?.toString() ?? role['role_name']?.toString() ?? '';
          _selectedPrivs
            ..clear()
            ..addAll(privSet);
          isLoading = false;
        });
        _showRoleDialog();
      } else {
        if (!mounted) return;
        setState(() => isLoading = false);
      }
    } catch (_) {
      // Fallback: use row data we already have
      if (!mounted) return;
      setState(() {
        editingId = id;
        _roleNameController.text = role['role_name']?.toString() ?? '';
        _selectedPrivs.clear();
        isLoading = false;
      });
      _showRoleDialog(); // Open dialog even on fallback
      _snack("Could not load role details.", isError: true);
    }
  }

  /// POST /createRoleview or /updateRoleview
  Future<void> handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPrivs.isEmpty) {
      _snack("Select at least one privilege.", isError: true);
      return;
    }

    setState(() => isSubmitting = true);

    final bool isUpdate = editingId != null;
    final url = isUpdate
        ? 'https://display.sriher.com/updateRoleview'
        : 'https://display.sriher.com/createRoleview';

    final Map<String, dynamic> body = {
      "api_key": _apiKey,
      "role_name": _roleNameController.text.trim(),
      "previliges": _selectedPrivs.toList(),
    };
    if (isUpdate) body["id"] = editingId;

    try {
      final res = await http
          .post(
            Uri.parse(url),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        if (!mounted) return;
        _snack(isUpdate ? "Role updated!" : "Role created!");
        _resetForm();
        if (Navigator.canPop(context)) Navigator.pop(context);
        fetchRoles();
      } else {
        if (!mounted) return;
        _snack("Server error (${res.statusCode}). Try again.", isError: true);
      }
    } catch (_) {
      if (!mounted) return;
      _snack("Connection failed. Check network.", isError: true);
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  /// POST /deleteRoleview — with confirmation dialog
  Future<void> deleteRole(dynamic role) async {
    final id = int.tryParse(role['id']?.toString() ?? '');
    if (id == null) return;

    final confirm = await StylishDialog.show<bool>(
      context: context,
      title: "DELETE ROLE",
      maxWidth: 400,
      builder: (context, setPopupState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Are you sure you want to delete \"${role['role_name']}\"? This action cannot be undone.",
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Delete Role",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final res = await http
          .post(
            Uri.parse('https://display.sriher.com/deleteRoleview'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"api_key": _apiKey, "id": id}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        if (!mounted) return;
        _snack("Role deleted.");
        fetchRoles();
      } else {
        if (!mounted) return;
        _snack("Delete failed (${res.statusCode}).", isError: true);
      }
    } catch (_) {
      if (!mounted) return;
      _snack("Connection failed.", isError: true);
    }
  }

  void _resetForm() {
    setState(() {
      editingId = null;
      _roleNameController.clear();
      _selectedPrivs.clear();
    });
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ──────────────────────────── POPUP DIALOG ────────────────────────────────

  void _showRoleDialog() {
    StylishDialog.show(
      context: context,
      title: editingId == null ? "Create Roles" : "Edit Role Details",
      subtitle: "Configure system permissions and access levels",
      icon: editingId == null ? Icons.add_moderator : Icons.edit_note_rounded,
      width: MediaQuery.of(context).size.width * 0.6,
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          return _buildRoleForm(setDialogState);
        },
      ),
    );
  }

  // ──────────────────────────── BUILD ──────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final int limit = int.parse(entriesValue);
    final filtered = searchQuery.isEmpty
        ? allRoles
        : allRoles
              .where(
                (r) => (r['role_name']?.toString().toLowerCase() ?? '')
                    .contains(searchQuery.toLowerCase()),
              )
              .toList();
    final paged = filtered.take(limit).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const AnimatedHeading(
                      text: "Roles List",
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showRoleDialog,
                      icon: const Icon(Icons.add_moderator, size: 20),
                      label: const Text(
                        "CREATE ROLES",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildListHeader(),
                const SizedBox(height: 16),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : paged.isEmpty
                      ? const Center(child: Text("No roles found."))
                      : _buildTableContainer(paged, filtered.length),
                ),
                const SizedBox(height: 20),
                _buildFooter(paged.length, filtered.length),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableContainer(List<dynamic> paged, int totalFiltered) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade100),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  columnSpacing: 24,
                  headingRowHeight: 45,
                  dataRowMaxHeight: 56,
                  horizontalMargin: 20,
                  headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                  columns: [
                    _buildCol('#'),
                    _buildCol('Role'),
                    _buildCol('Edit'),
                    _buildCol('Action'),
                  ],
                  rows: paged
                      .asMap()
                      .entries
                      .map((e) => _buildRow(e.key + 1, e.value))
                      .toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter(int pagedCount, int totalCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Showing $pagedCount of $totalCount entries",
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        _buildPagination(),
      ],
    );
  }

  // (Removed _buildFullViewEdit as it is no longer needed)

  Widget _buildRoleForm([StateSetter? setDialogState]) {
    final bool allSelected = _selectedPrivs.length == _allPrivileges.length;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Role Name",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _roleNameController,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? "Enter role name" : null,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'e.g. Administrator',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              const Text(
                "Permissions",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              Transform.scale(
                scale: 0.9,
                child: Checkbox(
                  value: allSelected,
                  onChanged: (v) {
                    if (setDialogState != null) {
                      setDialogState(() {
                        if (v == true) {
                          _selectedPrivs.addAll(
                            _allPrivileges.map((p) => p.id),
                          );
                        } else {
                          _selectedPrivs.clear();
                        }
                      });
                    }
                    setState(() {
                      if (v == true) {
                        _selectedPrivs.addAll(_allPrivileges.map((p) => p.id));
                      } else {
                        _selectedPrivs.clear();
                      }
                    });
                  },
                ),
              ),
              const Text("Select All", style: TextStyle(fontSize: 12)),
            ],
          ),
          const Divider(),

          // Privileges table
          SizedBox(
            height: 400, // Fixed height for scrolling permissions
            child: SingleChildScrollView(
              child: Table(
                border: TableBorder.all(color: Colors.grey.shade200),
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(2.5),
                },
                children: [
                  _buildPrivRow("Dashboard", [
                    _allPrivileges[0],
                  ], setDialogState),
                  _buildPrivRow("Users", [_allPrivileges[1]], setDialogState),
                  _buildPrivRow(
                    "System",
                    _allPrivileges.sublist(2, 7),
                    setDialogState,
                  ),
                  _buildPrivRow("Files", [_allPrivileges[7]], setDialogState),
                  _buildPrivRow(
                    "Templates",
                    _allPrivileges.sublist(8, 11),
                    setDialogState,
                  ),
                  _buildPrivRow(
                    "Scheduling",
                    _allPrivileges.sublist(11, 16),
                    setDialogState,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    _resetForm();
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          editingId == null ? "Create Role" : "Update Role",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────── UI HELPERS ─────────────────────────────────

  TableRow _buildPrivRow(
    String section,
    List<_Priv> privs, [
    StateSetter? setDialogState,
  ]) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            section,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Wrap(
            spacing: 0,
            runSpacing: 0,
            children: privs
                .map(
                  (p) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _selectedPrivs.contains(p.id),
                        onChanged: (v) {
                          if (setDialogState != null) {
                            setDialogState(() {
                              if (v == true) {
                                _selectedPrivs.add(p.id);
                              } else {
                                _selectedPrivs.remove(p.id);
                              }
                            });
                          }
                          setState(() {
                            if (v == true) {
                              _selectedPrivs.add(p.id);
                            } else {
                              _selectedPrivs.remove(p.id);
                            }
                          });
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Text(p.name, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 8),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  DataColumn _buildCol(String label) {
    return DataColumn(
      label: Text(
        label,
        style: TextStyle(
          color: Colors.blue.shade800,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  DataRow _buildRow(int idx, dynamic role) {
    return DataRow(
      cells: [
        DataCell(
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text("$idx", style: const TextStyle(fontSize: 13)),
          ),
        ),
        DataCell(
          Text(
            role['role_name']?.toString() ?? "-",
            style: const TextStyle(fontSize: 13),
          ),
        ),
        DataCell(
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
            tooltip: "Edit  ",
            onPressed: () => loadForEdit(role),
          ),
        ),
        DataCell(
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            tooltip: "Delete",
            onPressed: () => deleteRole(role),
          ),
        ),
      ],
    );
  }

  Widget _buildListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text(
              "Show ",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              height: 38,
              child: DropdownButtonFormField<String>(
                value: entriesValue,
                dropdownColor: Colors.white,
                style: const TextStyle(color: Colors.black87, fontSize: 13),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                items: ["10", "25", "50"]
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => entriesValue = v!),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              " entries",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        SizedBox(
          width: 250,
          height: 38,
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search roles...',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: Color(0xFF94A3B8),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pageBtn("Prev"),
        _pageBtn("1", active: true),
        _pageBtn("Next"),
      ],
    );
  }

  Widget _pageBtn(String label, {bool active = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: active ? Colors.blue : Colors.grey.shade100,
          foregroundColor: active ? Colors.white : Colors.black87,
          side: active
              ? const BorderSide(color: Colors.blue)
              : BorderSide(color: Colors.grey.shade300),
          padding: EdgeInsets.symmetric(horizontal: label.length > 1 ? 15 : 12),
          minimumSize: const Size(40, 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: () {},
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
