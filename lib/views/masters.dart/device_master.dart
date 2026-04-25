import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../widgets/animated_heading.dart';

class DeviceMasterView extends StatefulWidget {
  const DeviceMasterView({super.key});

  @override
  State<DeviceMasterView> createState() => _DeviceMasterViewState();
}

class _DeviceMasterViewState extends State<DeviceMasterView> {
  // --- API CONFIGURATION ---
  final String _apiKey =
      "933cdb13cb54e31e694f82bf7f75f0144a9495036db0243b85dd855be53c06f2";
  final String _baseUrl = "https://display.sriher.com";

  // --- STATE MANAGEMENT ---
  List<dynamic> deviceList = [];
  bool isLoading = true;
  String entriesValue = "10";
  int? editingId;

  // --- FORM CONTROLLERS ---
  final TextEditingController _deviceCodeController = TextEditingController();
  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _osController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _warrantyController = TextEditingController();
  final TextEditingController _serialNoController = TextEditingController();
  final TextEditingController _manufacturerController = TextEditingController();
  String? selectedDeviceType;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await fetchDevices();
  }

  @override
  void dispose() {
    _deviceCodeController.dispose();
    _deviceNameController.dispose();
    _modelController.dispose();
    _osController.dispose();
    _yearController.dispose();
    _warrantyController.dispose();
    _serialNoController.dispose();
    _manufacturerController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // --- API INTEGRATION METHODS ---
  // ──────────────────────────────────────────────────────────────────────────

  // 1. FETCH DEVICE LIST
  Future<void> fetchDevices() async {
    setState(() => isLoading = true);
    final url = Uri.parse('$_baseUrl/deviceview');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"api_key": _apiKey}),
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        // Debug logging to help identify correct keys
        debugPrint("API Response: $decoded");

        setState(() {
          if (decoded is List) {
            deviceList = decoded;
          } else if (decoded is Map) {
            final data = decoded['data'];
            if (data is Map) {
              deviceList = (data['DeviceMasters'] is List)
                  ? data['DeviceMasters']
                  : [];
            } else if (data is List) {
              deviceList = data;
            } else {
              final otherPossibility =
                  decoded['device_list'] ?? decoded['device_data'];
              deviceList = (otherPossibility is List) ? otherPossibility : [];
            }
          } else {
            deviceList = [];
          }
          isLoading = false;
        });
      } else {
        _showSnackBar("Server Error: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      _showSnackBar("Network Error: $e");
      setState(() => isLoading = false);
    }
  }

  // 2. INSERT OR UPDATE DEVICE
  Future<void> handleFormSubmit() async {
    // Basic Validation
    if (_deviceCodeController.text.isEmpty ||
        _deviceNameController.text.isEmpty) {
      _showSnackBar("Please fill the Device ID and Name");
      return;
    }

    final bool isUpdate = editingId != null;
    final String endPoint = isUpdate
        ? '/deviceUpdateview'
        : '/insertDeviceview';
    final url = Uri.parse('$_baseUrl$endPoint');

    final Map<String, dynamic> body = {
      "api_key": _apiKey,
      "device_code": _deviceCodeController.text,
      "device_name": _deviceNameController.text,
      "device_model": _modelController.text,
      "device_os": _osController.text,
      "device_yr_model": _yearController.text,
      "device_warranty": _warrantyController.text,
      "device_s_no": _serialNoController.text,
      "Manufacture": _manufacturerController.text,
      "type_of_device": selectedDeviceType ?? "Android Smart TV",
    };

    if (isUpdate) {
      body["id"] = editingId; // Send as integer per user example
    }

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final status = resData['status']?.toString().toLowerCase();
        // Sriher API uses 'Success', '1', or sometimes just status: 1
        if (status == 'success' || status == '1' || resData['status'] == 1) {
          _showSnackBar(
            isUpdate
                ? "Device Updated Successfully"
                : "Device Created Successfully",
          );
          _clearForm();
          if (mounted && Navigator.canPop(context)) Navigator.pop(context);
          await fetchDevices(); // Ensure we await the refresh
        } else {
          _showSnackBar(
            "Server Error: ${resData['Message'] ?? resData['message'] ?? 'Unknown Error'}",
          );
        }
      }
    } catch (e) {
      _showSnackBar("Error sending data: $e");
    }
  }

  // 3. EDIT DEVICE (FETCH SINGLE DATA)
  Future<void> loadDeviceToEdit(dynamic id) async {
    final url = Uri.parse('$_baseUrl/deviceEditview');
    try {
      final intId = int.tryParse(id.toString());
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"api_key": _apiKey, "id": intId ?? id}),
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        final device = (data is Map)
            ? (data['device_data'] ?? data['data'])
            : null;

        if (device != null && device is Map) {
          setState(() {
            editingId = intId ?? (id is int ? id : null);
            _deviceCodeController.text =
                device['device_code']?.toString() ?? "";
            _deviceNameController.text =
                device['device_name']?.toString() ?? "";
            _modelController.text = device['device_model']?.toString() ?? "";
            _osController.text = device['device_os']?.toString() ?? "";
            _yearController.text = device['device_yr_model']?.toString() ?? "";
            _warrantyController.text =
                device['device_warranty']?.toString() ?? "";
            _serialNoController.text = device['device_s_no']?.toString() ?? "";
            _manufacturerController.text =
                device['Manufacture']?.toString() ?? "";
            selectedDeviceType = device['type_of_device']?.toString();
          });
          _showDeviceDialog(); // Open dialog after data is loaded
        } else {
          _showSnackBar("Could not find device details on server");
        }
      } else {
        _showSnackBar("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      _showSnackBar("Error loading details for edit: $e");
    }
  }

  // 4. DELETE DEVICE
  Future<void> deleteDevice(dynamic id) async {
    // Using the specific local URL provided by the user for delete
    final url = Uri.parse('http://127.0.0.1:8001/deleteDeviceview');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "api_key": _apiKey,
          "id": int.tryParse(id.toString()) ?? id,
        }),
      );

      if (response.statusCode == 200) {
        _showSnackBar("Device deleted successfully");
        fetchDevices();
      } else {
        _showSnackBar("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      _showSnackBar("Delete request failed: $e");
    }
  }

  void _clearForm() {
    setState(() {
      editingId = null;
      _deviceCodeController.clear();
      _deviceNameController.clear();
      _modelController.clear();
      _osController.clear();
      _yearController.clear();
      _warrantyController.clear();
      _serialNoController.clear();
      _manufacturerController.clear();
      selectedDeviceType = null;
    });
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // ──────────────────────────── POPUP DIALOG ────────────────────────────────

  void _showDeviceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              titlePadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF000000),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      editingId == null
                          ? "Create New Device"
                          : "Edit Device Details",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        _clearForm();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.7,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownField(
                              hint: "Type of Device",
                              value: selectedDeviceType,
                              items: [
                                "Android Smart TV",
                                "LED Display",
                                "Projector",
                                "Linux Player",
                              ],
                              onChanged: (val) {
                                setDialogState(() => selectedDeviceType = val);
                                setState(() => selectedDeviceType = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTextField(
                              "Device ID/Code",
                              _deviceCodeController,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTextField(
                              "Device Name",
                              _deviceNameController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              "Model Number",
                              _modelController,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTextField("OS System", _osController),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTextField(
                              "Year of Model",
                              _yearController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              "Warranty Status",
                              _warrantyController,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTextField(
                              "Serial Number",
                              _serialNoController,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTextField(
                              "Manufacturer",
                              _manufacturerController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              actions: [
                OutlinedButton(
                  onPressed: () {
                    _clearForm();
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await handleFormSubmit();
                  },
                  child: Text(
                    editingId == null ? "Save Device" : "Update Device",
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // --- UI BUILDING METHODS ---
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const AnimatedHeading(
                  text: "Device List",
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showDeviceDialog,
                  icon: const Icon(Icons.add_to_queue_rounded, size: 20),
                  label: const Text(
                    "CREATE DEVICE",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // List Card
            Expanded(child: _buildTableCard()),
          ],
        ),
      ),
    );
  }

  // Form Section Replaced by inline build in the expanded view for better theme control
  Widget _buildFormSection() {
    return const SizedBox.shrink(); // No longer used directly
  }

  Widget _buildTableCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildListHeaderControls(),
            const SizedBox(height: 16),

            // The Scrollable Table Container
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white10),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        if (isLoading)
                          const LinearProgressIndicator(
                            minHeight: 3,
                            backgroundColor: Colors.transparent,
                            color: Colors.white24,
                          ),

                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                ),
                                child: DataTable(
                                  columnSpacing: 20,
                                  headingRowHeight: 45,
                                  headingRowColor: WidgetStateProperty.all(
                                    Colors.blue.shade50,
                                  ),
                                  border: TableBorder.all(
                                    color: Colors.white10,
                                  ),
                                  columns: _getColumns(),
                                  rows: deviceList
                                      .map((device) => _getDataRow(device))
                                      .toList(),
                                ),
                              ),
                            ),
                          ),
                        ),

                        if (!isLoading && deviceList.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Center(
                              child: Text(
                                "No devices found.",
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),
            _buildTableFooter(),
          ],
        ),
      ),
    );
  }

  List<DataColumn> _getColumns() {
    return [
          'Type of device',
          'Device ID',
          'Name',
          'Model',
          'OS',
          'Year of Model',
          'Warranty',
          'Serial No',
          'Edit',
          'Action',
        ]
        .map(
          (title) => DataColumn(
            label: Text(
              title,
              style: TextStyle(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        )
        .toList();
  }

  DataRow _getDataRow(dynamic device) {
    // Ensure device is treated as a Map for safe access
    final Map<String, dynamic> data = (device is Map)
        ? Map<String, dynamic>.from(device)
        : {};

    // Robust key search to handle server-side camelCase or snake_case variations
    String val(List<String> keys) {
      for (var k in keys) {
        if (data.containsKey(k) && data[k] != null) return data[k].toString();
      }
      return "-";
    }

    return DataRow(
      cells: [
        DataCell(
          Text(
            val(['type_of_device', 'typeOfDevice', 'device_type', 'type']),
            style: const TextStyle(color: Colors.black87),
          ),
        ),
        DataCell(
          Text(
            val(['device_code', 'deviceCode', 'code']),
            style: const TextStyle(color: Colors.black87),
          ),
        ),
        DataCell(
          Text(
            val(['device_name', 'deviceName', 'name']),
            style: const TextStyle(color: Colors.black87),
          ),
        ),
        DataCell(
          Text(
            val(['device_model', 'deviceModel', 'model']),
            style: const TextStyle(color: Colors.black87),
          ),
        ),
        DataCell(
          Text(
            val(['device_os', 'deviceOs', 'os']),
            style: const TextStyle(color: Colors.black87),
          ),
        ),
        DataCell(
          Text(
            val(['device_yr_model', 'deviceYrModel', 'year', 'year_of_model']),
            style: const TextStyle(color: Colors.black87),
          ),
        ),
        DataCell(
          Text(
            val(['device_warranty', 'deviceWarranty', 'warranty']),
            style: const TextStyle(color: Colors.black87),
          ),
        ),
        DataCell(
          Text(
            val(['device_s_no', 'deviceSNo', 'serial_number', 'serial']),
            style: const TextStyle(color: Colors.black87),
          ),
        ),
        DataCell(
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue, size: 18),
            onPressed: () => loadDeviceToEdit(data['id'] ?? data['ID']),
          ),
        ),

        DataCell(
          Transform.scale(
            scale: 0.7,
            child: Switch(
              // Use active_status or status based on your API
              value:
                  data['active_status'] == 1 ||
                  data['status'] == 1 ||
                  data['status'] == "1",
              activeColor: Colors.green,
              onChanged: (v) {
                // Status toggle logic would go here
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- REUSABLE COMPONENTS ---

  Widget _buildTextField(String hint, TextEditingController controller) {
    return SizedBox(
      height: 42,
      child: TextFormField(
        controller: controller,
        style: const TextStyle(fontSize: 13, color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
          border: const OutlineInputBorder(),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String hint,
    String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      height: 42,
      child: DropdownButtonFormField<String>(
        value: value,
        hint: Text(
          hint,
          style: const TextStyle(fontSize: 12, color: Colors.white),
        ),
        dropdownColor: Colors.white,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        items: items
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Text(e, style: const TextStyle(fontSize: 13)),
              ),
            )
            .toList(),
        onChanged: onChanged,
        isExpanded: true,
      ),
    );
  }

  Widget _buildListHeaderControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text(
              "Show ",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
            SizedBox(
              width: 70,
              height: 35,
              child: DropdownButtonFormField<String>(
                value: entriesValue,
                dropdownColor: Colors.white,
                style: const TextStyle(color: Colors.black87, fontSize: 13),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 5),
                ),
                items: ["10", "25", "50"]
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => entriesValue = v!),
              ),
            ),
            const Text(
              " entries",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        SizedBox(
          width: 250,
          height: 40,
          child: TextField(
            onChanged: (val) {
              setState(() {
                // TODO: Implement actual filtering
              });
            },
            decoration: InputDecoration(
              hintText: "Search Devices...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Showing 1 to ${deviceList.length} of ${deviceList.length} entries",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: Colors.white54,
          ),
        ),
        Row(
          children: [
            _buildPageBtn("Previous"),
            const SizedBox(width: 4),
            _buildPageBtn("1", active: true),
            const SizedBox(width: 4),
            _buildPageBtn("Next"),
          ],
        ),
      ],
    );
  }

  Widget _buildPageBtn(String label, {bool active = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: active ? Colors.blue : Colors.grey.shade100,
          foregroundColor: active ? Colors.white : Colors.black87,
          side: active
              ? const BorderSide(color: Colors.blue)
              : BorderSide(color: Colors.grey.shade300),
          padding: EdgeInsets.symmetric(horizontal: label.length > 1 ? 15 : 12),
          minimumSize: const Size(40, 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: () {},
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _confirmDeletion(dynamic id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: const Text(
          "Are you sure you want to remove this device from the records?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              deleteDevice(id);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}
