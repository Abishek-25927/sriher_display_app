import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT PANEL: Selection & Available Files
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Select Templates",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Card(
                    color: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          _buildFormRow(
                            context,
                            "--Please Select a Template Name--",
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
                          const SizedBox(height: 15),
                          _buildFormRow(
                            context,
                            "Please Select Department Name",
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
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Radio<String>(
                                value: "images",
                                groupValue: fileType,
                                onChanged: (v) => setState(() => fileType = v!),
                              ),
                              const Text(
                                "Images",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Radio<String>(
                                value: "videos",
                                groupValue: fileType,
                                onChanged: (v) => setState(() => fileType = v!),
                              ),
                              const Text(
                                "Videos",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isSelectionComplete && fileType != null)
                    Expanded(child: _buildAvailableFilesTable()),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          // RIGHT PANEL: Selection List (Assigned)
          Expanded(
            flex: 5,
            child: isSelectionComplete
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFF000000),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "SELECTION LIST",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Card(
                            margin: EdgeInsets.zero,
                            color: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(8),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () =>
                                          _showPlayOrderDialog(context),
                                      child: const Text("Change Play Order"),
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  _buildListHeader(),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: isLoadingAssignedFiles
                                        ? const Center(
                                            child: CircularProgressIndicator(),
                                          )
                                        : _buildAssignedDataTable(),
                                  ),
                                  _buildPaginationFooter(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
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
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
          color: const Color(0xFF000000),
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
        Expanded(
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                if (isLoadingAvailableFiles)
                  const LinearProgressIndicator()
                else if (paginated.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Text(
                          "No files available for this selection",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: paginated.length,
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemBuilder: (c, i) {
                        final file = paginated[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 10,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Container(
                                  width: 45,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Image.network(
                                    "$_baseUrl/uploads/${file['file_name']}",
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                    filterQuality: FilterQuality.medium,
                                    cacheWidth: 100,
                                    errorBuilder: (c, e, s) => const Icon(
                                      Icons.broken_image,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 6,
                                child: Text(
                                  file['user_filename'] ??
                                      file['file_name'] ??
                                      '',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Center(
                                  child: SizedBox(
                                    width: 80,
                                    height: 30,
                                    child: TextField(
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 12),
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.zero,
                                        hintText: "00 : 30",
                                      ),
                                      controller: TextEditingController(
                                        text: "00 : 30",
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF000000),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                    ),
                                    onPressed: () => _assignFile(
                                      int.parse(file['id'].toString()),
                                      "30",
                                    ),
                                    child: const Text(
                                      "ADD",
                                      style: TextStyle(fontSize: 11),
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
            ),
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

    final int total = filtered.length;
    final int start = (currentPage - 1) * entriesValue;
    final int end = (start + entriesValue < total)
        ? start + entriesValue
        : total;
    final paginated = (start < total) ? filtered.sublist(start, end) : [];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: const BoxDecoration(color: Color(0xFF000000)),
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
        Expanded(
          child: paginated.isEmpty
              ? const Center(
                  child: Text(
                    "No files selected",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                )
              : ListView.separated(
                  itemCount: paginated.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    final file = paginated[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 6,
                            child: Text(
                              file['user_filename'] ?? file['file_name'] ?? '-',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Row(
                              children: [
                                Container(
                                  width: 45,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Image.network(
                                    "$_baseUrl/uploads/${file['file_name']}",
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                    filterQuality: FilterQuality.medium,
                                    cacheWidth: 100,
                                    errorBuilder: (c, e, s) => const Icon(
                                      Icons.broken_image,
                                      size: 20,
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
                              style: const TextStyle(fontSize: 12),
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

  TextStyle _headerStyle() => const TextStyle(
    color: Colors.white,
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
            value:
                items.any(
                  (i) => (int.tryParse(i['id'].toString()) ?? -1) == value,
                )
                ? value
                : null,
            hint: Text(hint, style: const TextStyle(fontSize: 13)),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10),
            ),
            items: items
                .map(
                  (e) => DropdownMenuItem<int>(
                    value: int.tryParse(e['id'].toString()),
                    child: Text(
                      e['temp_name'] ?? e['category_name'] ?? '',
                      style: const TextStyle(fontSize: 13),
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
          icon: const Icon(Icons.add_circle, color: Color(0xFF000000)),
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
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Container(
              height: 35,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButton<int>(
                value: entriesValue,
                items: [10, 25, 50, 100]
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text("$e", style: const TextStyle(fontSize: 12)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  entriesValue = v!;
                  currentPage = 1;
                }),
                underline: const SizedBox(),
              ),
            ),
            const Text(
              " entries",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SizedBox(
          width: 130,
          height: 35,
          child: TextField(
            onChanged: (v) => setState(() => searchQuery = v),
            decoration: const InputDecoration(
              hintText: "Search...",
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaginationFooter() {
    final int total = assignedFiles.length;
    final int start = (currentPage - 1) * entriesValue + 1;
    final int end = (start + entriesValue - 1 < total)
        ? start + entriesValue - 1
        : total;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Showing ${total == 0 ? 0 : start} to $end of $total entries",
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              _buildSquarePageBtn(
                "Previous",
                currentPage > 1,
                () => setState(() => currentPage--),
              ),
              ..._buildPageNumbers(total),
              _buildSquarePageBtn(
                "Next",
                end < total,
                () => setState(() => currentPage++),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers(int total) {
    List<Widget> widgets = [];
    int totalPages = (total / entriesValue).ceil();
    if (totalPages <= 1)
      return [_buildSquarePageBtn("1", false, null, isActive: true)];

    for (int i = 1; i <= totalPages; i++) {
      if (i == 1 ||
          i == totalPages ||
          (i >= currentPage - 1 && i <= currentPage + 1)) {
        widgets.add(
          _buildSquarePageBtn(
            "$i",
            true,
            () => setState(() => currentPage = i),
            isActive: currentPage == i,
          ),
        );
      } else if (i == currentPage - 2 || i == currentPage + 2) {
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

  Widget _buildSquarePageBtn(
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
              ? const Color(0xFF000000)
              : (enabled ? Colors.white : Colors.grey.shade100),
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? Colors.white
                : (enabled ? Colors.black : Colors.grey),
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
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
                        color: Color(0xFF000000),
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
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
                            backgroundColor: const Color(0xFF000000),
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
