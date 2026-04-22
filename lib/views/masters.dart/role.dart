import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ──────────────────────────────────────────────────────────────────────────────
// Privilege definitions
// Each entry: { id: menuId, name: display, type: subId }
// The API expects "previliges": ["menuId,subId", ...]
// ──────────────────────────────────────────────────────────────────────────────
class _Priv {
  final String id;   // "menuId,subId"  e.g. "1,1"
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

class _RoleViewState extends State<RoleView> with SingleTickerProviderStateMixin {
  static const String _apiKey =
      "933cdb13cb54e31e694f82bf7f75f0144a9495036db0243b85dd855be53c06f2";

  // ── list state ──
  List<dynamic> allRoles = [];
  bool isLoading = true;
  String entriesValue = "10";
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // ── form state ──
  int? editingId;           // null = create, non-null = update
  bool isSubmitting = false;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _roleNameController = TextEditingController();
  final Set<String> _selectedPrivs = {};   // e.g. {"1,1", "3,2"}

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
          .post(Uri.parse('https://display.sriher.com/roleview'),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({"api_key": _apiKey}))
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final payload =
            data is Map && data.containsKey('data') ? data['data'] : data;
        setState(() {
          allRoles = (payload is List
                  ? payload
                  : (payload['roles'] ?? payload['data'] ?? [])) as List;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (_) {
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
          .post(Uri.parse('https://display.sriher.com/roleUpdateFormview'),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({"api_key": _apiKey, "id": id}))
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final payload =
            data is Map && data.containsKey('data') ? data['data'] : data;
        final r = (payload is List && payload.isNotEmpty) ? payload[0] : payload;

        // Parse privileges — may come as List<String>, List<Map>, or comma-separated string
        final rawPrivs = r['previliges'] ?? r['privileges'] ?? [];
        final Set<String> privSet = {};
        if (rawPrivs is List) {
          for (final p in rawPrivs) {
            if (p is Map) {
              final mId = p['menu_id']?.toString() ?? p['menuId']?.toString();
              final sId = p['sub_menu_id']?.toString() ?? p['subMenuId']?.toString() ?? p['sub_id']?.toString() ?? p['type']?.toString();
              if (mId != null && sId != null) {
                privSet.add("$mId,$sId");
              }
            } else {
              privSet.add(p.toString());
            }
          }
        } else if (rawPrivs is String && rawPrivs.isNotEmpty) {
          final parts = rawPrivs.split(',').map((s) => s.trim()).toList();
          // Heuristic: if they are pairs like "1,1,3,1", group them; else just add them
          // If the list of parts only contains single integers, they might be pairs.
          // However, most likely the API returns ["1,1", "3,1"] as strings in a list.
          if (parts.length > 1 && !parts[0].contains(',')) {
             // Possible "1,1,3,1" format
             for (int i = 0; i < parts.length - 1; i += 2) {
               privSet.add("${parts[i]},${parts[i+1]}");
             }
          } else {
            privSet.addAll(parts);
          }
        }

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
        setState(() => isLoading = false);
      }
    } catch (_) {
      // Fallback: use row data we already have
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
          .post(Uri.parse(url),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        _snack(isUpdate ? "Role updated!" : "Role created!");
        _resetForm();
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        fetchRoles();
      } else {
        _snack("Server error (${res.statusCode}). Try again.", isError: true);
      }
    } catch (_) {
      _snack("Connection failed. Check network.", isError: true);
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  /// POST /deleteRoleview — with confirmation dialog
  Future<void> deleteRole(dynamic role) async {
    final id = int.tryParse(role['id']?.toString() ?? '');
    if (id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Role"),
        content: Text(
            "Are you sure you want to delete \"${role['role_name']}\"?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http
          .post(Uri.parse('https://display.sriher.com/deleteRoleview'),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({"api_key": _apiKey, "id": id}))
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        _snack("Role deleted.");
        fetchRoles();
      } else {
        _snack("Delete failed (${res.statusCode}).", isError: true);
      }
    } catch (_) {
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ──────────────────────────── POPUP DIALOG ────────────────────────────────

  void _showRoleDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              titlePadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF000000),
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      editingId == null ? "Create New Role" : "Edit Role Details",
                      style: const TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        _resetForm();
                        Navigator.pop(context);
                      },
                    )
                  ],
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.6,
                child: SingleChildScrollView(
                  child: _buildRoleForm(setDialogState),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ──────────────────────────── BUILD ──────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final int limit = int.parse(entriesValue);
    final filtered = searchQuery.isEmpty
        ? allRoles
        : allRoles
            .where((r) => (r['role_name']?.toString().toLowerCase() ?? '')
                .contains(searchQuery.toLowerCase()))
            .toList();
    final paged = filtered.take(limit).toList();

    return Container(
      color: const Color(0xFF000000),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Area
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Roles List",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
          
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 4,
                  ),
                  onPressed: _showRoleDialog,
                  icon: const Icon(Icons.add_moderator, size: 20),
                  label: const Text("CREATE ROLE",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Table Card
            Expanded(
              child: Card(
                color: Colors.white,
                elevation: 5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      _buildListHeader(),
                      const SizedBox(height: 20),
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
          ],
        ),
      ),
    );
  }

