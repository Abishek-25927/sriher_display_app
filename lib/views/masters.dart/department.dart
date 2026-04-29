import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../widgets/animated_heading.dart';

class DepartmentView extends StatefulWidget {
  const DepartmentView({super.key});

  @override
  State<DepartmentView> createState() => _DepartmentViewState();
}

class _DepartmentViewState extends State<DepartmentView>
    with SingleTickerProviderStateMixin {
  // --- API CONFIGURATION ---
  final String _apiKey =
      "933cdb13cb54e31e694f82bf7f75f0144a9495036db0243b85dd855be53c06f2";
  final String _baseUrl = "https://display.sriher.com";

  // --- STATE MANAGEMENT ---
  List<dynamic> categoryList = [];
  List<dynamic> filteredList = [];
  bool isLoading = true;
  String entriesValue = "10";
  int currentPage = 0;
  int? editingId;

  // --- CONTROLLERS ---
  final TextEditingController _departmentNameController =
      TextEditingController();
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
        final dynamic decoded = jsonDecode(response.body);
        setState(() {
          if (decoded is Map) {
            categoryList = decoded['data'] ?? decoded['category_list'] ?? [];
          } else if (decoded is List) {
            categoryList = decoded;
          }
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
    final String endPoint = isUpdate
        ? '/categoryUpdateview'
        : '/insertCategoryview';

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
      final int newStatus = (currentStatus == 1 || currentStatus == "1")
          ? 0
          : 1;
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
          .where(
            (item) => item['category_name'].toString().toLowerCase().contains(
              query.toLowerCase(),
            ),
          )
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              titlePadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 55, 164, 241),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (editingId == null)
                      const Text(
                        "Add Department",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      const Text(
                        "Edit Department",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Color.fromARGB(255, 245, 246, 247),
                      ),
                      onPressed: () {
                        _clearForm();
                        Navigator.pop(context);
                      },
                    ),
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
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Department Name',
                        hintStyle: const TextStyle(color: Colors.black45),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              actions: [
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.end, // Pushes everything to the right
                  children: [
                    SizedBox(
                      width:
                          250, // This controls the total width of the button group
                      child: Row(
                        children: [
                          // Both buttons use Expanded to share the 250px width equally (Flex: 1)
                          Expanded(
                            child: SizedBox(
                              height: 45,
                              child: TextButton(
                                onPressed: () {
                                  _clearForm();
                                  Navigator.pop(context);
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.red.shade600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  "Cancel",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12), // Gap between buttons

                          Expanded(
                            child: SizedBox(
                              height: 45,
                              child: ElevatedButton(
                                onPressed: handleFormSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  editingId == null ? "Submit" : "Update",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const AnimatedHeading(
                  text: "Department List",
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showDepartmentDialog,
                  icon: const Icon(Icons.add_business_rounded, size: 20),
                  label: const Text(
                    "ADD DEPARTMENT",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // List Card
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20.0),
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
                child: _buildTableCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white54, width: 1.2),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Department Name *",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _departmentNameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter Department Name',
              hintStyle: const TextStyle(color: Colors.white54),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white10,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (editingId != null)
                TextButton(
                  onPressed: _clearForm,
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ElevatedButton(
                onPressed: handleFormSubmit,
                child: Text(editingId == null ? "Submit" : "Update"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard() {
    return Column(
      children: [
        _buildListHeader(),
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
                if (isLoading)
                  const LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    color: Colors.blue,
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                            ),
                            child: DataTable(
                              headingRowHeight: 45,
                              headingRowColor: WidgetStateProperty.all(
                                Colors.blue.shade50,
                              ),
                              border: TableBorder.all(
                                color: Colors.grey.shade100,
                              ),
                              columns: _getColumns(),
                              rows: _getCurrentPageRows(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildTableFooter(),
      ],
    );
  }

  List<DataColumn> _getColumns() {
    return ['Department', 'Edit', 'Action']
        .map(
          (label) => DataColumn(
            label: Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        )
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
    return DataRow(
      cells: [
        DataCell(
          Text(
            item['category_name']?.toString() ?? "-",
            style: const TextStyle(color: Colors.black87),
          ),
        ),
        DataCell(
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 18),
            onPressed: () => loadForEdit(item['id']),
          ),
        ),
        DataCell(
          Transform.scale(
            scale: 0.7,
            child: Switch(
              value: item['status'] == 1 || item['status'] == "1",
              activeColor: Colors.greenAccent,
              onChanged: (v) => toggleStatus(item['id'], item['status']),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSetexttionLabel(String label) => Text(
    label,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
  );

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
                color: Colors.black87,
              ),
            ),
            SizedBox(
              width: 70,
              height: 35,
              child: DropdownButtonFormField<String>(
                value: entriesValue,
                dropdownColor: Colors.white,
                style: const TextStyle(color: Colors.black87, fontSize: 13),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 5),
                ),
                items: ["10", "25", "50"]
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() {
                  entriesValue = v!;
                  currentPage = 0;
                }),
              ),
            ),
            const Text(
              " entries",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        SizedBox(
          width: 250,
          height: 40,
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.black87, fontSize: 13),
            decoration: InputDecoration(
              hintText: "Search Departments...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            ),
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
        Text(
          "Total: ${filteredList.length} Departments",
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        Row(
          children: [
            GestureDetector(
              onTap: currentPage > 0
                  ? () => setState(() => currentPage--)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: currentPage > 0
                        ? Colors.blue.shade300
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  "Prev",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: currentPage > 0 ? Colors.blue.shade700 : Colors.grey,
                  ),
                ),
              ),
            ),

            Row(
              children: List.generate(totalPages, (index) {
                if (totalPages > 7) {
                  if (index != 0 &&
                      index != totalPages - 1 &&
                      (index < currentPage - 1 || index > currentPage + 1)) {
                    if (index == currentPage - 2 || index == currentPage + 2) {
                      return const Text(
                        "...",
                        style: TextStyle(color: Colors.white54),
                      );
                    }
                    return const SizedBox.shrink();
                  }
                }
                return InkWell(
                  onTap: () => setState(() => currentPage = index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: currentPage == index
                          ? Colors.blue.shade600
                          : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: currentPage == index
                            ? Colors.blue.shade600
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      "${index + 1}",
                      style: TextStyle(
                        fontSize: 12,
                        color: currentPage == index
                            ? Colors.white
                            : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
            ),

            GestureDetector(
              onTap: currentPage < totalPages - 1
                  ? () => setState(() => currentPage++)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: currentPage < totalPages - 1
                        ? Colors.blue.shade300
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  "Next",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: currentPage < totalPages - 1
                        ? Colors.blue.shade700
                        : Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
