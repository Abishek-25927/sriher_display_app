import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AssignDeviceView extends StatefulWidget {
  const AssignDeviceView({super.key});

  @override
  State<AssignDeviceView> createState() => _AssignDeviceViewState();
}

class _AssignDeviceViewState extends State<AssignDeviceView>
    with SingleTickerProviderStateMixin {
  final String _baseUrl = "https://display.sriher.com";
  final String _apiKey =
      "933cdb13cb54e31e694f82bf7f75f0144a9495036db0243b85dd855be53c06f2";

  List<dynamic> deviceList = [];
  List<dynamic> scheduleList = [];
  List<dynamic> assignedList = [];
  bool isLoadingDevices = false;
  bool isLoadingSchedules = false;
  bool isLoadingAssigned = false;

  int? selectedDeviceId;
  int? selectedScheduleId;
  DateTime today = DateTime.now();
  int? selectedDay;

  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    selectedDay = today.day;
    _fetchDevices();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchDevices() async {
    setState(() => isLoadingDevices = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/assignDevice_deviceListview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"api_key": _apiKey}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => deviceList = data['data'] ?? []);
      }
    } catch (e) {
      debugPrint("Error fetching devices: $e");
    } finally {
      setState(() => isLoadingDevices = false);
    }
  }

  Future<void> _fetchSchedules(int deviceId) async {
    setState(() => isLoadingSchedules = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/assignDevice_scheduleListview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"api_key": _apiKey, "device_id": deviceId}),
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

  Future<void> _fetchAssignedSchedules(int deviceId) async {
    setState(() => isLoadingAssigned = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/assignDevice_assignedListview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"api_key": _apiKey, "device_id": deviceId}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => assignedList = data['data'] ?? []);
      }
    } catch (e) {
      debugPrint("Error fetching assigned schedules: $e");
    } finally {
      setState(() => isLoadingAssigned = false);
    }
  }

  Future<void> _handleAssignmentSubmit() async {
    if (selectedDeviceId == null || selectedScheduleId == null) return;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/assignDevice_insertview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "api_key": _apiKey,
          "device_id": selectedDeviceId,
          "schedule_id": selectedScheduleId,
        }),
      );
      if (response.statusCode == 200) {
        _fetchAssignedSchedules(selectedDeviceId!);
        _showSnackBar("Assigned Successfully");
      }
    } catch (e) {
      debugPrint("Error submitting assignment: $e");
    }
  }

  Future<void> _handleAssignmentRemove(int scheduleId) async {
    if (selectedDeviceId == null) return;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/assignDevice_removeview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "api_key": _apiKey,
          "device_id": selectedDeviceId,
          "schedule_id": scheduleId,
        }),
      );
      if (response.statusCode == 200) {
        _fetchAssignedSchedules(selectedDeviceId!);
        _showSnackBar("Removed Successfully");
      }
    } catch (e) {
      debugPrint("Error removing assignment: $e");
    }
  }

  void _showSnackBar(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3), // Big Card Black
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Assign schedule for device",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                Card(
                  color: Colors.white, // Inner Small Card White
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        // --- TOP ROW ---
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdown(
                                hint: "Select Device Name",
                                value: selectedDeviceId,
                                items: deviceList,
                                onChanged: (val) {
                                  setState(() {
                                    selectedDeviceId = val;
                                    selectedScheduleId = null;
                                    scheduleList = [];
                                    assignedList = [];
                                  });
                                  if (val != null) {
                                    _fetchSchedules(val);
                                    _fetchAssignedSchedules(val);
                                    _controller.forward(from: 0.0);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: _buildDropdown(
                                hint: "Select Schedule Name",
                                value: selectedScheduleId,
                                items: scheduleList,
                                onChanged: (val) =>
                                    setState(() => selectedScheduleId = val),
                              ),
                            ),
                            const SizedBox(width: 15),
                            SizedBox(
                              height: 40,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF000000),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                onPressed:
                                    (selectedDeviceId != null &&
                                        selectedScheduleId != null)
                                    ? _handleAssignmentSubmit
                                    : null,
                                child: const Text(
                                  "SUBMIT",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // --- LEFT-TO-RIGHT ANIMATED CALENDAR ---
                        if (selectedDeviceId != null)
                          FadeTransition(
                            opacity: _opacityAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: Column(
                                children: [
                                  const SizedBox(height: 15),
                                  const Divider(thickness: 1),
                                  const SizedBox(height: 15),
                                  _buildCagedCalendar(),
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
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildCagedCalendar() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Calendar (Narrower width)
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: _buildSmallCalendar(),
            ),
          ),
          // Vertical Divider
          Container(width: 1, height: 220, color: Colors.grey.shade300),
          // Right: Side Box
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: _buildScheduleSideBox(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String hint,
    int? value,
    required List<dynamic> items,
    required ValueChanged<int?> onChanged,
  }) {
    return SizedBox(
      height: 40,
      child: DropdownButtonFormField<int>(
        initialValue: value,
        hint: Text(hint, style: const TextStyle(fontSize: 13)),
        isExpanded: true,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 10),
        ),
        items: items.map((e) {
          final id = int.tryParse(e['id'].toString());
          final name =
              e['device_name'] ?? e['schedule_name'] ?? e['device_code'] ?? '';
          return DropdownMenuItem<int>(
            value: id,
            child: Text(name, style: const TextStyle(fontSize: 13)),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSmallCalendar() {
    int daysInMonth = DateTime(today.year, today.month + 1, 0).day;
    return Column(
      children: [
        const Text(
          "February 2026",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black,
          ),
        ),

        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            childAspectRatio: 1.4,
          ),
          itemCount: daysInMonth,
          itemBuilder: (context, index) {
            int day = index + 1;
            bool isSelected = day == selectedDay;
            // Check if this day has an assigned schedule
            bool hasAssignment = assignedList.any(
              (a) => int.tryParse(a['day']?.toString() ?? '') == day,
            );

            return InkWell(
              onTap: () => setState(() => selectedDay = day),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.deepPurple.withValues(alpha: 0.1)
                      : (hasAssignment
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.transparent),
                  border: isSelected
                      ? Border.all(color: Colors.deepPurple, width: 1)
                      : (hasAssignment
                            ? Border.all(color: Colors.green, width: 1)
                            : null),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  "$day",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: (isSelected || hasAssignment)
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: hasAssignment ? Colors.green : Colors.black,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildScheduleSideBox() {
    final dayAssignment = assignedList.firstWhere(
      (a) => int.tryParse(a['day']?.toString() ?? '') == selectedDay,
      orElse: () => null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "February $selectedDay, 2026",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: dayAssignment != null
                ? Colors.green.withValues(alpha: 0.1)
                : const Color(0xFFE0B0FF).withValues(alpha: 0.2),
            border: Border.all(
              color: dayAssignment != null
                  ? Colors.green.withValues(alpha: 0.3)
                  : const Color(0xFFE0B0FF).withValues(alpha: 0.4),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dayAssignment != null
                    ? (dayAssignment['schedule_name'] ?? 'Assigned')
                    : "No Schedule for today",
                style: TextStyle(
                  fontSize: 10,
                  color: dayAssignment != null
                      ? Colors.green.shade800
                      : Colors.black54,
                  fontWeight: dayAssignment != null
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontStyle: dayAssignment != null
                      ? FontStyle.normal
                      : FontStyle.italic,
                ),
              ),
              if (dayAssignment != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () =>
                        _handleAssignmentRemove(dayAssignment['schedule_id']),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 20),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      "Remove",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