  Widget _buildTableContainer(List<dynamic> paged, int totalFiltered) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 100),
          child: DataTable(
            columnSpacing: 24,
            headingRowHeight: 56,
            dataRowMaxHeight: 60,
            headingRowColor: WidgetStateProperty.all(const Color(0xFF000000)),
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
    );
  }

  Widget _buildFooter(int pagedCount, int totalCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Showing $pagedCount of $totalCount entries",
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
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
          // Role Name field
          const Text.rich(
            TextSpan(
              
              children: [
                
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _roleNameController,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? "Enter role name" : null,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Enter Role Name',
              hintStyle: TextStyle(fontSize: 13),
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            ),
          ),
          const SizedBox(height: 15),

          // Select All
          Row(children: [
            Checkbox(
              value: allSelected,
              tristate: true,
              onChanged: (v) {
                if (setDialogState != null) {
                  setDialogState(() {
                    if (v == true) {
                      _selectedPrivs.addAll(_allPrivileges.map((p) => p.id));
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
            const Text("Select All",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ]),
          const Divider(),

          // Privileges table
          Table(
            border: TableBorder.all(color: Colors.grey[300]!),
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(2.5)
            },
            children: [
              _buildPrivRow("Dashboard", [_allPrivileges[0]], setDialogState),
              _buildPrivRow("Authentication", [_allPrivileges[1]], setDialogState),
              _buildPrivRow("Masters", _allPrivileges.sublist(2, 7), setDialogState),
              _buildPrivRow("File Master", [_allPrivileges[7]], setDialogState),
              _buildPrivRow(
                  "Template Master", _allPrivileges.sublist(8, 11), setDialogState),
              _buildPrivRow("Schedule", _allPrivileges.sublist(11), setDialogState),
            ],
          ),
          const SizedBox(height: 24),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () {
                  _resetForm();
                  if (Navigator.canPop(context)) Navigator.pop(context);
                },
                child: const Text("Cancel", style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                width: 120,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000000),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 4,
                  ),
                  onPressed: isSubmitting ? null : handleSubmit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(editingId == null ? "Submit" : "Update",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────── UI HELPERS ─────────────────────────────────

  TableRow _buildPrivRow(String section, List<_Priv> privs, [StateSetter? setDialogState]) {
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(section,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Wrap(
          spacing: 0,
          runSpacing: 0,
          children: privs
              .map((p) => Row(
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
                  ))
              .toList(),
        ),
      ),
    ]);
  }

  DataColumn _buildCol(String label) {
    return DataColumn(
      label: Expanded(
        child: Row(children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11)),
          ),
          const Spacer(),
          const Icon(Icons.unfold_more, color: Colors.white70, size: 14),
        ]),
      ),
    );
  }

  DataRow _buildRow(int idx, dynamic role) {
    return DataRow(cells: [
      DataCell(Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text("$idx", style: const TextStyle(fontSize: 13)))),
      DataCell(
          Text(role['role_name']?.toString() ?? "-",
              style: const TextStyle(fontSize: 13))),
      DataCell(IconButton(
        icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
        tooltip: "Edit  ",
        onPressed: () => loadForEdit(role),
      )),
      DataCell(IconButton(
        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
        tooltip: "Delete",
        onPressed: () => deleteRole(role),
      )),
    ]);
  }

  Widget _buildListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          const Text("Show ",
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          SizedBox(
            width: 65,
            height: 35,
            child: DropdownButtonFormField<String>(
              initialValue: entriesValue,
              decoration: const InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 5),
                  border: OutlineInputBorder()),
              items: ["10", "25", "50"]
                  .map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(v,
                          style:
                              const TextStyle(fontSize: 11))))
                  .toList(),
              onChanged: (v) =>
                  setState(() => entriesValue = v!),
            ),
          ),
          const Text(" entries",
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 11)),
        ]),
        Row(children: [
          const Text("Search: ",
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 11)),
          SizedBox(
            width: 110,
            height: 35,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8),
              ),
              onChanged: (v) =>
                  setState(() => searchQuery = v),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildPagination() {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _pageBtn("Prev"),
      _pageBtn("1", active: true),
      _pageBtn("Next"),
    ]);
  }

  Widget _pageBtn(String label, {bool active = false}) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? Colors.blue : Colors.white,
        foregroundColor: active ? Colors.white : Colors.blue,
        side: const BorderSide(color: Colors.grey),
        padding:
            EdgeInsets.symmetric(horizontal: label == "1" ? 12 : 15),
        minimumSize: const Size(45, 36),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero),
      ),
      onPressed: () {},
      child: Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}