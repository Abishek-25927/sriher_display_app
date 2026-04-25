import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../widgets/animated_heading.dart';

class DefaultTemplateView extends StatefulWidget {
  const DefaultTemplateView({super.key});

  @override
  State<DefaultTemplateView> createState() => _DefaultTemplateViewState();
}

class _DefaultTemplateViewState extends State<DefaultTemplateView> {
  // ──────────────────────────────────────────────────────────────────────────
  // CONFIGURATION
  // ──────────────────────────────────────────────────────────────────────────
  final String _baseUrl = "https://display.sriher.com";
  final String _apiKey =
      "933cdb13cb54e31e694f82bf7f75f0144a9495036db0243b85dd855be53c06f2";

  // Data Lists
  List<dynamic> _templateList = []; // For the Table
  List<dynamic> _deviceDropdownList = []; // From /deviceview
  List<dynamic> _templateDropdownList = []; // From /new_templateview

  // Form State
  String? _selectedDeviceId;
  String? _selectedCategoryId;
  int? _editingId;
  bool _isLoading = false;
  bool _isSubmitting = false;

  // Table State
  String _entriesValue = "10";
  String _searchQuery = "";
  int _currentPage = 1;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
    _fetchTableData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // API METHODS
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _fetchDropdownData() async {
    try {
      // 1. Fetch Device Types
      final resDevice = await http.post(
        Uri.parse('$_baseUrl/deviceview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"api_key": _apiKey}),
      );
      // 2. Fetch Template Names
      final resTemplate = await http.post(
        Uri.parse('$_baseUrl/new_templateview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"api_key": _apiKey}),
      );

      if (mounted) {
        setState(() {
          final devParsed = jsonDecode(resDevice.body)['data'];
          if (devParsed is Map) {
            _deviceDropdownList =
                devParsed['DeviceMasters'] ?? devParsed.values.first ?? [];
          } else {
            _deviceDropdownList = devParsed ?? [];
          }

          final tempParsed = jsonDecode(resTemplate.body)['data'];
          if (tempParsed is Map) {
            _templateDropdownList = tempParsed.values.first ?? [];
          } else {
            _templateDropdownList = tempParsed ?? [];
          }
        });
      }
    } catch (e) {
      _showSnackBar("Error loading dropdowns: $e");
    }
  }

  Future<void> _fetchTableData() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/new_templateview'), // Reusing this for the list
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"api_key": _apiKey}),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final dataField = decoded['data'];
        setState(() {
          if (dataField is List) {
            _templateList = dataField;
          } else if (dataField is Map) {
            _templateList = dataField.values.first ?? [];
          } else {
            _templateList = [];
          }
        });
      }
    } catch (e) {
      _showSnackBar("Sync Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitAction() async {
    if (_selectedDeviceId == null || _selectedCategoryId == null) {
      _showSnackBar("Please select both Device Type and Template Name");
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // Find the name of the selected device to send as device_name
      final selectedDevice = _deviceDropdownList.firstWhere(
        (element) => element['id'].toString() == _selectedDeviceId,
        orElse: () => {},
      );
      final String deviceName = selectedDevice['device_name'] ?? "Unknown";

      // Find the name of the selected template to send as template_name
      final selectedTemplate = _templateDropdownList.firstWhere(
        (element) => element['id'].toString() == _selectedCategoryId,
        orElse: () => {},
      );
      final String templateName = selectedTemplate['temp_name'] ?? "Unknown";

      final url = _editingId == null
          ? '/insertNew_templateview'
          : '/new_templateUpdateview';
      Map<String, dynamic> body = {
        "api_key": _apiKey,
        "device_name": deviceName,
        "template_name": templateName,
      };
      if (_editingId != null) body["id"] = _editingId!;

      final response = await http.post(
        Uri.parse('$_baseUrl$url'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        _showSnackBar(
          _editingId == null ? "Saved successfully" : "Updated successfully",
        );
        _resetForm();
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        _fetchTableData();
      }
    } catch (e) {
      _showSnackBar("Action failed: $e");
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteItem(dynamic id) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/deleteNew_templateview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"api_key": _apiKey, "id": id}),
      );
      if (response.statusCode == 200) {
        _showSnackBar("Item Deleted");
        _fetchTableData();
      }
    } catch (e) {
      _showSnackBar("Delete failed");
    }
  }

  Future<void> _toggleStatus(dynamic id, dynamic currentStatus) async {
    try {
      final int newStatus = (currentStatus == 1 || currentStatus == "1")
          ? 0
          : 1;
      await http.post(
        Uri.parse('$_baseUrl/new_templateStatusUpdateview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"api_key": _apiKey, "id": id, "status": newStatus}),
      );
      _fetchTableData();
    } catch (e) {
      debugPrint("Status error: $e");
    }
  }

  void _editItem(dynamic item) {
    setState(() {
      _editingId = int.tryParse(item['id'].toString());
      // Logic to pre-select based on existing name if possible
      _selectedDeviceId = _deviceDropdownList
          .firstWhere(
            (d) => d['device_name'] == item['device_name'],
            orElse: () => {'id': null},
          )['id']
          ?.toString();
      _selectedCategoryId = _templateDropdownList
          .firstWhere(
            (t) => t['temp_name'] == item['temp_name'],
            orElse: () => {'id': null},
          )['id']
          ?.toString();
    });
    _showDefaultTemplateDialog(); // Open dialog after setting state
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _selectedDeviceId = null;
      _selectedCategoryId = null;
    });
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // POPUP DIALOG
  // ──────────────────────────────────────────────────────────────────────────

  void _showDefaultTemplateDialog() {
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
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _editingId == null
                          ? "Create Default Template"
                          : "Edit Default Template",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        _resetForm();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDropdown(
                      _selectedDeviceId,
                      _deviceDropdownList,
                      "id",
                      "device_name",
                      "Select Device Type",
                      (val) {
                        setDialogState(() => _selectedDeviceId = val);
                        setState(() => _selectedDeviceId = val);
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildDropdown(
                      _selectedCategoryId,
                      _templateDropdownList,
                      "id",
                      "temp_name",
                      "Select Template Name",
                      (val) {
                        setDialogState(() => _selectedCategoryId = val);
                        setState(() => _selectedCategoryId = val);
                      },
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade600,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          child: const Text("CANCEL"),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _isSubmitting ? null : _submitAction,
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _editingId == null
                                      ? 'SUBMIT'
                                      : 'UPDATE RECORD',
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // UI BUILDERS
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
                  text: "Default Templates",
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showDefaultTemplateDialog,
                  icon: const Icon(Icons.settings_applications, size: 20),
                  label: const Text(
                    "CREATE DEFAULT TEMPLATE",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
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
                padding: const EdgeInsets.all(16.0),
                child: _buildRightListContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightListContent() {
    List<dynamic> filtered = _templateList.where((item) {
      final name = (item['temp_name'] ?? "").toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    filtered.sort(
      (a, b) => (int.tryParse(b['id'].toString()) ?? 0).compareTo(
        int.tryParse(a['id'].toString()) ?? 0,
      ),
    );

    final int perPage = int.tryParse(_entriesValue) ?? 10;
    final int startIdx = (_currentPage - 1) * perPage;
    final paginated = filtered.skip(startIdx).take(perPage).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTableControls(),
        const SizedBox(height: 15),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                if (_isLoading)
                  const LinearProgressIndicator(color: Colors.blue),
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
                              columns: [
                                _buildTableCol('Device Name'),
                                _buildTableCol('Template Name'),
                                _buildTableCol('Edit'),
                              ],
                              rows: paginated.map((item) {
                                final devId =
                                    item['device_id']?.toString() ??
                                    item['id']?.toString();
                                String? resolvedName;

                                // 1. Try Lookup from master list first if ID is available
                                if (devId != null) {
                                  final dev = _deviceDropdownList.firstWhere(
                                    (d) =>
                                        d['id'].toString() == devId ||
                                        d['device_id']?.toString() == devId,
                                    orElse: () => null,
                                  );
                                  if (dev != null) {
                                    resolvedName =
                                        dev['device_name'] ??
                                        dev['device_code'];
                                  }
                                }

                                // 2. Fallback to item's own fields if lookup failed or no ID
                                resolvedName ??=
                                    item['device_name'] ??
                                    item['Device_name'] ??
                                    item['device_code'] ??
                                    "-";

                                return DataRow(
                                  cells: [
                                    DataCell(Text(resolvedName ?? "-")),
                                    DataCell(Text(item['temp_name'] ?? "-")),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                          size: 20,
                                        ),
                                        onPressed: () => _editItem(item),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
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
        _buildTableFooter(filtered.length),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // WIDGET HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildLabel(String text, {Color color = Colors.black87}) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(
      text,
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
    ),
  );

  Widget _buildDropdown(
    String? value,
    List<dynamic> items,
    String idKey,
    String nameKey,
    String hint,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          dropdownColor: Colors.white,
          value: items.any((i) => i[idKey].toString() == value) ? value : null,
          hint: Text(
            hint,
            style: const TextStyle(fontSize: 13, color: Colors.black45),
          ),
          style: const TextStyle(color: Colors.black87),
          menuMaxHeight: 300,
          alignment:
              AlignmentDirectional.topStart, // Helps keep menu below the button
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item[idKey].toString(),
              child: Text(
                item[nameKey] ?? "",
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTableControls() {
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
                value: _entriesValue,
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
                  _entriesValue = v!;
                  _currentPage = 1;
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
            onChanged: (v) => setState(() {
              _searchQuery = v;
              _currentPage = 1;
            }),
            style: const TextStyle(color: Colors.black87, fontSize: 13),
            decoration: InputDecoration(
              hintText: "Search devices...",
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

  DataColumn _buildTableCol(String label) => DataColumn(
    label: Text(
      label,
      style: TextStyle(
        color: Colors.blue.shade800,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    ),
  );

  Widget _buildTableFooter(int total) {
    final int perPage = int.tryParse(_entriesValue) ?? 10;
    final int start = (_currentPage - 1) * perPage + 1;
    final int end = (start + perPage - 1 < total) ? start + perPage - 1 : total;

    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Showing ${total == 0 ? 0 : start} to $end of $total entries",
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          Row(
            children: [
              _buildSquareBtn(
                "Previous",
                _currentPage > 1,
                () => setState(() => _currentPage--),
              ),
              ..._buildPageNumbers(total, perPage),
              _buildSquareBtn(
                "Next",
                end < total,
                () => setState(() => _currentPage++),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers(int total, int perPage) {
    List<Widget> widgets = [];
    int totalPages = (total / perPage).ceil();
    if (totalPages <= 1)
      return [_buildSquareBtn("1", false, null, isActive: true)];

    for (int i = 1; i <= totalPages; i++) {
      if (i == 1 ||
          i == totalPages ||
          (i >= _currentPage - 1 && i <= _currentPage + 1)) {
        widgets.add(
          _buildSquareBtn(
            "$i",
            true,
            () => setState(() => _currentPage = i),
            isActive: _currentPage == i,
          ),
        );
      } else if (i == _currentPage - 2 || i == _currentPage + 2) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text("...", style: TextStyle(fontSize: 11)),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _buildSquareBtn(
    String label,
    bool enabled,
    VoidCallback? onTap, {
    bool isActive = false,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: EdgeInsets.symmetric(
          horizontal: label.length > 2 ? 8 : 4,
          vertical: 4,
        ),
        constraints: const BoxConstraints(minWidth: 30),
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.blue
              : (enabled ? Colors.white : Colors.grey.shade50),
          border: Border.all(
            color: isActive ? Colors.blue : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? Colors.white
                : (enabled ? Colors.black87 : Colors.black26),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
