import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../widgets/animated_heading.dart';

class SpecificRangesView extends StatefulWidget {
  const SpecificRangesView({super.key});

  @override
  State<SpecificRangesView> createState() => _SpecificRangesViewState();
}

class _SpecificRangesViewState extends State<SpecificRangesView> {
  final String _baseUrl = "https://display.sriher.com";
  final String _apiKey =
      "933cdb13cb54e31e694f82bf7f75f0144a9495036db0243b85dd855be53c06f2";

  bool skipDates = false;
  int? selectedScheduleId;
  int? selectedTemplateId;
  String entriesValue = "10";

  List<dynamic> scheduleList = [];
  List<dynamic> templateList = [];
  List<dynamic> templateFiles = [];
  List<String> offDates = [];

  bool isLoadingSchedules = false;
  bool isLoadingTemplates = false;
  bool isLoadingFiles = false;

  Map<int, bool> slotSelection = {};

  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  final TextEditingController _scheduleNameController = TextEditingController();

  @override
  void dispose() {
    _fromDateController.dispose();
    _toDateController.dispose();
    _scheduleNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchScheduleNames();
    _fetchTemplates();
    for (int i = 0; i < 48; i++) {
      slotSelection[i] = false;
    }
  }

  List<String> _generateTimeSlots() {
    List<String> slots = [];
    for (int i = 0; i < 24; i++) {
      String start = i.toString().padLeft(2, '0');
      String end = (i + 1 == 24 ? "00" : (i + 1).toString().padLeft(2, '0'));
      slots.add("$start:00-$start:30");
      slots.add("$start:30-$end:00");
    }
    return slots;
  }

