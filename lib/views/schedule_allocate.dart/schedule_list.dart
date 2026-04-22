import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ScheduleListView extends StatefulWidget {
  const ScheduleListView({super.key});

  @override
  State<ScheduleListView> createState() => _ScheduleListViewState();
}

class _ScheduleListViewState extends State<ScheduleListView> {
  final String _baseUrl = "https://display.sriher.com";
  final String _apiKey = "933cdb13cb54e31e694f82bf7f75f0144a9495036db0243b85dd855be53c06f2";

  List<dynamic> scheduleData = [];
  bool isLoading = true;
  String entriesValue = "10";
  bool showActive = true; // Toggle between Active and Inactive APIs

  @override
  void initState() {
    super.initState();
    _fetchSchedules();
  }

  // ──────────────────────────── API CALLS ────────────────────────────────────

  Future<void> _fetchSchedules() async {
    setState(() => isLoading = true);
    final endpoint = showActive ? "scheduleList_activeListview" : "scheduleList_inactiveListview";
    
    Map<String, dynamic> body = {"api_key": _apiKey};
    if (!showActive) {
      body["from_date"] = "2026-01-01"; 
      body["to_date"] = "2026-03-31";
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/$endpoint'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
    ));
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
                        showActive ? "ACTIVE SCHEDULE LIST" : "INACTIVE SCHEDULE LIST",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade800,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          setState(() => showActive = !showActive);
                          _fetchSchedules();
                        },
                        icon: Icon(showActive ? Icons.history : Icons.check_circle),
                        label: Text(showActive ? "View Inactive" : "View Active"),
                      )
                    ],
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildListHeader(),
                            const SizedBox(height: 16),
                            Expanded(
                              child: isLoading
                                  ? const Center(child: CircularProgressIndicator())
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
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width * 0.9),
          child: DataTable(
            border: TableBorder.all(color: Colors.grey.shade300),
            headingRowHeight: 50,
            dataRowMaxHeight: 55,
            headingRowColor: WidgetStateProperty.all(const Color(0xFF000000)), // BLACK HEADER
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

    return DataRow(cells: [
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
      DataCell(
        Center(
          child: _buildChangesButton(item),
        ),
      ),
    ]);
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
          _showSnack("Edit clicked for ${item['schedule_name']}");
        } else if (value == 'extend') {
          _showSnack("Extend clicked for ${item['schedule_name']}");
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
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
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
            const Text("Show ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            SizedBox(
              width: 75,
              height: 38,
              child: DropdownButtonFormField<String>(
                value: entriesValue,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  border: OutlineInputBorder(),
                ),
                items: ['10', '25', '50'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setState(() => entriesValue = v!),
              ),
            ),
             
            const Text(" entries", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        SizedBox(
          width: 220,
          height: 38,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search Schedule...',
              hintStyle: const TextStyle(fontSize: 12),
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
          style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 12),
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

  Widget _buildPageBtn(String label, {bool active = false, bool enabled = true}) {
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
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}