import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';


/**
 * FileUploadView - Master Module
 * * This screen manages the complete Digital Signage File Repository.
 * Features:
 * - Dynamic Department/Category selection
 * - Multipart File Upload (Image/Video)
 * - Real-time Repository Sync (Sorted Latest First)
 * - ID-based Status Toggling and Deletion
 * - Image Preview (Passport size) in Table
 */
class FileUploadView extends StatefulWidget {
  const FileUploadView({super.key});

  @override
  State<FileUploadView> createState() => _FileUploadViewState();
}

class _FileUploadViewState extends State<FileUploadView> {
  // ──────────────────────────────────────────────────────────────────────────
  // API CONFIGURATION & CREDENTIALS
  // ──────────────────────────────────────────────────────────────────────────
  final String _apiKey = "933cdb13cb54e31e694f82bf7f75f0144a9495036db0243b85dd855be53c06f2";
  final String _baseUrl = "https://display.sriher.com";

  // ──────────────────────────────────────────────────────────────────────────
  List<dynamic> fileList = [];
  List<dynamic> _deptList = []; // loaded from /categoryview
  bool isLoading = true; 
  bool isSubmitting = false;
  
  // Table Pagination & Search
  String entriesValue = "10"; 
  int currentPage = 1;        
  int? editingId;
  
  // Form Selections
  String _selectedType = "Permanent"; 
  String? _selectedDeptId;
  String? _selectedFileName;
  PlatformFile? _selectedFile;

