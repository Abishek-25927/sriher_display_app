import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../widgets/animated_heading.dart';

class CopyWipeoffView extends StatefulWidget {
  const CopyWipeoffView({super.key});

  @override
  State<CopyWipeoffView> createState() => _CopyWipeoffViewState();
}

class _CopyWipeoffViewState extends State<CopyWipeoffView> {
  final String _baseUrl = "https://display.sriher.com";
  final String _apiKey =
      "933cdb13cb54e31e694f82bf7f75f0144a9495036db0243b85dd855be53c06f2";

  List<dynamic> deviceList = [];
  List<dynamic> sourceSchedules = [];

  String? selectedSourceDeviceId;
  String? selectedTargetDeviceId;
  String? selectedWipeDeviceId;

  bool isLoadingDevices = false;
  bool isLoadingSchedules = false;
  bool isCheckingConflicts = false;
  bool isSubmitingCopy = false;
  bool isSubmitingWipe = false;

  String? conflictMessage;
  bool hasConflict = false;

  @override
  void initState() {
    super.initState();
    _fetchDeviceList();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // API CALLS
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _fetchDeviceList() async {
    setState(() => isLoadingDevices = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/copyWipe_deviceListview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"api_key": _apiKey}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          deviceList = data['data'] ?? [];
        });
      }
    } catch (e) {
      _showSnackBar("Error fetching devices: $e");
    } finally {
      setState(() => isLoadingDevices = false);
    }
  }

  Future<void> _fetchDeviceSchedules(String deviceId) async {
    setState(() => isLoadingSchedules = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/copyWipe_deviceSchedulesview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"api_key": _apiKey, "device_id": deviceId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          sourceSchedules = data['data'] ?? [];
        });
      }
    } catch (e) {
      _showSnackBar("Error fetching schedules: $e");
    } finally {
      setState(() => isLoadingSchedules = false);
    }
  }

  Future<void> _checkConflicts() async {
    if (selectedSourceDeviceId == null || selectedTargetDeviceId == null)
      return;
    if (selectedSourceDeviceId == selectedTargetDeviceId) {
      setState(() {
        hasConflict = true;
        conflictMessage = "Source and Target devices cannot be the same.";
      });
      return;
    }

    setState(() => isCheckingConflicts = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/copyWipe_checkConflictview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "api_key": _apiKey,
          "source_device_id": selectedSourceDeviceId,
          "target_device_id": selectedTargetDeviceId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          hasConflict = data['conflict'] == true;
          conflictMessage = data['message'];
        });
      }
    } catch (e) {
      _showSnackBar("Error checking conflicts: $e");
    } finally {
      setState(() => isCheckingConflicts = false);
    }
  }

  Future<void> _copySchedule() async {
    if (selectedSourceDeviceId == null || selectedTargetDeviceId == null) {
      _showSnackBar("Please select both source and target devices.");
      return;
    }

    setState(() => isSubmitingCopy = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/copyWipe_copyScheduleview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "api_key": _apiKey,
          "source_device_id": selectedSourceDeviceId,
          "target_device_id": selectedTargetDeviceId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _showSnackBar(data['message'] ?? "Schedules copied successfully!");
        setState(() {
          selectedSourceDeviceId = null;
          selectedTargetDeviceId = null;
          sourceSchedules = [];
          hasConflict = false;
          conflictMessage = null;
        });
      }
    } catch (e) {
      _showSnackBar("Error copying schedules: $e");
    } finally {
      setState(() => isSubmitingCopy = false);
    }
  }

  Future<void> _wipeOff() async {
    if (selectedWipeDeviceId == null) {
      _showSnackBar("Please select a device to wipe.");
      return;
    }

    // Show confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Wipe Off"),
        content: const Text(
          "Are you sure you want to permanently remove ALL schedules from this device? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("WIPE EVERYTHING"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isSubmitingWipe = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/copyWipe_wipeOffview'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "api_key": _apiKey,
          "device_id": selectedWipeDeviceId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _showSnackBar(data['message'] ?? "Schedules wiped successfully!");
        setState(() {
          selectedWipeDeviceId = null;
        });
      }
    } catch (e) {
      _showSnackBar("Error wiping schedules: $e");
    } finally {
      setState(() => isSubmitingWipe = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // UI BUILDERS
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- COPY SECTION ---
          const AnimatedHeading(text: "Copy Schedule Settings"),
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
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.blue.shade50),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.copy_all, color: Colors.blue, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      "Devices Synchronization",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        label: "Source Device",
                        hintText: "Select device to copy from",
                        value: selectedSourceDeviceId,
                        items: deviceList,
                        onChanged: (val) {
                          setState(() {
                            selectedSourceDeviceId = val;
                            sourceSchedules = [];
                            hasConflict = false;
                            conflictMessage = null;
                          });
                          if (val != null) {
                            _fetchDeviceSchedules(val);
                            _checkConflicts();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildDropdown(
                        label: "Target Device",
                        hintText: "Select device to assign to",
                        value: selectedTargetDeviceId,
                        items: deviceList,
                        onChanged: (val) {
                          setState(() {
                            selectedTargetDeviceId = val;
                            hasConflict = false;
                            conflictMessage = null;
                          });
                          _checkConflicts();
                        },
                      ),
                    ),
                    const SizedBox(width: 24),
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        onPressed: (isSubmitingCopy || isCheckingConflicts)
                            ? null
                            : _copySchedule,
                        child: isSubmitingCopy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "COPY SCHEDULE",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
                if (conflictMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: hasConflict
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasConflict
                            ? Colors.red.shade200
                            : Colors.green.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasConflict
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline,
                          color: hasConflict
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            conflictMessage!,
                            style: TextStyle(
                              color: hasConflict
                                  ? Colors.red.shade900
                                  : Colors.green.shade900,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isLoadingSchedules)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (sourceSchedules.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Text(
                    "Schedules included in copy:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: sourceSchedules.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final schedule = sourceSchedules[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            schedule['schedule_name'] ?? 'Unnamed Schedule',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            "${schedule['from_date']} to ${schedule['to_date']} | ${schedule['from_time']} - ${schedule['to_time']}",
                          ),
                          trailing: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 48),

          // --- WIPE OFF SECTION ---
          const AnimatedHeading(text: "Wipe Off Schedule"),
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
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.red.shade50),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.delete_sweep, color: Colors.red, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      "Clear Device Schedule",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildDropdown(
                        label: "Select Device",
                        hintText: "Select device to wipe completely",
                        value: selectedWipeDeviceId,
                        items: deviceList,
                        onChanged: (val) =>
                            setState(() => selectedWipeDeviceId = val),
                      ),
                    ),
                    const SizedBox(width: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      onPressed: isSubmitingWipe ? null : _wipeOff,
                      child: isSubmitingWipe
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "WIPE ALL SCHEDULES",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          "Warning: This will permanently stop all playback and remove all assignments on the selected device.",
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String hintText,
    required String? value,
    required List<dynamic> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.blue.shade900,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.any((i) => i['id'].toString() == value)
                  ? value
                  : null,
              hint: Text(
                hintText,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
              isExpanded: true,
              dropdownColor: Colors.white,
              menuMaxHeight: 300,
              style: const TextStyle(color: Colors.black87),
              items: items
                  .map(
                    (item) => DropdownMenuItem(
                      value: item['id'].toString(),
                      child: Text(
                        item['device_name'] ??
                            item['Device_name'] ??
                            'Unknown Device',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
