import 'package:flutter/material.dart';

class CopyWipeoffView extends StatefulWidget {
  const CopyWipeoffView({super.key});

  @override
  State<CopyWipeoffView> createState() => _CopyWipeoffViewState();
}

class _CopyWipeoffViewState extends State<CopyWipeoffView> {
  String? selectedSourceDevice;
  String? selectedAssignDevice;
  String? selectedWipeDevice;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Using Expanded here ensures the content stays at the top
        // while allowing scrolling if the screen gets too small.
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3), // Big Card Black
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Copying schedule - Devices",
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
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildDropdown(
                                  hintText: "Select Device Name",
                                  value: selectedSourceDevice,
                                  onChanged: (val) =>
                                      setState(() => selectedSourceDevice = val),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: _buildDropdown(
                                  hintText: "Select Assign Device",
                                  value: selectedAssignDevice,
                                  onChanged: (val) =>
                                      setState(() => selectedAssignDevice = val),
                                ),
                              ),
                              const SizedBox(width: 20),
                              SizedBox(
                                height: 45,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF000000),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 32),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(4)),
                                  ),
                                  onPressed: () {},
                                  child: const Text("SUBMIT",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // --- BOTTOM SECTION: Wipe Off Section ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3), // Big Card Black
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column( 
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Wipe Off Schedule",
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
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.4,
                                child: _buildDropdown(
                                  hintText: "Select Device Name",
                                  value: selectedWipeDevice,
                                  onChanged: (val) =>
                                      setState(() => selectedWipeDevice = val),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 45,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 32),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(4)),
                                  ),
                                  onPressed: () {},
                                  child: const Text("SUBMIT",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
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
        // Removed the Spacer with flex 0 to fix the error.
        // The Expanded above will keep everything pushed to the top.
      ],
    );
  }

  Widget _buildDropdown({
    required String hintText,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      height: 45,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        hint: Text(hintText, style: const TextStyle(fontSize: 14)),
        isExpanded: true,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        ),
        items: ['Device 01', 'Device 02', 'Device 03']
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}