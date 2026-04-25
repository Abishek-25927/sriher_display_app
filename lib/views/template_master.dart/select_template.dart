import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../widgets/animated_heading.dart';

class SelectTemplateView extends StatefulWidget {
  const SelectTemplateView({super.key});

  @override
  State<SelectTemplateView> createState() => _SelectTemplateViewState();
}

class _SelectTemplateViewState extends State<SelectTemplateView> {
  int entriesValue = 10;
  int currentPage = 1;
  int availableEntriesValue = 10;
  int availableCurrentPage = 1;
  String searchQuery = "";
  int? selectedTemplateId;
  int? selectedCategoryId;
  String? fileType;

  final String _baseUrl = "https://display.sriher.com";
  final String _apiKey =
      "933cdb13cb54e31e694f82bf7f75f0144a9495036db0243b85dd855be53c06f2";

  List<dynamic> templates = [];
  List<dynamic> categories = [];
  List<dynamic> availableFiles = [];
  List<dynamic> assignedFiles = [];

  bool isLoadingTemplates = false;
  bool isLoadingCategories = false;
  bool isLoadingAvailableFiles = false;
  bool isLoadingAssignedFiles = false;

  final TextEditingController _durationController = TextEditingController(
    text: "10",
  );
  final TextEditingController _popupNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTemplates();
    _fetchCategories();
  }

  @override
  void dispose() {
    _durationController.dispose();
    _popupNameController.dispose();
    super.dispose();
  }

  bool get isSelectionComplete =>
      selectedTemplateId != null && selectedCategoryId != null;

  // ──────────────────────────────────────────────────────────────────────────
  // API CALLS
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _fetchTemplates() async {
    if (!mounted) return;
    setState(() => isLoadingTemplates = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/new_templateview'),
        body: jsonEncode({"api_key": _apiKey}),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => templates = data['data'] ?? []);
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => isLoadingTemplates = false);
    }
  }

  Future<void> _fetchCategories() async {
    if (!mounted) return;
    setState(() => isLoadingCategories = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/categoryview'),
        body: jsonEncode({"api_key": _apiKey}),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => categories = data['data'] ?? []);
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => isLoadingCategories = false);
    }
  }

  Future<void> _fetchAvailableFiles() async {
    if (selectedTemplateId == null || selectedCategoryId == null) return;
    if (!mounted) return;
    setState(() => isLoadingAvailableFiles = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/selectTemplate_availableFilesview'),
        body: jsonEncode({
          "api_key": _apiKey,
          "template_id": selectedTemplateId,
          "category_id": selectedCategoryId,
        }),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => availableFiles = data['data'] ?? []);
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => isLoadingAvailableFiles = false);
    }
  }

  Future<void> _fetchAssignedFiles() async {
    if (selectedTemplateId == null) return;
    if (!mounted) return;
    setState(() => isLoadingAssignedFiles = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/selectTemplate_filesview'),
        body: jsonEncode({
          "api_key": _apiKey,
          "template_id": selectedTemplateId,
        }),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => assignedFiles = data['data'] ?? []);
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => isLoadingAssignedFiles = false);
    }
  }

  Future<void> _assignFile(int fileId, String duration) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/selectTemplate_assignFileview'),
        body: jsonEncode({
          "api_key": _apiKey,
          "template_id": selectedTemplateId,
          "file_id": fileId,
          "duration": int.tryParse(duration) ?? 10,
        }),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) _fetchAssignedFiles();
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _removeFile(int fileId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/selectTemplate_removeFileview'),
        body: jsonEncode({
          "api_key": _apiKey,
          "template_id": selectedTemplateId,
          "file_id": fileId,
        }),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) _fetchAssignedFiles();
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _updatePlayOrder() async {
    if (selectedTemplateId == null || assignedFiles.isEmpty) return;
    try {
      final fileIds = assignedFiles
          .map((f) => int.tryParse(f['id'].toString()) ?? 0)
          .toList();
      final response = await http.post(
        Uri.parse('$_baseUrl/selectTemplate_updatePlayOrderview'),
        body: jsonEncode({
          "api_key": _apiKey,
          "template_id": selectedTemplateId,
          "file_ids": fileIds,
        }),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Order Updated")));
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // UI BUILDERS
  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT PANEL: Configuration Card Alone
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: Colors.blue.shade50),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AnimatedHeading(text: "TEMPLATE CONFIGURATION"),
                          const SizedBox(height: 32),
                          _buildFormRow(
                            context,
                            "--Select Template Name--",
                            selectedTemplateId,
                            "Template",
                            templates,
                            (v) {
                              setState(() {
                                selectedTemplateId = v;
                                availableFiles.clear();
                                assignedFiles.clear();
                              });
                              if (v != null) {
                                _fetchAssignedFiles();
                                _fetchAvailableFiles();
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                          _buildFormRow(
                            context,
                            "--Select Department Name--",
                            selectedCategoryId,
                            "Department",
                            categories,
                            (v) {
                              setState(() {
                                selectedCategoryId = v;
                                availableFiles.clear();
                              });
                              if (v != null) _fetchAvailableFiles();
                            },
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "FILE TYPE",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.1,
                              color: Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: "images",
                                  groupValue: fileType,
                                  activeColor: Colors.blue,
                                  onChanged: (v) =>
                                      setState(() => fileType = v!),
                                ),
                                const Text(
                                  "Images",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Radio<String>(
                                  value: "videos",
                                  groupValue: fileType,
                                  activeColor: Colors.blue,
                                  onChanged: (v) =>
                                      setState(() => fileType = v!),
                                ),
                                const Text(
                                  "Videos",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelectionComplete && fileType != null) ...[
                      const SizedBox(height: 32),
                      _buildAvailableFilesTable(),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 32),
            // RIGHT PANEL: Content Area (Available Files + Selection List)
            Expanded(
              flex: 5,
              child: isSelectionComplete
                  ? Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 24,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade600,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            child: const Text(
                              "CURRENT SELECTION LIST",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.sort, size: 18),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.shade50,
                                        foregroundColor: Colors.blue.shade900,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: () =>
                                          _showPlayOrderDialog(context),
                                      label: const Text(
                                        "Change Play Order",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildListHeader(),
                                  const SizedBox(height: 16),
                                  isLoadingAssignedFiles
                                      ? const Padding(
                                          padding: EdgeInsets.all(48.0),
                                          child: CircularProgressIndicator(),
                                        )
                                      : _buildAssignedDataTable(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.touch_app_outlined,
                            size: 80,
                            color: Colors.blue.shade100,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "Complete configuration to view files",
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableFilesTable() {
    final filteredFiles = availableFiles.where((f) {
      final type = f['file_type']?.toString().toLowerCase() ?? '';
      if (fileType == null) return false;
      return fileType == 'images'
          ? (type.contains('image') ||
                type == 'png' ||
                type == 'jpg' ||
                type == 'jpeg')
          : (type.contains('video') || type == 'mp4');
    }).toList();

    final int total = filteredFiles.length;
    final int start = (availableCurrentPage - 1) * availableEntriesValue;
    final int end = (start + availableEntriesValue < total)
        ? start + availableEntriesValue
        : total;
    final paginated = (start < total) ? filteredFiles.sublist(start, end) : [];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(flex: 4, child: Text("File ↕", style: _headerStyle())),
              Expanded(
                flex: 6,
                child: Text("File Name ↕", style: _headerStyle()),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  "Duration ↕",
                  textAlign: TextAlign.center,
                  style: _headerStyle(),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "Action ↕",
                  textAlign: TextAlign.right,
                  style: _headerStyle(),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoadingAvailableFiles)
                const LinearProgressIndicator()
              else if (paginated.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(48.0),
                  child: Center(
                    child: Text(
                      "No files available for this selection",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: paginated.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    final file = paginated[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade100),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(
                                "$_baseUrl/uploads/${file['file_name']}",
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (c, e, s) => const Icon(
                                  Icons.broken_image,
                                  size: 30,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file['user_filename'] ??
                                      file['file_name'] ??
                                      '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Format: ${file['file_type']?.toString().toUpperCase() ?? '-'}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Center(
                              child: Container(
                                width: 90,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: TextField(
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    hintText: "30s",
                                  ),
                                  keyboardType: TextInputType.number,
                                  controller: TextEditingController(text: "30"),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: IconButton.filled(
                                onPressed: () => _assignFile(
                                  int.parse(file['id'].toString()),
                                  "30",
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.add, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssignedDataTable() {
    final filtered = assignedFiles.where((f) {
      return (f['user_filename'] ?? f['file_name'] ?? '')
          .toString()
          .toLowerCase()
          .contains(searchQuery.toLowerCase());
    }).toList();

    final paginated = filtered; // No pagination for unlimited scroll

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 6,
                child: Text("File Name ↕", style: _headerStyle()),
              ),
              Expanded(flex: 4, child: Text("File ↕", style: _headerStyle())),
              Expanded(
                flex: 3,
                child: Text("File Type ↕", style: _headerStyle()),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "Action ↕",
                  textAlign: TextAlign.right,
                  style: _headerStyle(),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: paginated.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(48.0),
                  child: Center(
                    child: Text(
                      "No files selected",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: paginated.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    final file = paginated[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade100),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 6,
                            child: Text(
                              file['user_filename'] ?? file['file_name'] ?? '-',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.network(
                                    "$_baseUrl/uploads/${file['file_name']}",
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                    filterQuality: FilterQuality.high,
                                    errorBuilder: (c, e, s) => const Icon(
                                      Icons.broken_image,
                                      size: 24,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              file['file_type'] ?? '-',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () => _removeFile(
                                  int.parse(file['id'].toString()),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  TextStyle _headerStyle() => TextStyle(
    color: Colors.blue.shade900,
    fontWeight: FontWeight.bold,
    fontSize: 12,
  );

  Widget _buildFormRow(
    BuildContext context,
    String hint,
    int? value,
    String title,
    List<dynamic> items,
    Function(int?) onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            dropdownColor: Colors.white,
            style: const TextStyle(color: Colors.black87),
            menuMaxHeight: 300,
            alignment: AlignmentDirectional.topStart,
            value:
                items.any(
                  (i) => (int.tryParse(i['id'].toString()) ?? -1) == value,
                )
                ? value
                : null,
            hint: Text(
              hint,
              style: const TextStyle(fontSize: 13, color: Colors.black45),
            ),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 10),
            ),
            items: items
                .map(
                  (e) => DropdownMenuItem<int>(
                    value: int.tryParse(e['id'].toString()),
                    child: Text(
                      e['temp_name'] ?? e['category_name'] ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.add_circle, color: Colors.blue),
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
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
            Container(
              height: 35,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: entriesValue,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Colors.black87, fontSize: 11),
                  items: [10, 25, 50]
                      .map((v) => DropdownMenuItem(value: v, child: Text("$v")))
                      .toList(),
                  onChanged: (v) => setState(() {
                    entriesValue = v!;
                    currentPage = 1;
                  }),
                ),
              ),
            ),
            const Text(
              " entries",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        SizedBox(
          width: 150,
          height: 35,
          child: TextField(
            style: const TextStyle(color: Colors.black87, fontSize: 11),
            decoration: InputDecoration(
              hintText: "Search...",
              hintStyle: const TextStyle(color: Colors.black38),
              border: const OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 16,
                color: Colors.blue,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 10),
            ),
            onChanged: (v) => setState(() {
              searchQuery = v;
              currentPage = 1;
            }),
          ),
        ),
      ],
    );
  }

  void _showPlayOrderDialog(BuildContext context) {
    final ScrollController scrollController = ScrollController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.9,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      "Change Play Order",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: assignedFiles.isEmpty
                          ? const Center(
                              child: Text(
                                "No files assigned",
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ReorderableListView.builder(
                              physics: const BouncingScrollPhysics(),
                              scrollController: scrollController,
                              itemCount: assignedFiles.length,
                              onReorder: (oldIndex, newIndex) {
                                if (newIndex > oldIndex) newIndex -= 1;
                                setState(() {
                                  final item = assignedFiles.removeAt(oldIndex);
                                  assignedFiles.insert(newIndex, item);
                                });
                                setDialogState(() {});
                              },
                              itemBuilder: (context, index) {
                                final file = assignedFiles[index];
                                return Card(
                                  key: ValueKey(file['id'] ?? index),
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    leading: Container(
                                      width: 60,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.network(
                                          "$_baseUrl/uploads/${file['file_name']}",
                                          fit: BoxFit.cover,
                                          gaplessPlayback: true,
                                          filterQuality: FilterQuality.medium,
                                          errorBuilder: (c, e, s) => const Icon(
                                            Icons.broken_image,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      file['user_filename'] ??
                                          file['file_name'] ??
                                          '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: Text(
                                      file['file_type'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    trailing: const Icon(
                                      Icons.drag_handle,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                              },
                            ),
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
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () {
                            _updatePlayOrder();
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "UPDATE",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 15),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "CLOSE",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 15),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () {
                            scrollController.animateTo(
                              0,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: const Text(
                            "TOP",
                            style: TextStyle(fontWeight: FontWeight.bold),
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
}
