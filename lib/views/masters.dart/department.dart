import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class DepartmentView extends StatefulWidget {
  const DepartmentView({super.key});

  @override
  State<DepartmentView> createState() => _DepartmentViewState();
}

class _DepartmentViewState extends State<DepartmentView>
    with SingleTickerProviderStateMixin {
  // --- API CONFIGURATION ---
  final String _apiKey = "933cdb13cb54e31e694f82bf7f75f0144a9495036db0243b85dd855be53c06f2";
  final String _baseUrl = "https://display.sriher.com";

  // --- STATE MANAGEMENT ---
  List<dynamic> categoryList = [];
  List<dynamic> filteredList = [];
  bool isLoading = true;
  String entriesValue = "10";
  int currentPage = 0;
  int? editingId;

  // --- CONTROLLERS ---
  final TextEditingController _departmentNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // --- ANIMATIONS ---
  late AnimationController _entryController;
  late Animation<double> _leftFade;
  late Animation<Offset> _leftSlide;
  late Animation<double> _rightFade;
  late Animation<Offset> _rightSlide;

  @override
  void initState() {
    super.initState();
    fetchCategories(); // Load data immediately
  }

  @override
  void dispose() {
    _departmentNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // --- API INTEGRATIONS (THE 5 COMMANDS) ---
  // ──────────────────────────────────────────────────────────────────────────

  // 1. FETCH LIST (categoryview)
  Future<void> fetchCategories() async {
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/categoryview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"api_key": _apiKey}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        setState(() {
          categoryList = decoded['data'] ?? decoded['category_list'] ?? [];
          filteredList = categoryList;
          isLoading = false;
        });
      }
    } catch (e) {
      _showSnackBar("Connection Error: $e");
      setState(() => isLoading = false);
    }
  }

  // 2 & 4. INSERT OR UPDATE (insertCategoryview / categoryUpdateview)
  Future<void> handleFormSubmit() async {
    if (_departmentNameController.text.isEmpty) {
      _showSnackBar("Department Name is required!");
      return;
    }

    final bool isUpdate = editingId != null;
    final String endPoint = isUpdate ? '/categoryUpdateview' : '/insertCategoryview';
    
    final Map<String, dynamic> body = {
      "api_key": _apiKey,
      "category_name": _departmentNameController.text,
    };
    if (isUpdate) body["id"] = editingId.toString();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$endPoint'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        _showSnackBar(isUpdate ? "Department Updated!" : "Department Saved!");
        _clearForm();
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        fetchCategories(); // Refresh table immediately
      }
    } catch (e) {
      _showSnackBar("Submit failed: $e");
    }
  }

  // 3. EDIT (categoryEditview)
  Future<void> loadForEdit(dynamic id) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/categoryEditview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"api_key": _apiKey, "id": id.toString()}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        setState(() {
          editingId = int.parse(id.toString());
          _departmentNameController.text = data['category_name'] ?? "";
        });
        _showDepartmentDialog(); // Open dialog after loading data
      }
    } catch (e) {
      _showSnackBar("Error loading data");
    }
  }

  // 5. TOGGLE STATUS (categoryStatusUpdateview)
  Future<void> toggleStatus(dynamic id, dynamic currentStatus) async {
    try {
      final int newStatus = (currentStatus == 1 || currentStatus == "1") ? 0 : 1;
      final response = await http.post(
        Uri.parse('$_baseUrl/categoryStatusUpdateview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "api_key": _apiKey,
          "category_id": id,
          "status": newStatus,
        }),
      );

      if (response.statusCode == 200) {
        fetchCategories();
      }
    } catch (e) {
      debugPrint("Toggle Error: $e");
    }
  }

  void _clearForm() {
    setState(() {
      editingId = null;
      _departmentNameController.clear();
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      filteredList = categoryList
          .where((item) => item['category_name']
              .toString()
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
      currentPage = 0; // Reset pagination on search
    });
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ──────────────────────────── POPUP DIALOG ────────────────────────────────

  void _showDepartmentDialog() {
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
                      editingId == null ? " Department" : "Department",
                      style: const TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        _clearForm();
                        Navigator.pop(context);
                      },
                    )
                  ],
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _departmentNameController,
                      decoration: InputDecoration(
                        hintText: 'Department Name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                OutlinedButton(
                  onPressed: () {
                    _clearForm();
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
                  onPressed: handleFormSubmit,
                  child: Text(editingId == null ? "Submit" : "Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // --- UI COMPONENTS ---
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF000000),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Area
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Department List",
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
                  onPressed: _showDepartmentDialog,
                  icon: const Icon(Icons.add_business_rounded, size: 20),
                  label: const Text("ADD DEPARTMENT",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // List Card
            Expanded(
              child: Card(
                color: Colors.white,
                elevation: 5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _buildTableCard(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Department Name *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _departmentNameController,
              decoration: InputDecoration(
                hintText: 'Enter Department Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (editingId != null)
                  TextButton(onPressed: _clearForm, child: const Text("Cancel", style: TextStyle(color: Colors.red))),
                _AnimatedSubmitButton(
                  label: editingId == null ? "Submit" : "Update",
                  onPressed: handleFormSubmit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCard() {

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 5.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11.0),
              child: _buildListHeader(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    if (isLoading) const LinearProgressIndicator(backgroundColor: Colors.transparent, color: Colors.blue),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                child: DataTable(
                                  headingRowHeight: 45,
                                  headingRowColor: WidgetStateProperty.all(const Color(0xFF000000)),
                                  columns: _getColumns(),
                                  rows: _getCurrentPageRows(),
                                ),
                              ),
                            ),
                          );
                        }
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11.0),
              child: _buildTableFooter(),
            ),
          ],
        ),
      ),
    );
  }

  List<DataColumn> _getColumns() {
    return ['Department','Edit','Action']
        .map((label) => DataColumn(
              label: Expanded(
                child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ))
        .toList();
  }

  List<DataRow> _getCurrentPageRows() {
    int rowsPerPage = int.parse(entriesValue);
    int start = currentPage * rowsPerPage;
    int end = (start + rowsPerPage < filteredList.length)
        ? (start + rowsPerPage)
        : filteredList.length;

    if (start >= filteredList.length && filteredList.isNotEmpty) {
      currentPage = (filteredList.length / rowsPerPage).floor();
      start = currentPage * rowsPerPage;
      end = filteredList.length;
    }

    return filteredList
        .sublist(start, end)
        .map((item) => _getRow(item))
        .toList();
  }

  DataRow _getRow(dynamic item) {
    return DataRow(cells: [
      DataCell(Text(item['category_name']?.toString() ?? "-")),
      DataCell(IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => loadForEdit(item['id']))),
      DataCell(
        Transform.scale(
          scale: 0.7,
          child: Switch(
            value: item['status'] == 1 || item['status'] == "1",
            activeColor: Colors.green,
            onChanged: (v) => toggleStatus(item['id'], item['status']),
          ),
        ),
      ),
    ]);
  }

  Widget _buildSetexttionLabel(String label) => Text(label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold));

  Widget _buildListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          const Text("Show ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          SizedBox(
            width: 70, height: 35,
            child: DropdownButtonFormField<String>(
              value: entriesValue,
              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 5)),
              items: ["10", "25", "50"].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() {
                entriesValue = v!;
                currentPage = 0; // Reset to first page when changing entries count
              }),
            ),
          ),
          const Text(" entries", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        ]),
        SizedBox(
          width: 140, height: 35,
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(hintText: "Search...", border: OutlineInputBorder(), prefixIcon: Icon(Icons.search, size: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildTableFooter() {
    int rowsPerPage = int.parse(entriesValue);
    int totalPages = (filteredList.length / rowsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Total: ${filteredList.length} Departments", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        Row(
          children: [
            GestureDetector(
              onTap: currentPage > 0 ? () => setState(() => currentPage--) : null,
              child: Text(
                "Prev",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: currentPage > 0 ? Colors.blue : Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 15),
            Row(
              children: List.generate(totalPages, (index) {
                // Show only a few page numbers if there are too many
                if (totalPages > 7) {
                  if (index != 0 && index != totalPages - 1 && (index < currentPage - 1 || index > currentPage + 1)) {
                    if (index == currentPage - 2 || index == currentPage + 2) {
                      return const Text("...");
                    }
                    return const SizedBox.shrink();
                  }
                }
                return InkWell(
                  onTap: () => setState(() => currentPage = index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: currentPage == index ? const Color(0xFF000000) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: currentPage == index ? const Color(0xFF000000) : Colors.grey.shade300),
                    ),
                    child: Text(
                      "${index + 1}",
                      style: TextStyle(
                        fontSize: 11,
                        color: currentPage == index ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
            ),
            
            const SizedBox(width: 15),
            GestureDetector(
              onTap: currentPage < totalPages - 1 ? () => setState(() => currentPage++) : null,
              child: Text(
                "Next",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: currentPage < totalPages - 1 ? Colors.blue : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnimatedSubmitButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _AnimatedSubmitButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40, width: 120,
      child: ElevatedButton(
        
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF000000), foregroundColor: Colors.white),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

 