  Future<void> _fetchScheduleNames() async {
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
      debugPrint("Error fetching schedules: $e");
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
      debugPrint("Error fetching templates: $e");
    } finally {
      setState(() => isLoadingTemplates = false);
    }
  }

  Future<void> _fetchTemplateFiles(int tempId) async {
    setState(() => isLoadingFiles = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/schedulerange_temptableview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"api_key": _apiKey, "temp_id": tempId}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => templateFiles = data['data'] ?? []);
      }
    } catch (e) {
      debugPrint("Error fetching template files: $e");
    } finally {
      setState(() => isLoadingFiles = false);
    }
  }

  Future<void> _fetchOffDates() async {
    if (_fromDateController.text.isEmpty || _toDateController.text.isEmpty)
      return;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/schedulerange_getOffDatesview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "api_key": _apiKey,
          "from_date": _fromDateController.text,
          "to_date": _toDateController.text,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => offDates = List<String>.from(data['data'] ?? []));
      }
    } catch (e) {
      debugPrint("Error fetching off dates: $e");
    }
  }

  Future<void> _handleInsertSlots() async {
    if (selectedScheduleId == null ||
        selectedTemplateId == null ||
        _fromDateController.text.isEmpty ||
        _toDateController.text.isEmpty) {
      _showSnackBar("Please complete all required fields");
      return;
    }

    List<int> selectedIndices = slotSelection.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    if (selectedIndices.isEmpty) {
      _showSnackBar("Please select at least one slot");
      return;
    }

    List<String> times = _generateTimeSlots();
    bool success = true;

    for (int index in selectedIndices) {
      String slot = times[index];
      List<String> range = slot.split('-');

      final body = {
        "api_key": _apiKey,
        "schedule_id": selectedScheduleId,
        "temp_id": selectedTemplateId,
        "from_date": _fromDateController.text,
        "to_date": _toDateController.text,
        "t_duration": "01:00:00",
        "slot_from_time": range[0],
        "slot_to_time": range[1],
        "r_dates": skipDates ? offDates : [],
      };

      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/schedulerange_insertSlotsview'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        );
        if (response.statusCode != 200) success = false;
      } catch (e) {
        success = false;
        debugPrint("Error inserting slot $slot: $e");
      }
    }

    if (success) {
      _showSnackBar("Slots successfully assigned");
    } else {
      _showSnackBar("Some slots failed to assign");
    }
  }

  void _showSnackBar(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: Colors.blue.shade800,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );

  void _showAddSchedulePopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 450,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: Colors.white,
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Text(
                      "NEW SCHEDULE",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Schedule Name",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _scheduleNameController,
                      decoration: InputDecoration(
                        hintText: 'Enter department or purpose',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "CANCEL",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "SAVE",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Align(
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const AnimatedHeading(text: "Schedule Range Allocation"),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          label: "Schedule Name",
                          hint: "Select Schedule",
                          value: selectedScheduleId,
                          items: scheduleList,
                          showAdd: true,
                          onChanged: (val) =>
                              setState(() => selectedScheduleId = val),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildDropdown(
                          label: "Template Name",
                          hint: "Select Template",
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
                  if (selectedScheduleId != null &&
                      selectedTemplateId != null) ...[
                    const SizedBox(height: 48),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 4, child: _buildSlotsPanel()),
                        const SizedBox(width: 32),
                        Expanded(flex: 6, child: _buildTemplateDetailsPanel()),
                      ],
                    ),
                  ],
                  const SizedBox(height: 48),
                  const Divider(),
                  const SizedBox(height: 48),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildDateField(
                                "From Date",
                                _fromDateController,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildDateField(
                                "To Date",
                                _toDateController,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                      Row(
                        children: [
                          Checkbox(
                            value: skipDates,
                            activeColor: Colors.blue.shade600,
                            onChanged: (val) {
                              setState(() => skipDates = val!);
                              if (val!) _fetchOffDates();
                            },
                          ),
                          const Text(
                            "Skip Conflict Dates",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 48),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 4,
                        ),
                        onPressed: _handleInsertSlots,
                        child: const Text(
                          "SUBMIT ALLOCATION",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPanelHeader("SELECT TIME SLOTS", Icons.access_time),
        Container(
          height: 450,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(48, (index) {
                String slot = _generateTimeSlots()[index];
                bool isSelected = slotSelection[index] ?? false;
                return InkWell(
                  onTap: () =>
                      setState(() => slotSelection[index] = !isSelected),
                  child: Container(
                    width: 110,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color.fromARGB(255, 96, 164, 223)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? const Color.fromARGB(255, 101, 167, 224)
                            : Colors.grey.shade300,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        slot,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateDetailsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPanelHeader("TEMPLATE PREVIEW", Icons.visibility_outlined),
        Container(
          height: 450,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildTableHeader(),
              Expanded(
                child: templateFiles.isEmpty
                    ? Center(
                        child: Text(
                          "No files in this template",
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: templateFiles.length,
                        itemBuilder: (context, index) {
                          final file = templateFiles[index];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade100),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Center(
                                    child: Text(
                                      "${index + 1}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: file['file_name'] != null
                                            ? Image.network(
                                                "$_baseUrl/uploads/${file['file_name']}",
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(
                                                      Icons.broken_image,
                                                      size: 20,
                                                    ),
                                              )
                                            : const Icon(Icons.image, size: 20),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    file['user_filename'] ??
                                        file['file_name'] ??
                                        '-',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        "${file['duration'] ?? '30'}s",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade900,
                                        ),
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
              _buildTableFooter(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPanelHeader(String title, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.blue.shade900,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.blue.shade50,
      child: const Row(
        children: [
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                "ORDER",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                "FILE",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              "NAME",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                "DURATION",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Total Files: ${templateFiles.length}",
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          Row(
            children: [
              _buildMiniBtn("Prev"),
              _buildMiniBtn("1", active: true),
              _buildMiniBtn("Next"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBtn(String label, {bool active = false}) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          backgroundColor: active ? Colors.blue.shade600 : Colors.white,
          foregroundColor: active ? Colors.white : Colors.blue.shade600,
          side: BorderSide(
            color: active ? Colors.blue.shade600 : Colors.grey.shade300,
          ),
          minimumSize: const Size(0, 30),
        ),
        onPressed: () {},
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String hint,
    int? value,
    required List<dynamic> items,
    bool showAdd = false,
    required ValueChanged<int?> onChanged,
  }) {
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
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: value,
                    hint: Text(
                      hint,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    onChanged: onChanged,
                    items: items.map((e) {
                      final id = int.tryParse(e['id'].toString());
                      final name = e['schedule_name'] ?? e['temp_name'] ?? '';
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text(name, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            if (showAdd) ...[
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _showAddSchedulePopup(context),
                icon: const Icon(Icons.add, size: 20),
              ),
            ],
          ],
        ),
      ],
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
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            hintText: 'yyyy-mm-dd',
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(
              Icons.calendar_today,
              size: 18,
              color: Colors.blue,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          onTap: () async {
            DateTime? picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2101),
            );
            if (picked != null)
              setState(
                () => controller.text = DateFormat('yyyy-MM-dd').format(picked),
              );
          },
        ),
      ],
    );
  }
}
