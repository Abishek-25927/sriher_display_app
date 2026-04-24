import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

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

  // Track checkbox states for 48 slots
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
    // Initialize all slots as unselected
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
        // The user says "display the data of file play order , file name , duration"
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

    // Filter selected slots
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
        "t_duration": "01:00:00", // Defaulting to 1 hour as per example
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
      // Optional: clear selection or navigate
    } else {
      _showSnackBar("Some slots failed to assign");
    }
  }

  void _showSnackBar(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // --- POPUP DIALOG FUNCTION ---
  void _showAddSchedulePopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        contentPadding: EdgeInsets.zero,
        // Use SizedBox to force the width of the popup
        content: SizedBox(
          width: 600, // Increased width
          child: Column(
            mainAxisSize: MainAxisSize.min, // Keeps height based on content
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  "SCHEDULE NAME",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const Divider(height: 1, thickness: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40.0,
                  vertical: 30.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Schedule Name :",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 45,
                      child: TextFormField(
                        controller: _scheduleNameController,
                        decoration: const InputDecoration(
                          hintText: 'Enter Schedule Name',
                          hintStyle: TextStyle(fontSize: 13),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 40,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF000000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Save",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 100,
                      height: 40,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Close",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
    return Container(
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Schedule Range",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Row(
                                        children: [
                                          Expanded(
                                            child: _buildDropdown(
                                              hint: "Select Schedule Name",
                                              value: selectedScheduleId,
                                              items: scheduleList,
                                              width:
                                                  constraints.maxWidth -
                                                  30, // Account for add button
                                              onChanged: (val) => setState(
                                                () => selectedScheduleId = val,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _buildSmallAddButton(context),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 30),
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return _buildDropdown(
                                        hint: "Select Template Name",
                                        value: selectedTemplateId,
                                        items: templateList,
                                        width: constraints.maxWidth,
                                        onChanged: (val) {
                                          setState(() {
                                            selectedTemplateId = val;
                                            templateFiles = [];
                                          });
                                          if (val != null)
                                            _fetchTemplateFiles(val);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if (selectedScheduleId != null &&
                                selectedTemplateId != null) ...[
                              const SizedBox(height: 20),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _buildSlotsCard()),
                                  const SizedBox(width: 30),
                                  Expanded(child: _buildPlayOrderCard()),
                                ],
                              ),
                            ],
                            const SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      _buildInlineDateField(
                                        "From Date",
                                        _fromDateController,
                                      ),
                                      const SizedBox(width: 15),
                                      _buildInlineDateField(
                                        "To Date",
                                        _toDateController,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 30),
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Checkbox(
                                            value: skipDates,
                                            visualDensity:
                                                VisualDensity.compact,
                                            activeColor: Colors.black,
                                            onChanged: (val) {
                                              setState(() => skipDates = val!);
                                              if (val!) _fetchOffDates();
                                            },
                                          ),
                                          const Text(
                                            "Skip Dates(Between Selected Range)",
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                        height: 40,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF000000,
                                            ),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                          onPressed:
                                              (selectedScheduleId != null &&
                                                  selectedTemplateId != null)
                                              ? _handleInsertSlots
                                              : null,
                                          child: const Text(
                                            "SUBMIT",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
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
                        ),
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

  Widget _buildSlotsCard() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF000000),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
          child: const Text(
            "SLOTS",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        Container(
          height: 380,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                double itemWidth = (constraints.maxWidth - 20) / 5;
                List<String> times = _generateTimeSlots();
                return Wrap(
                  children: List.generate(times.length, (index) {
                    return SizedBox(
                      width: itemWidth,
                      child: Row(
                        children: [
                          Transform.scale(
                            scale: 0.8,
                            child: Checkbox(
                              value: slotSelection[index], // Fixed state logic
                              onChanged: (v) =>
                                  setState(() => slotSelection[index] = v!),
                              visualDensity: VisualDensity.compact,
                              activeColor: const Color(0xFF000000),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              times[index],
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF000000),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- REUSED HELPERS (Play Order, Header, Footer) ---
  Widget _buildPlayOrderCard() {
    return Column(
      children: [
        _buildListHeader(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          color: const Color(0xFF000000),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Expanded(
                flex: 1,
                child: Text(
                  "PLAY ORDER",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  "FILE NO",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  "FILE NAME",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "FILE",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "DURATION",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          constraints: const BoxConstraints(minHeight: 326),
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: templateFiles.isEmpty
              ? const SizedBox(
                  height: 326,
                  child: Center(
                    child: Text(
                      "No data available in table",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: templateFiles.length,
                  itemBuilder: (context, index) {
                    final file = templateFiles[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Text(
                              "${file['play_order'] ?? file['slot_order'] ?? (index + 1)}",
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              "${file['file_no'] ?? file['f_no'] ?? '-'}",
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              file['user_filename'] ?? file['file_name'] ?? '-',
                              style: const TextStyle(fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: file['file_name'] != null
                                ? Image.network(
                                    "$_baseUrl/uploads/${file['file_name']}",
                                    height: 30,
                                    width: 30,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.broken_image,
                                      size: 20,
                                    ),
                                  )
                                : const Icon(Icons.image, size: 20),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              "${file['duration'] ?? '30'}s",
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        _buildPaginationFooter(),
      ],
    );
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              children: [
                const Text(
                  "Show ",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                SizedBox(
                  width: 80,
                  height: 35,
                  child: DropdownMenu<String>(
                    initialSelection: entriesValue,
                    inputDecorationTheme: const InputDecorationTheme(
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(),
                    ),
                    onSelected: (v) {
                      if (v != null) setState(() => entriesValue = v);
                    },
                    dropdownMenuEntries: ["10", "25"]
                        .map((e) => DropdownMenuEntry(value: e, label: e))
                        .toList(),
                  ),
                ),
                const Text(
                  " entries",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          Flexible(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  "Search: ",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(
                  width: 140,
                  height: 35,
                  child: TextField(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Showing 1 to ${templateFiles.length} of ${templateFiles.length} entries",
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              _buildPageBtn("Previous", true),
              _buildPageBtn("1", false),
              _buildPageBtn("Next", true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageBtn(String label, bool isText) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      height: 32,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: label == "1" ? Colors.blue : Colors.white,
          foregroundColor: label == "1" ? Colors.white : Colors.blue,
          side: const BorderSide(color: Colors.grey),
          padding: EdgeInsets.symmetric(horizontal: isText ? 12 : 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        onPressed: () {},
        child: Text(label, style: const TextStyle(fontSize: 10)),
      ),
    );
  }

  Widget _buildInlineDateField(String label, TextEditingController controller) {
    return Row(
      children: [
        Text(
          "$label: ",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        SizedBox(
          width: 140,
          height: 40,
          child: TextFormField(
            controller: controller,
            readOnly: true,
            decoration: const InputDecoration(
              hintText: 'yyyy-MM-dd',
              hintStyle: TextStyle(fontSize: 12),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8),
              suffixIcon: Icon(Icons.calendar_today, size: 14),
            ),
            onTap: () async {
              DateTime? p = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2101),
              );
              if (p != null) {
                setState(
                  () => controller.text = DateFormat('yyyy-MM-dd').format(p),
                );
                if (skipDates) _fetchOffDates();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String hint,
    required int? value,
    required List<dynamic> items,
    required ValueChanged<int?> onChanged,
    double? width,
  }) {
    return DropdownMenu<int>(
      initialSelection: value,
      hintText: hint,
      width: width, // Use passed width
      menuHeight: 300,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10),
      ),
      onSelected: onChanged,
      dropdownMenuEntries: items.map((e) {
        final id = int.tryParse(e['id'].toString());
        final name = e['schedule_name'] ?? e['temp_name'] ?? '';
        return DropdownMenuEntry<int>(value: id ?? 0, label: name);
      }).toList(),
    );
  }

  Widget _buildSmallAddButton(BuildContext context) {
    return InkWell(
      onTap: () => _showAddSchedulePopup(context),
      child: Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Color(0xFF000000),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 12),
      ),
    );
  }
}