  // ──────────────────────────────────────────────────────────────────────────
  // TEXT CONTROLLERS
  // ──────────────────────────────────────────────────────────────────────────
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeData();
    _searchController.addListener(() {
      if (mounted) setState(() => currentPage = 1);
    });
  }

  Future<void> _initializeData() async {
    await fetchDepartments(); // load departments first
    await fetchFilesFromServer();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // API 0: FETCH DEPARTMENTS from /categoryview
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> fetchDepartments() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/categoryview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"api_key": _apiKey}),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (mounted) setState(() {
          _deptList = decoded['data'] ?? decoded['category_list'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Dept fetch error: $e");
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // API 1: FETCH FILES (GET /fileview)
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> fetchFilesFromServer() async {
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/fileview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"api_key": _apiKey}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        setState(() {
          fileList = decoded['data'] ?? [];
        });
      }
    } catch (e) {
      _showSnackBar("Connectivity Error: Unable to sync with repository.");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // API 2: INSERT FILE (POST /insertFileview) — plain JSON POST
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> insertFileAction() async {
    if (_selectedDeptId == null || _nameController.text.trim().isEmpty) {
      _showSnackBar("Please select a Department and enter a File Name.");
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/insertFileview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "api_key": _apiKey,
          "category_id": int.tryParse(_selectedDeptId!) ?? int.parse(_selectedDeptId!),
          "name": _nameController.text.trim(),
          "desc": _descController.text.trim(),
          "group5": _selectedType,
          "file_duration": 25,
        }),
      );

      debugPrint("Insert response [${response.statusCode}]: ${response.body}");

      if (response.statusCode == 200) {
        _showSnackBar("File saved successfully.");
        _resetForm();
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      } else {
        _showSnackBar("Server error ${response.statusCode}: ${response.body}");
      }
      // Always refresh so latest entry shows at top
      await fetchFilesFromServer();
    } catch (e) {
      _showSnackBar("Insert failed: $e");
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }


  // ──────────────────────────────────────────────────────────────────────────
  // API 3: EDIT FETCH (POST /fileEditview)
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> editFileDetails(dynamic id) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/fileEditview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"api_key": _apiKey, "id": id.toString()}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        setState(() {
          editingId = int.parse(id.toString());
          _nameController.text = data['user_filename'] ?? "";
          _descController.text = data['description'] ?? "";
          _selectedDeptId = data['category_id']?.toString();
          _selectedType = data['type'] ?? "Permanent";
        });
        _showUploadDialog(); // Open the dialog after loading details
      }
    } catch (e) {
      _showSnackBar("Record Retrieval Failed.");
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // API 4: UPDATE FILE (POST /fileUpdateview)
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> updateFileAction() async {
    setState(() => isSubmitting = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/fileUpdateview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "api_key": _apiKey,
          "id": editingId,
          "category_id": _selectedDeptId,
          "name": _nameController.text.trim(),
          "desc": _descController.text.trim(),
          "group5": _selectedType,
        }),
      );

      if (response.statusCode == 200) {
        _showSnackBar("Record metadata updated successfully.");
        _resetForm();
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        fetchFilesFromServer();
      }
    } catch (e) {
      _showSnackBar("Update Error.");
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // API 5: STATUS TOGGLE (POST /fileStatusUpdateview)
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> toggleFileStatus(dynamic id, dynamic currentStatus) async {
    try {
      final int newStatus = (currentStatus == 1 || currentStatus == "1") ? 0 : 1;
      final response = await http.post(
        Uri.parse('$_baseUrl/fileStatusUpdateview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "api_key": _apiKey,
          "id": id,
          "status": newStatus,
        }),
      );
      if (response.statusCode == 200) fetchFilesFromServer();
    } catch (e) {
      debugPrint("Status Shift Error: $e");
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // API 6: DELETE RECORD (POST /deleteFileview)
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> deleteFileAction(dynamic id) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/deleteFileview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"api_key": _apiKey, "id": id}),
      );
      if (response.statusCode == 200) {
        _showSnackBar("Record purged from repository.");
        fetchFilesFromServer();
      }
    } catch (e) {
      _showSnackBar("Delete Protocol Failed.");
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HELPERS & DATA LOGIC
  // ──────────────────────────────────────────────────────────────────────────

  void _resetForm() {
    setState(() { 
      editingId = null; 
      _selectedDeptId = null; 
      _selectedType = "Permanent";
      _selectedFileName = null;
      _selectedFile = null;
    });
    _nameController.clear(); 
    _descController.clear();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
        _selectedFileName = result.files.first.name;
      });
    }
  }

  void _showSnackBar(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
  }

  List<dynamic> get _filteredList {
    String query = _searchController.text.toLowerCase();
    List<dynamic> sorted = List.from(fileList);
    // Descending Sort (Latest First)
    sorted.sort((a, b) => (int.tryParse(b['id'].toString()) ?? 0).compareTo(int.tryParse(a['id'].toString()) ?? 0));

    if (query.isEmpty) return sorted;
    return sorted.where((item) {
      final fileName = (item['user_filename'] ?? '').toString().toLowerCase();
      final desc = (item['description'] ?? '').toString().toLowerCase();
      return fileName.contains(query) || desc.contains(query);
    }).toList();
  }

  List<dynamic> get _pagedList {
    final filtered = _filteredList;
    final int perPage = int.tryParse(entriesValue) ?? 10;
    int start = (currentPage - 1) * perPage;
    if (start >= filtered.length) return [];
    return filtered.sublist(start, (start + perPage).clamp(0, filtered.length));
  }

  // ─── POPUP DIALOG FOR UPLOAD ───────────────────────────────────────────
  void _showUploadDialog() {
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
                      editingId == null ? "File Upload" : "Edit File Metadata",
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _buildFormCardInDialog(setDialogState),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFormCardInDialog(StateSetter setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedDeptId,
                    hint: const Text("Select Department Name"),
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                    items: _deptList.map<DropdownMenuItem<String>>((dept) {
                      return DropdownMenuItem<String>(
                        value: dept['id']?.toString(),
                        child: Text(dept['category_name']?.toString() ?? '-'),
                      );
                    }).toList(),
                    onChanged: (val) => setDialogState(() => _selectedDeptId = val),
                  ),
                  
                   
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        onPressed: () async {
                          await _pickFile();
                          setDialogState(() {});
                        },
                        icon: const Icon(Icons.upload_file),
                        label: const Text("Choose File"),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedFileName ?? "No file selected",
                          style: TextStyle(color: _selectedFileName != null ? Colors.black87 : Colors.grey, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 30),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                 
                  const SizedBox(height: 8),
                  _buildTextField("Enter reference name", _nameController),
                  const SizedBox(height: 20),
                  
                  const SizedBox(height: 8),
                  _buildTextField("Short description", _descController),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text("Type: ", style: TextStyle(fontWeight: FontWeight.bold)),
                Radio<String>(value: "Permanent", groupValue: _selectedType, onChanged: (v) => setDialogState(() => _selectedType = v!)),
                const Text("Permanent"),
                const SizedBox(width: 10),
                Radio<String>(value: "Short Term", groupValue: _selectedType, onChanged: (v) => setDialogState(() => _selectedType = v!)),
                const Text("Short Term"),
              ],
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF000000),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: isSubmitting ? null : (editingId == null ? insertFileAction : updateFileAction),
              child: isSubmitting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(editingId == null ? "Submit" : "Update"),
            ),
          ],
        ),
      ],
    );
  }

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
                    Text("Uploaded File List",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    
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
                  onPressed: _showUploadDialog,
                  icon: const Icon(Icons.cloud_upload_rounded, size: 20),
                  label: const Text("UPLOAD NEW FILE", style: TextStyle(fontWeight: FontWeight.bold,fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Repository List Card
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



  Widget _buildTableCard() {
    final paged = _pagedList;
    return Column(
      children: [
        _buildTableHeader(),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : _buildDataTable(paged),
          ),
        ),
        const SizedBox(height: 16),
        _buildTableFooter(paged),
      ],
    );
  }

  Widget _buildDataTable(List<dynamic> data) {
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
            headingRowHeight: 50,
            headingRowColor: WidgetStateProperty.all(const Color(0xFF000000)),
            columnSpacing: 20,
            columns: [
              _buildCol('ID'),
              _buildCol('IMG/VID'),
              _buildCol('FILE NAME'),
              _buildCol('DESCRIPTION'),
              _buildCol('TYPE'),
              _buildCol('VALID FROM'),
              _buildCol('VALID UPTO'),
              _buildCol('STATUS'),
              _buildCol('EDIT'),
              _buildCol('DELETE'),
            ],
            rows: data.map((item) {
              return DataRow(cells: [
                DataCell(Text(item['id']?.toString() ?? "-")),
                DataCell(
                  Container(
                    width: 40,
                    height: 50,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      color: Colors.grey.shade100,
                    ),
                    child: (item['file_name'] != null && item['file_name'].toString().isNotEmpty)
                      ? Image.network(
                          "$_baseUrl/uploads/${item['file_name']}",
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 20),
                        )
                      : const Icon(Icons.image, size: 20),
                  ),
                ),
                DataCell(Text(item['user_filename'] ?? "-")),
                DataCell(Text(item['description'] ?? "-")),
                DataCell(Text(item['type'] ?? "-")),
                DataCell(Text(item['valid_from_date'] ?? "-")),
                DataCell(Text(item['valid_upto_date'] ?? "-")),
                DataCell(
                  Switch(
                    value: item['file_status'] == 1 || item['file_status'] == "1",
                    activeColor: Colors.green,
                    onChanged: (v) => toggleFileStatus(item['id'], item['file_status']),
                  ),
                ),
                DataCell(IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => editFileDetails(item['id']))),
                DataCell(IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => deleteFileAction(item['id']))),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  });
}

  // ──────────────────────────────────────────────────────────────────────────
  // WIDGET HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildTextField(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return TextField(
      controller: ctrl, 
      maxLines: maxLines, 
      decoration: InputDecoration(
        labelText: label, 
        labelStyle: const TextStyle(fontSize: 13),
        border: const OutlineInputBorder(), 
        alignLabelWithHint: true
      ),
    );
  }

  DataColumn _buildCol(String label) {
    return DataColumn(
      label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))
    );
  }

  Widget _buildTableHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          const Text("Show ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          DropdownButton<String>(
            value: entriesValue, 
            items: ["10", "25", "50"].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), 
            onChanged: (v) => setState(() { entriesValue = v!; currentPage = 1; })
          ),
          const Text(" entries", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
        SizedBox(
          width: 320, 
          height: 40, 
          child: TextField(
            controller: _searchController, 
            decoration: const InputDecoration(
              hintText: "Search Files...", 
              border: OutlineInputBorder(), 
              prefixIcon: Icon(Icons.search, size: 18)
            )
          )
        ),
      ],
    );
  }

  Widget _buildTableFooter(List<dynamic> paged) {
    int total = _filteredList.length;
    int maxPages = (total / int.parse(entriesValue)).ceil();
    if (maxPages == 0) maxPages = 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Showing ${paged.length} of $total records", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        Row(
          children: [
            OutlinedButton(
              onPressed: currentPage > 1 ? () => setState(() => currentPage--) : null, 
              child: const Text("Previous")
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text("Page $currentPage of $maxPages", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            OutlinedButton(
              onPressed: currentPage < maxPages ? () => setState(() => currentPage++) : null, 
              child: const Text("Next")
            ),
          ],
        )
      ],
    );
  }
}