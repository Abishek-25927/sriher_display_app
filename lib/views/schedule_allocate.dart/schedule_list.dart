import 'package:intl/intl.dart';
import '../../widgets/animated_heading.dart';
import '../../widgets/stylish_dialog.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  final TextEditingController _dateRangeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSchedules();
  }

  Future<void> _fetchSchedules() async {
    setState(() => isLoading = true);
    final endpoint = showActive
        ? "scheduleList_activeListview"
        : "scheduleList_inactiveListview";

    Map<String, dynamic> body = {"api_key": _apiKey};
    if (!showActive) {
      if (_dateRangeController.text.isNotEmpty) {
        DateTime selected = DateFormat(
          'yyyy-MM-dd',
        ).parse(_dateRangeController.text);
        body["from_date"] = DateFormat('yyyy-MM-01').format(selected);
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
        _fetchSchedules();
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
        backgroundColor: isError ? Colors.red.shade800 : Colors.blue.shade800,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AnimatedHeading(
                      text: showActive
                          ? "Active Schedule List"
                          : "InActive Schedule List",
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
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
                        size: 20,
                      ),
                      label: Text(
                        showActive ? "View Inactive" : "View Active",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildListHeader(),
                        const Divider(height: 1),
                        Expanded(
                          child: isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : _buildTableContainer(),
                        ),
                        const Divider(height: 1),
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableContainer() {
    if (scheduleData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              "No schedules found",
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                headingRowHeight: 52,
                dataRowMaxHeight: 64,
                horizontalMargin: 20,
                columnSpacing: 20,
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
      },
    );
  }

  DataRow _buildDataRow(dynamic item) {
    bool isActive = (item['status'] == 1 || item['status'] == '1');
    int id = int.tryParse(item['id'].toString()) ?? 0;

    return DataRow(
      cells: [
        DataCell(
          Text(
            item['schedule_name'] ?? '-',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        DataCell(
          Text(
            item['temp_name'] ?? '-',
            style: const TextStyle(color: Colors.black87),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "${item['duration'] ?? '0'}s",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            item['from_date'] ?? '-',
            style: const TextStyle(color: Colors.black87),
          ),
        ),
        DataCell(
          Text(
            item['to_date'] ?? '-',
            style: const TextStyle(color: Colors.black87),
          ),
        ),
        DataCell(
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: isActive,
              activeColor: Colors.blue.shade600,
              onChanged: (val) => _updateStatus(id, val ? 1 : 0),
            ),
          ),
        ),
        DataCell(_buildChangesButton(item)),
      ],
    );
  }

  Widget _buildChangesButton(dynamic item) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tooltip: "Manage Schedule",
      color: Colors.white,
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings, color: Colors.blue, size: 18),
            SizedBox(width: 8),
            Icon(Icons.arrow_drop_down, color: Colors.blue, size: 18),
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
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20, color: Colors.blue.shade600),
              const SizedBox(width: 12),
              const Text(
                "Edit Schedule",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'extend',
          child: Row(
            children: [
              Icon(Icons.more_time, size: 20, color: Colors.orange.shade600),
              const SizedBox(width: 12),
              const Text(
                "Extend Period",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  DataColumn _buildCol(String label) {
    return DataColumn(
      label: Text(
        label,
        style: TextStyle(
          color: Colors.blue.shade900,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text(
                "Show ",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                height: 38,
                child: DropdownButtonFormField<String>(
                  value: entriesValue,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
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
                  onChanged: (v) {
                    if (v != null) setState(() => entriesValue = v);
                  },
                  items: ['10', '25', '50']
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v, style: const TextStyle(fontSize: 14)),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                " entries",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          SizedBox(
            width: 250,
            height: 38,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search schedules...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: Colors.grey,
                ),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Showing ${scheduleData.length} entries",
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.bold,
              fontSize: 13,
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
      ),
    );
  }

  Widget _buildPageBtn(
    String label, {
    bool active = false,
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: active ? Colors.blue.shade600 : Colors.white,
          foregroundColor: active ? Colors.white : Colors.blue.shade600,
          side: BorderSide(
            color: active ? Colors.blue.shade600 : Colors.grey.shade300,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          minimumSize: const Size(0, 36),
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

    StylishDialog.show(
      context: context,
      title: "SELECT ARCHIVE PERIOD",
      maxWidth: 450,
      builder: (context, setPopupState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "View schedules from a previous month and year.",
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Year",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: selectedYear,
                        decoration: const InputDecoration(
                          fillColor: Color(0xFFF8FAFC),
                        ),
                        onChanged: (y) =>
                            setPopupState(() => selectedYear = y!),
                        items:
                            List.generate(
                                  5,
                                  (index) => DateTime.now().year - index,
                                )
                                .map(
                                  (y) => DropdownMenuItem(
                                    value: y,
                                    child: Text(y.toString()),
                                  ),
                                )
                                .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Month",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: selectedMonth,
                        decoration: const InputDecoration(
                          fillColor: Color(0xFFF8FAFC),
                        ),
                        onChanged: (m) =>
                            setPopupState(() => selectedMonth = m!),
                        items: List.generate(12, (index) => index + 1)
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(
                                  DateFormat('MMMM').format(DateTime(2024, m)),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "View Records",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
