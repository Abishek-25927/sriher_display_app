import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class ScheduleAllocateView extends StatefulWidget {
  final Map<String, dynamic>? editData;
  final bool isExtend;

  const ScheduleAllocateView({super.key, this.editData, this.isExtend = false});

  @override
  State<ScheduleAllocateView> createState() => _ScheduleAllocateViewState();
}

class _ScheduleAllocateViewState extends State<ScheduleAllocateView>
    with SingleTickerProviderStateMixin {
  final String _baseUrl = "https://display.sriher.com";
  final String _apiKey =
      "933cdb13cb54e31e694f82bf7f75f0144a9495036db0243b85dd855be53c06f2";

  List<dynamic> scheduleList = [];
  List<dynamic> templateList = [];
  List<dynamic> templateFiles = [];
  bool isLoadingSchedules = false;
  bool isLoadingTemplates = false;
  bool isLoadingFiles = false;

  String entriesValue = "10";
  int? selectedScheduleId;
  int? selectedTemplateId;
  bool selectAllSlot = false;
  Map<String, List<String>> selectedSlotsByDay = {};

  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  final TextEditingController _fromTimeController = TextEditingController();
  final TextEditingController _newScheduleController = TextEditingController();

  late AnimationController _durationPanelController;
  late Animation<double> _durationFade;
  late Animation<Offset> _durationSlide;
  bool _wasSelectionComplete = false;

  @override
  void initState() {
    super.initState();
    _fetchSchedules();
    _fetchTemplates();

    if (widget.editData != null) {
      // Handle various possible key names for schedule/template IDs
      selectedScheduleId =
          int.tryParse(widget.editData!['schedule_id']?.toString() ?? '') ??
          int.tryParse(widget.editData!['id']?.toString() ?? '');

      selectedTemplateId =
          int.tryParse(widget.editData!['temp_id']?.toString() ?? '') ??
          int.tryParse(widget.editData!['template_id']?.toString() ?? '');

      _fromDateController.text =
          widget.editData!['from_date']?.toString() ?? '';
      _toDateController.text = widget.editData!['to_date']?.toString() ?? '';
      _fromTimeController.text =
          widget.editData!['from_time']?.toString() ?? '';

      if (selectedTemplateId != null) {
        _fetchTemplateFiles(selectedTemplateId!);
      }

      // If we have a from_time, pre-select that slot in the grid for each day
      if (_fromTimeController.text.isNotEmpty &&
          _fromDateController.text.isNotEmpty &&
          _toDateController.text.isNotEmpty) {
        _prepopulateSlots();
      }
    }

    _durationPanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _durationFade = CurvedAnimation(
      parent: _durationPanelController,
      curve: Curves.easeOut,
    );
    _durationSlide =
        Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _durationPanelController,
            curve: Curves.easeOutCubic,
          ),
        );
  }

  @override
  void dispose() {
    _fromDateController.dispose();
    _toDateController.dispose();
    _fromTimeController.dispose();
    _newScheduleController.dispose();
    _durationPanelController.dispose();
    super.dispose();
  }

  List<String> _generateTimeSlots() {
    List<String> slots = [];
    for (int i = 0; i < 24; i++) {
      String hour = i.toString().padLeft(2, '0');
      slots.add("$hour:00");
      slots.add("$hour:30");
    }
    return slots;
  }

  bool get isSelectionComplete =>
      selectedScheduleId != null && selectedTemplateId != null;

  bool get isAllFilled =>
      isSelectionComplete &&
      _fromDateController.text.isNotEmpty &&
      _toDateController.text.isNotEmpty &&
      _fromTimeController.text.isNotEmpty;

  List<String> get slotPairs {
    List<String> pairs = [];
    for (int i = 0; i < 24; i++) {
      String h1 = i.toString().padLeft(2, '0');
      String h2 = (i + 1).toString().padLeft(2, '0');
      if (i == 23) h2 = "00";
      pairs.add("$h1:00 - $h1:30");
      pairs.add("$h1:30 - $h2:00");
    }
    return pairs;
  }

  void _prepopulateSlots() {
    try {
      DateTime start = DateFormat('yyyy-MM-dd').parse(_fromDateController.text);
      DateTime end = DateFormat('yyyy-MM-dd').parse(_toDateController.text);
      String time = _fromTimeController.text;

      // Find which slot this time falls into
      String? matchedSlot;
      for (var pair in slotPairs) {
        if (pair.startsWith(time)) {
          matchedSlot = pair;
          break;
        }
      }

      if (matchedSlot != null) {
        for (int i = 0; i <= end.difference(start).inDays; i++) {
          String key = DateFormat(
            'yyyy-MM-dd',
          ).format(start.add(Duration(days: i)));
          selectedSlotsByDay[key] = [matchedSlot];
        }
      }
    } catch (e) {
      debugPrint("Error pre-populating slots: $e");
    }
  }

  // ──────────────────────────── API CALLS ────────────────────────────────────

  Future<void> _fetchSchedules() async {
    setState(() => isLoadingSchedules = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/scheduleMenu_listview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"api_key": _apiKey}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => scheduleList = data['data'] ?? []);
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() => isLoadingSchedules = false);
    }
  }

  Future<void> _fetchTemplates() async {
    setState(() => isLoadingTemplates = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/new_templateview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"api_key": _apiKey}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => templateList = data['data'] ?? []);
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() => isLoadingTemplates = false);
    }
  }

  Future<void> _fetchTemplateFiles(int templateId) async {
    setState(() => isLoadingFiles = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/selectTemplate_filesview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"api_key": _apiKey, "template_id": templateId}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => templateFiles = data['data'] ?? []);
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() => isLoadingFiles = false);
    }
  }

  Future<void> _handleScheduleSubmit() async {
    if (selectedScheduleId == null || selectedTemplateId == null) return;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/scheduleMenu_insertview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "api_key": _apiKey,
          "schedule_id": selectedScheduleId,
          "temp_id": selectedTemplateId,
          "from_date": _fromDateController.text,
          "to_date": _toDateController.text,
          "from_time": _fromTimeController.text,
        }),
      );
      if (response.statusCode == 200) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Assigned Successfully")),
          );
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // ──────────────────────────── POPUPS ───────────────────────────────────────

  void _showSchedulePopup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "SCHEDULE DEPARTMENT",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const Divider(height: 1, color: Colors.grey),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 30,
                ),
                child: TextFormField(
                  controller: _newScheduleController,
                  decoration: const InputDecoration(
                    hintText: "Schedule Name",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
              const Divider(height: 1, color: Colors.grey),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("SAVE"),
                    ),
                    const SizedBox(width: 15),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("CLOSE"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────── BUILD ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (isSelectionComplete && !_wasSelectionComplete) {
      _durationPanelController.forward(from: 0);
      _wasSelectionComplete = true;
    } else if (!isSelectionComplete) {
      _wasSelectionComplete = false;
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.topLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column (Fixed position)
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionTitle(
                    widget.isExtend ? "Extend Schedule" : "Schedule",
                  ),
                  const SizedBox(height: 15),
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildDropdownField(
                                  hint: "Select Schedule Name",
                                  value: selectedScheduleId,
                                  items: scheduleList,
                                  onChanged: (val) =>
                                      setState(() => selectedScheduleId = val),
                                ),
                              ),
                              const SizedBox(width: 12),
                              _buildCircularAddButton(),
                              const SizedBox(width: 25),
                              Expanded(
                                child: _buildDropdownField(
                                  hint: "Select Template Name",
                                  value: selectedTemplateId,
                                  items: templateList,
                                  onChanged: (val) {
                                    setState(() {
                                      selectedTemplateId = val;
                                      templateFiles = [];
                                    });
                                    if (val != null) _fetchTemplateFiles(val);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: _buildDateField(
                                  "From Date",
                                  _fromDateController,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: _buildTimeDropdown(
                                  "Select Time",
                                  _fromTimeController,
                                  enabled: _fromDateController.text.isNotEmpty,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: _buildDateField(
                                  "To Date",
                                  _toDateController,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Row(
                                children: [
                                  Checkbox(
                                    value: selectAllSlot,
                                    activeColor: Colors.black,
                                    onChanged: (val) => setState(() {
                                      selectAllSlot = val!;
                                      if (selectAllSlot) {
                                        try {
                                          DateTime start = DateFormat(
                                            'yyyy-MM-dd',
                                          ).parse(_fromDateController.text);
                                          DateTime end = DateFormat(
                                            'yyyy-MM-dd',
                                          ).parse(_toDateController.text);
                                          if (end.isBefore(start)) end = start;
                                          for (
                                            int i = 0;
                                            i <= end.difference(start).inDays;
                                            i++
                                          ) {
                                            String key =
                                                DateFormat('yyyy-MM-dd').format(
                                                  start.add(Duration(days: i)),
                                                );
                                            selectedSlotsByDay[key] = List.from(
                                              slotPairs,
                                            );
                                          }
                                        } catch (e) {
                                          debugPrint(e.toString());
                                        }
                                      } else {
                                        selectedSlotsByDay.clear();
                                      }
                                    }),
                                  ),
                                  const Text(
                                    "Select All Slot",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (isAllFilled) ...[
                    _buildSlotSelectionCard(),
                    const SizedBox(height: 15),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 18,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 8,
                        ),
                        onPressed: _handleScheduleSubmit,
                        child: const Text(
                          "SUBMIT",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Right Column
          Expanded(
            flex: 5,
            child: isSelectionComplete
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionTitle("TEMPLATE DURATION"),
                        const SizedBox(height: 15),
                        Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 6,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                _buildListHeader(),
                                const SizedBox(height: 16),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (isLoadingFiles) {
                                      return const SizedBox(
                                        height: 200,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.blueAccent,
                                          ),
                                        ),
                                      );
                                    }

                                    if (templateFiles.isEmpty) {
                                      return const SizedBox(
                                        height: 100,
                                        child: Center(
                                          child: Text(
                                            "No files found for this template",
                                            style: TextStyle(
                                              color: Colors.black54,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    return SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minWidth: constraints.maxWidth,
                                        ),
                                        child: DataTable(
                                          columnSpacing: 25,
                                          horizontalMargin: 10,
                                          dataRowMinHeight: 65,
                                          dataRowMaxHeight: 75,
                                          headingRowColor:
                                              WidgetStateProperty.all(
                                                Colors.black,
                                              ),
                                          headingRowHeight: 40,
                                          columns: [
                                            _buildSortableColumn('Play order'),
                                            _buildSortableColumn('File'),
                                            _buildSortableColumn('File Name'),
                                            _buildSortableColumn('Duration'),
                                          ],
                                          rows: templateFiles.map((file) {
                                            final index =
                                                templateFiles.indexOf(file) + 1;
                                            return DataRow(
                                              cells: [
                                                DataCell(
                                                  Text(
                                                    index.toString(),
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 6.0,
                                                        ),
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color: Colors
                                                              .grey
                                                              .shade300,
                                                        ),
                                                      ),
                                                      child:
                                                          file['file_name'] !=
                                                              null
                                                          ? Image.network(
                                                              "$_baseUrl/uploads/${file['file_name']}",
                                                              height: 55,
                                                              width: 45,
                                                              fit: BoxFit.cover,
                                                              errorBuilder:
                                                                  (
                                                                    context,
                                                                    error,
                                                                    stackTrace,
                                                                  ) => const Icon(
                                                                    Icons
                                                                        .broken_image,
                                                                    size: 30,
                                                                  ),
                                                            )
                                                          : const Icon(
                                                              Icons.image,
                                                              size: 20,
                                                            ),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    file['user_filename'] ??
                                                        file['file_name'] ??
                                                        '-',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    "${file['duration'] ?? '30'}s",
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildPagination(),
                              ],
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

  // ──────────────────────────── UI HELPERS ───────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDropdownField({
    required String hint,
    int? value,
    required List<dynamic> items,
    required Function(int?) onChanged,
  }) {
    return DropdownMenu<int>(
      key: ValueKey(value),
      initialSelection: value,
      hintText: hint,
      width: 250, // Adjust as needed
      menuHeight: 300,
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onSelected: onChanged,
      dropdownMenuEntries: items.map((e) {
        final id = int.tryParse(e['id'].toString());
        final name = e['schedule_name'] ?? e['temp_name'] ?? '';
        return DropdownMenuEntry<int>(value: id ?? 0, label: name);
      }).toList(),
    );
  }

  Widget _buildTimeDropdown(
    String hint,
    TextEditingController controller, {
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "From Time",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.blueAccent,
          ),
        ),
        const SizedBox(height: 5),
        DropdownMenu<String>(
          initialSelection: controller.text.isEmpty ? null : controller.text,
          hintText: hint,
          width: 250, // Match other dropdowns
          menuHeight: 300,
          enabled: enabled,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey.shade200,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          onSelected: (v) {
            if (v != null) {
              setState(() => controller.text = v);
            }
          },
          dropdownMenuEntries: enabled
              ? _generateTimeSlots().map((String time) {
                  return DropdownMenuEntry<String>(value: time, label: time);
                }).toList()
              : [],
        ),
      ],
    );
  }

  Widget _buildCircularAddButton() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.add, color: Colors.white, size: 14),
        onPressed: _showSchedulePopup,
      ),
    );
  }

  Widget _buildDateField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.blueAccent,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          readOnly: true,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'yyyy-mm-dd',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            suffixIcon: const Icon(Icons.calendar_month, size: 18),
          ),
          onTap: () async {
            DateTime? pickedDate = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2101),
            );
            if (pickedDate != null) {
              setState(
                () => controller.text = DateFormat(
                  'yyyy-MM-dd',
                ).format(pickedDate),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 1. Entries dropdown now on the LEFT
        Row(
          children: [
            SizedBox(
              width: 70,
              height: 35,
              child: DropdownButtonFormField<String>(
                value:
                    entriesValue, // Use 'value' instead of 'initialValue' if it changes via setState
                items: ["10", "25", "50"]
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, style: const TextStyle(fontSize: 11)),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => entriesValue = val!),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 5),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const Text(
              " entries",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ],
        ),

        const SizedBox(width: 20), // Spacing between the two sections
        // 2. Search field now on the RIGHT
        Expanded(
          child: SizedBox(
            height: 35, // Matching height with the dropdown for symmetry
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search...",
                hintStyle: TextStyle(fontSize: 12),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSetexttionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
    );
  }

  DataColumn _buildSortableColumn(String label) {
    return DataColumn(
      label: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          const Icon(Icons.unfold_more, color: Colors.white70, size: 14),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildPageBtn("Previous"),
        _buildPageBtn("1"),
        _buildPageBtn("2"),
        _buildPageBtn("3"),
        _buildPageBtn("4"),
        _buildPageBtn("Next"),
      ],
    );
  }

  Widget _buildPageBtn(String label) {
    bool isActive = label == "1";
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: isActive ? Colors.blue : Colors.white,
        foregroundColor: isActive ? Colors.white : Colors.blue,
        minimumSize: const Size(40, 35),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      onPressed: () {},
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSlotSelectionCard() {
    DateTime start;
    DateTime end;
    try {
      start = DateFormat('yyyy-MM-dd').parse(_fromDateController.text);
      end = DateFormat('yyyy-MM-dd').parse(_toDateController.text);
      if (end.isBefore(start)) end = start;
    } catch (e) {
      return const SizedBox.shrink();
    }

    List<DateTime> days = [];
    for (int i = 0; i <= end.difference(start).inDays; i++) {
      days.add(start.add(Duration(days: i)));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 6,
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(0),
                child: Column(
                  children: days.map((day) => _buildDaySection(day)).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildDaySection(DateTime day) {
    String dateStr = DateFormat('dd-MM-yyyy').format(day);
    String key = DateFormat('yyyy-MM-dd').format(day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Text(
            dateStr,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 0,
              crossAxisSpacing: 0,
              childAspectRatio: 2.8,
            ),
            itemCount: slotPairs.length,
            itemBuilder: (context, index) {
              final slot = slotPairs[index];
              List<String> daySlots = selectedSlotsByDay[key] ?? [];
              bool isSelected = daySlots.contains(slot) || selectAllSlot;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: 0.8,
                    child: Checkbox(
                      value: isSelected,
                      activeColor: Colors.black,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (val) {
                        setState(() {
                          if (val!) {
                            selectedSlotsByDay.putIfAbsent(key, () => []);
                            if (!selectedSlotsByDay[key]!.contains(slot)) {
                              selectedSlotsByDay[key]!.add(slot);
                            }
                          } else {
                            if (selectAllSlot) {
                              // If global selectAll is on, we local-populate others if needed
                              // or just handle it as individual uncheck
                              selectedSlotsByDay[key]?.remove(slot);
                            } else {
                              selectedSlotsByDay[key]?.remove(slot);
                            }
                          }
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: Text(
                      slot,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
