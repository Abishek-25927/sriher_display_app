import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AddUserView extends StatefulWidget {
  const AddUserView({super.key});

  @override
  State<AddUserView> createState() => _AddUserViewState();
}

class _AddUserViewState extends State<AddUserView> {
  static const String _apiKey =
      "933cdb13cb54e31e694f82bf7f75f0144a9495036db0243b85dd855be53c06f2";

  List<dynamic> allUsers = [];
  List<dynamic> allRoles = [];
  bool isLoading = true;
  bool isSubmitting = false;
  String entriesValue = "10";
  String searchQuery = "";

  // Form State
  int? editingDatabaseId;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String? selectedRoleId;

  @override
  void initState() {
    super.initState();
    fetchUserList();
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ──────────────────────────── API CALLS ────────────────────────────────────

  Future<void> fetchUserList() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final response = await http
          .post(
            Uri.parse('https://display.sriher.com/Registerview'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"api_key": _apiKey}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        final payload = res is Map && res.containsKey('data') ? res['data'] : res;
        setState(() {
          allUsers = (payload['users'] ?? payload['data'] ?? []) as List;
          allRoles = (payload['roles'] ?? []) as List;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnack("Failed to load users. Check connection.", isError: true);
    }
  }

  Future<void> loadForEdit(dynamic user) async {
    final id = int.tryParse(user['id']?.toString() ?? '');
    if (id == null) return;

    try {
      final response = await http
          .post(
            Uri.parse('https://display.sriher.com/regEditview'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"api_key": _apiKey, "id": id}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        final payload = res is Map && res.containsKey('data') ? res['data'] : res;
        final u = (payload is List && payload.isNotEmpty) ? payload[0] : payload;
        
        editingDatabaseId = id;
        _userIdController.text = u['user_id']?.toString() ?? user['user_id']?.toString() ?? '';
        _userNameController.text = u['user_name']?.toString() ?? user['user_name']?.toString() ?? '';
        _passwordController.text = '';
        selectedRoleId = u['role_id']?.toString() ?? user['role_id']?.toString();
        
        _showFormDialog(); 
      }
    } catch (e) {
      editingDatabaseId = id;
      _userIdController.text = user['user_id']?.toString() ?? '';
      _userNameController.text = user['user_name']?.toString() ?? '';
      selectedRoleId = user['role_id']?.toString();
      _showFormDialog();
    }
  }

  Future<void> handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);

    final bool isUpdating = editingDatabaseId != null;
    final url = isUpdating
        ? 'https://display.sriher.com/regUpdateview'
        : 'https://display.sriher.com/insertRegisterview';

    final Map<String, dynamic> body = {
      "api_key": _apiKey,
      "user_id": _userIdController.text.trim(),
      "user_name": _userNameController.text.trim(),
      "user_password": _passwordController.text.trim(),
      "role_id": selectedRoleId ?? "1",
    };
    if (isUpdating) body["id"] = editingDatabaseId;

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _showSnack(isUpdating ? "User updated successfully!" : "User added successfully!");
        _resetForm();
        fetchUserList();
      } else {
        _showSnack("Server error (${response.statusCode}). Try again.", isError: true);
      }
    } catch (e) {
      _showSnack("Connection failed. Check network.", isError: true);
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> toggleStatus(dynamic user, bool newStatus) async {
    final id = int.tryParse(user['id']?.toString() ?? '');
    if (id == null) return;

    setState(() {
      final idx = allUsers.indexWhere((u) => u['id']?.toString() == user['id']?.toString());
      if (idx != -1) allUsers[idx] = {...allUsers[idx], 'status': newStatus ? 1 : 0};
    });

    try {
      await http
          .post(
            Uri.parse('https://display.sriher.com/regUpdateview'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "api_key": _apiKey,
              "device_id": id,
              "status": newStatus ? 1 : 0,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      setState(() {
        final idx = allUsers.indexWhere((u) => u['id']?.toString() == user['id']?.toString());
        if (idx != -1) allUsers[idx] = {...allUsers[idx], 'status': newStatus ? 0 : 1};
      });
      _showSnack("Failed to update status.", isError: true);
    }
  }

  void _resetForm() {
    setState(() {
      editingDatabaseId = null;
      _userIdController.clear();
      _userNameController.clear();
      _passwordController.clear();
      selectedRoleId = null;
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
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

  void _showFormDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              titlePadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D47A1),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12), 
                    topRight: Radius.circular(12)
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      editingDatabaseId == null ? "Add New User" : "Edit User Details",
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 18, 
                        fontWeight: FontWeight.bold
                      ),
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
                width: 450,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 25),
                      _buildInput("User ID", _userIdController,
                          validator: (v) => (v == null || v.trim().isEmpty) ? "Enter user id" : null),
                      const SizedBox(height: 20),
                      _buildInput("User Name", _userNameController,
                          validator: (v) => (v == null || v.trim().isEmpty) ? "Enter user name" : null),
                      const SizedBox(height: 20),
                      _buildInput("Password", _passwordController,
                          isPass: true,
                          validator: (v) {
                            if (editingDatabaseId != null) return null;
                            if (v == null || v.trim().isEmpty) return "Enter password";
                            return null;
                          }),
                      const SizedBox(height: 20),
                      _buildRoleDrop(),
                      const SizedBox(height: 15),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                OutlinedButton(
                  onPressed: () {
                    _resetForm();
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000000),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: isSubmitting ? null : () async {
                    setDialogState(() => isSubmitting = true);
                    await handleSubmit();
                    if (mounted) Navigator.pop(context);
                  },
                  child: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(editingDatabaseId == null ? "Save User" : "Update User"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ──────────────────────────── BUILD ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final int limit = int.parse(entriesValue);
    final List<dynamic> filtered = searchQuery.isEmpty
        ? allUsers
        : allUsers.where((u) {
            final q = searchQuery.toLowerCase();
            return (u['user_id']?.toString().toLowerCase().contains(q) ?? false) ||
                (u['user_name']?.toString().toLowerCase().contains(q) ?? false);
          }).toList();
    final List<dynamic> pagedUsers = filtered.take(limit).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          color: const Color(0xFF000000), 
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "User Management",
                          style: TextStyle(
                            color: Colors.white, 
                            fontWeight: FontWeight.bold, 
                            fontSize: 26
                          ),
                        ),
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
                      onPressed: _showFormDialog,
                      icon: const Icon(Icons.person_add_alt_1, size: 20),
                      label: const Text("ADD NEW USER", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                Card(
                  color: Colors.white,
                  elevation: 5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildListHeader(),
                        const SizedBox(height: 20),
                        _buildTableContainer(constraints, pagedUsers),
                        const SizedBox(height: 20),
                        _buildPagination(pagedUsers.length, filtered.length),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ──────────────────────────── UI COMPONENTS ────────────────────────────────

  Widget _buildTableContainer(BoxConstraints constraints, List<dynamic> pagedUsers) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: isLoading
          ? const SizedBox(height: 400, child: Center(child: CircularProgressIndicator()))
          : pagedUsers.isEmpty
              ? const SizedBox(height: 400, child: Center(child: Text("No users found.", style: TextStyle(fontSize: 16))))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth - 88),
                    child: DataTable(
                      columnSpacing: 24,
                      headingRowHeight: 56,
                      dataRowMaxHeight: 60,
                      headingRowColor: WidgetStateProperty.all(const Color(0xFF000000)), // BLACK HEADER
                      showCheckboxColumn: false,
                      columns: _buildColumns(),
                      rows: pagedUsers.map((u) => _buildRow(u)).toList(),
                    ),
                  ),
                ),
    );
  }

  Widget _buildInput(String hint, TextEditingController c, {bool isPass = false, String? Function(String?)? validator}) {
    return TextFormField(
      controller: c,
      obscureText: isPass,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: Colors.black45),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), 
          borderSide: BorderSide(color: Colors.grey.shade300)
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), 
          borderSide: BorderSide(color: Colors.grey.shade300)
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
    );
  }

  Widget _buildRoleDrop() {
    return DropdownButtonFormField<String>(
      value: selectedRoleId,
      style: const TextStyle(fontSize: 14, color: Colors.black),
      decoration: InputDecoration(
        hintText: "Select Role",
        hintStyle: const TextStyle(fontSize: 14, color: Colors.black45),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), 
          borderSide: BorderSide(color: Colors.grey.shade300)
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
      items: allRoles.map((r) => DropdownMenuItem(
        value: r['id'].toString(), 
        child: Text(r['role_name'] ?? '', style: const TextStyle(color: Colors.black))
      )).toList(),
      onChanged: (v) => setState(() => selectedRoleId = v),
    );
  }

  List<DataColumn> _buildColumns() {
    return ["USER ID", "USER NAME", "ROLE", "EDIT", "ACTION"].map((c) => DataColumn(
      label: Text(c, style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.bold, fontSize: 13)), // WHITE TEXT
    )).toList();
  }

  DataRow _buildRow(dynamic u) {
    final roleName = allRoles.firstWhere(
      (r) => r['id']?.toString() == u['role_id']?.toString(),
      orElse: () => {'role_name': 'User'},
    )['role_name'] ?? 'User';

    final isActive = (u['status'] == 1 || u['status'] == '1');

    return DataRow(cells: [
      DataCell(Text(u['user_id']?.toString() ?? "-", style: const TextStyle(fontWeight: FontWeight.w500))),
      DataCell(Text(u['user_name']?.toString() ?? "-")),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
        child: Text(roleName.toString(), style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.bold)),
      )),
      DataCell(
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
          onPressed: () => loadForEdit(u),
          tooltip: "Edit User",
        ),
      ),
      DataCell(
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: isActive,
            activeColor: Colors.green,
            onChanged: (v) => toggleStatus(u, v),
          ),
        ),
      ),
    ]);
  }

  Widget _buildListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          const Text("Show ", style: TextStyle(fontSize: 14)),
          // STYLED ENTRIES BOX
          Container(
            width: 70,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: entriesValue,
                isExpanded: true,
                style: const TextStyle(fontSize: 14, color: Colors.black),
                items: ["10", "25", "50"].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setState(() => entriesValue = v!),
              ),
            ),
          ),
          const Text(" entries", style: TextStyle(fontSize: 14)),
        ]),
        SizedBox(
          width: 250,
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => searchQuery = v),
            decoration: InputDecoration(
              hintText: "Search ID or Name...",
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPagination(int showing, int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Showing 1 to $showing of $total entries", style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Row(children: [
          _buildPageBtn("Previous", enabled: false),
          _buildPageBtn("1", active: true),
          _buildPageBtn("Next", enabled: true),
        ]),
      ],
    );
  }

  Widget _buildPageBtn(String t, {bool active = false, bool enabled = true}) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: active ? const Color(0xFF000000) : Colors.white,
          foregroundColor: active ? Colors.white : Colors.black87,
          elevation: 0,
          side: BorderSide(color: Colors.grey.shade300),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        onPressed: enabled ? () {} : null,
        child: Text(t, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}