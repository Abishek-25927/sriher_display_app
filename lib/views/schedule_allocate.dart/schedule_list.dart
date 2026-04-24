import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ScheduleListView extends StatefulWidget {
  final Function(Map<String, dynamic>)? onEdit;
  final Function(Map<String, dynamic>)? onExtend;

  const ScheduleListView({super.key, this.onEdit, this.onExtend});

  @override
  State<ScheduleListView> createState() => _ScheduleListViewState();
}

class _ScheduleListViewState extends State<ScheduleListView> {
  final String _baseUrl = "https://display.sriher.com";
  final String _apiKey =
      "933cdb13cb54e31e694f82bf7f75f0144a9495036db0243b85dd855be53c06f2";

  List<dynamic> scheduleData = [];
  bool isLoading = true;
  String entriesValue = "10";
  bool showActive = true;

  // Inactive Popup State
  final TextEditingController _dateRangeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSchedules();
  }

  // ──────────────────────────── API CALLS ────────────────────────────────────

  Future<void> _fetchSchedules() async {
    setState(() => isLoading = true);
    final endpoint = showActive
        ? "scheduleList_activeListview"
        : "scheduleList_inactiveListview";

    Map<String, dynamic> body = {"api_key": _apiKey};
    if (!showActive) {
      // Use selected date for inactive lookup
      if (_dateRangeController.text.isNotEmpty) {
        DateTime selected = DateFormat(
          'yyyy-MM-dd',
        ).parse(_dateRangeController.text);
        body["from_date"] = DateFormat('yyyy-MM-01').format(selected);
        // Find last day of month
        DateTime nextMonth = DateTime(selected.year, selected.month + 1, 1);
        DateTime lastDay = nextMonth.subtract(const Duration(days: 1));
        body["to_date"] = DateFormat('yyyy-MM-dd').format(lastDay);
      } else {
        body["from_date"] = "2026-01-01";
        body["to_date"] = "2026-12-31";
      }
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/$endpoint'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          scheduleData = data['data'] ?? [];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnack("Error loading data. Check server connection.", isError: true);
    }
  }

  Future<void> _updateStatus(int id, int newStatus) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/scheduleList_statusUpdateview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "api_key": _apiKey,
          "schedule_id": id,
          "status": newStatus,
        }),
      );
      if (response.statusCode == 200) {
        _showSnack("Status Updated Successfully");
        _fetchSchedules(); // Refresh list to show correct state
      }
    } catch (e) {
      _showSnack("Failed to update status", isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ──────────────────────────── BUILD ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        showActive
                            ? "Active Schedule List"
                            : "InActive Schedule List",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          if (showActive) {
                            _showInactivePopup(context);
                          } else {
                            setState(() {
                              showActive = true;
                              scheduleData = [];
                            });
                            _fetchSchedules();
                          }
                        },
                        icon: Icon(
                          showActive ? Icons.history : Icons.check_circle,
                        ),
                        label: Text(
                          showActive ? "View Inactive" : "View Active",
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildListHeader(),
                            const SizedBox(height: 16),
                            Expanded(
                              child: isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : _buildTableContainer(),
                            ),
                            const SizedBox(height: 16),
                            _buildFooter(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableContainer() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          child: DataTable(
            border: TableBorder.all(color: Colors.grey.shade300),
            headingRowHeight: 50,
            dataRowMaxHeight: 55,
            headingRowColor: WidgetStateProperty.all(
              const Color(0xFF000000),
            ), // BLACK HEADER
            columns: [
              _buildCol('SCHEDULE NAME'),
              _buildCol('TEMPLATE NAME'),
              _buildCol('DURATION'),
              _buildCol('FROM DATE'),
              _buildCol('TO DATE'),
              _buildCol('ACTION'),
              _buildCol('CHANGES'),
            ],
            rows: scheduleData.map((item) => _buildDataRow(item)).toList(),
          ),
        ),
      ),
    );
  }

  DataRow _buildDataRow(dynamic item) {
    bool isActive = (item['status'] == 1 || item['status'] == '1');
    int id = int.tryParse(item['id'].toString()) ?? 0;

    return DataRow(
      cells: [
        DataCell(Text(item['schedule_name'] ?? '-')),
        DataCell(Text(item['temp_name'] ?? '-')),
        DataCell(Text("${item['duration'] ?? '0'}s")),
        DataCell(Text(item['from_date'] ?? '-')),
        DataCell(Text(item['to_date'] ?? '-')),
        // WIFI STYLE TOGGLE
        DataCell(
          Center(
            child: Transform.scale(
              scale: 0.8,
              child: Switch(
                value: isActive,
                activeColor: Colors.green,
                onChanged: (val) => _updateStatus(id, val ? 1 : 0),
              ),
            ),
          ),
        ),
        // SETTINGS + DOWN ARROW DROPDOWN
        DataCell(Center(child: _buildChangesButton(item))),
      ],
    );
  }

  Widget _buildChangesButton(dynamic item) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0A192F),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
          ],
        ),
      ),
      onSelected: (value) {
        if (value == 'edit') {
          if (widget.onEdit != null) widget.onEdit!(item);
        } else if (value == 'extend') {
          if (widget.onExtend != null) widget.onExtend!(item);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18, color: Colors.blue),
              SizedBox(width: 10),
              Text("Edit", style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'extend',
          child: Row(
            children: [
              Icon(Icons.unfold_more, size: 18, color: Colors.orange),
              SizedBox(width: 10),
              Text("Extend", style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  DataColumn _buildCol(String label) {
    return DataColumn(
      label: Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.unfold_more, color: Colors.white70, size: 14),
          ],
        ),
      ),
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
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            SizedBox(
              width: 85,
              child: DropdownMenu<String>(
                initialSelection: entriesValue,
                inputDecorationTheme: const InputDecorationTheme(
                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  border: OutlineInputBorder(),
                ),
                onSelected: (v) {
                  if (v != null) setState(() => entriesValue = v);
                },
                dropdownMenuEntries: [
                  '10',
                  '25',
                  '50',
                ].map((v) => DropdownMenuEntry(value: v, label: v)).toList(),
              ),
            ),

            const Text(
              " entries",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
        SizedBox(
          width: 220,
          height: 38,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search Schedule',
              hintStyle: const TextStyle(fontSize: 14),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              suffixIcon: const Icon(Icons.search, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Showing ${scheduleData.length} entries",
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Row(
          children: [
            _buildPageBtn("Previous", enabled: false),
            _buildPageBtn("1", active: true),
            _buildPageBtn("Next", enabled: true),
          ],
        ),
      ],
    );
  }

  Widget _buildPageBtn(
    String label, {
    bool active = false,
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      height: 35,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: active ? Colors.blue : Colors.white,
          foregroundColor: active ? Colors.white : Colors.blue,

          side: BorderSide(color: Colors.grey.shade400),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onPressed: enabled ? () {} : null,
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showInactivePopup(BuildContext context) {
    int selectedYear = DateTime.now().year;
    int selectedMonth = DateTime.now().month;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Center(
            child: Text(
              "Select Year and Month",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(),
              const SizedBox(height: 20),
              Row(
                children: [
                  // Year Dropdown
                  Expanded(
                    child: DropdownMenu<int>(
                      initialSelection: selectedYear,
                      label: const Text("Year"),
                      width: 120,
                      onSelected: (y) => setPopupState(() => selectedYear = y!),
                      dropdownMenuEntries:
                          List.generate(
                                10,
                                (index) => DateTime.now().year - 5 + index,
                              )
                              .map(
                                (y) => DropdownMenuEntry(
                                  value: y,
                                  label: y.toString(),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Month Dropdown
                  Expanded(
                    child: DropdownMenu<int>(
                      initialSelection: selectedMonth,
                      label: const Text("Month"),
                      width: 120,
                      onSelected: (m) =>
                          setPopupState(() => selectedMonth = m!),
                      dropdownMenuEntries:
                          List.generate(12, (index) => index + 1)
                              .map(
                                (m) => DropdownMenuEntry(
                                  value: m,
                                  label: DateFormat(
                                    'MMM',
                                  ).format(DateTime(2024, m)),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                    ),
                    onPressed: () {
                      setState(() {
                        showActive = false;
                        _dateRangeController.text =
                            "$selectedYear-${selectedMonth.toString().padLeft(2, '0')}-01";
                        scheduleData = [];
                      });
                      _fetchSchedules();
                      Navigator.pop(context);
                    },
                    child: const Text("VIEW"),
                  ),
                  const SizedBox(width: 15),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("CLOSE"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
