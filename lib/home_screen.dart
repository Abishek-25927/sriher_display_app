import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'widgets/animated_background.dart';

// Existing Imports
import 'package:sriher_display_application/views/dashboard_view.dart';
import 'package:sriher_display_application/views/authentication/add_user_view.dart';
import 'package:sriher_display_application/views/file_master.dart/file_upload.dart';
import 'package:sriher_display_application/views/template_master.dart/create_template.dart';
import 'package:sriher_display_application/views/template_master.dart/default_template.dart';
import 'package:sriher_display_application/views/template_master.dart/select_template.dart';
import 'package:sriher_display_application/views/schedule_allocate.dart/schedule_allocate_main.dart';
import 'package:sriher_display_application/views/schedule_allocate.dart/assign_device.dart';
import 'package:sriher_display_application/views/schedule_allocate.dart/schedule_list.dart';
import 'package:sriher_display_application/views/schedule_allocate.dart/specific_ranges.dart';
import 'package:sriher_display_application/views/schedule_allocate.dart/copy_wipeoff.dart';
import 'package:sriher_display_application/views/masters.dart/role.dart';
import 'package:sriher_display_application/views/masters.dart/device_master.dart';
import 'package:sriher_display_application/views/masters.dart/department.dart';
import 'package:sriher_display_application/views/masters.dart/location_master.dart';
import 'package:sriher_display_application/views/masters.dart/mapping.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  int _previousIndex = 0;
  String? _userName;
  String? _userRole;

  late AnimationController _sidebarController;
  late AnimationController _viewController;
  late Animation<double> _sidebarFade;
  late Animation<Offset> _sidebarSlide;
  late Animation<double> _viewFade;
  late Animation<Offset> _viewSlide;

  @override
  void initState() {
    super.initState();

    // Sidebar entry animation
    _sidebarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _sidebarFade = CurvedAnimation(parent: _sidebarController, curve: Curves.easeOut);
    _sidebarSlide = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _sidebarController, curve: Curves.easeOutCubic));

    // View content transition
    _viewController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _viewFade = CurvedAnimation(parent: _viewController, curve: Curves.easeOut);
    _viewSlide = Tween<Offset>(
      begin: const Offset(0.04, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _viewController, curve: Curves.easeOutCubic));

    _sidebarController.forward();
    _viewController.forward();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName');
      _userRole = prefs.getString('userRole');
    });
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
  @override
  void dispose() {
    _sidebarController.dispose();
    _viewController.dispose();
    super.dispose();
  }

  void _selectIndex(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _previousIndex = _selectedIndex;
      _selectedIndex = index;
    });
    _viewController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // --- GLOBAL HEADER ---
          Container(
            decoration: const BoxDecoration(
              color: Colors.black, // Dark Theme Header
              boxShadow: [
                BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 2)),
              ],
            ),
            padding: const EdgeInsets.only(left: 16, right: 16, top: 18, bottom: 8),
            child: Row(
              children: [
                _buildDynamicHeader(),
                const Spacer(),
                // User name chip with avatar
                if (_userName != null)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutBack,
                    builder: (context, v, child) =>
                        Transform.scale(scale: v, child: child),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A), // Darker chip
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF333333)), // Subtle border
                      ),
                      child: Text(
                        _userName!,
                        style: const TextStyle(
                          color: Colors.white, // White text
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                // Animated power button (Logout)
                _AnimatedIconButton(
                  icon: Icons.logout_rounded,
                  color: Colors.white70, // White icon
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // --- MAIN CONTENT ---
          Expanded(
            child: Row(
              children: [
                // --- Animated Sidebar ---
                SlideTransition(
                  position: _sidebarSlide,
                  child: FadeTransition(
                    opacity: _sidebarFade,
                    child: Container(
                      width: 230,
                      margin: const EdgeInsets.only(left: 12, bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4), // Glassmorphism dark
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              children: [
                                Image.asset(
                                  'assets/images/sriher_logo.png',
                                  height: 24,
                                  width: 24,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.display_settings, size: 24, color: Color(0xFF64FFDA)),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  "SRIHER Display",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                           const Divider(color: Colors.white12),
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                _buildSidebarItem(Icons.dashboard, 'Dashboard', 0),

                                // Authentication
                                _buildExpansionTile(
                                  icon: Icons.security,
                                  title: 'Authentication',
                                  children: [
                                    _buildSidebarItem(Icons.person_add, 'Add User', 1, isSub: true),
                                  ],
                                ),

                                // Masters
                                _buildExpansionTile(
                                  icon: Icons.storage,
                                  title: 'Masters',
                                  initiallyExpanded: _selectedIndex >= 11,
                                  children: [
                                    _buildSidebarItem(Icons.admin_panel_settings, 'Role', 11, isSub: true),
                                    _buildSidebarItem(Icons.devices, 'Device Master', 12, isSub: true),
                                    _buildSidebarItem(Icons.domain, 'Department', 13, isSub: true),
                                    _buildSidebarItem(Icons.location_on, 'Location Master', 14, isSub: true),
                                    _buildSidebarItem(Icons.map, 'Mapping', 15, isSub: true),
                                  ],
                                ),

                                // File Master
                                _buildExpansionTile(
                                  icon: Icons.folder,
                                  title: 'File Master',
                                  children: [
                                    _buildSidebarItem(Icons.upload_file, 'File Upload', 2, isSub: true),
                                  ],
                                ),

                                // Template Master
                                _buildExpansionTile(
                                  icon: Icons.art_track,
                                  title: 'Template Master',
                                  initiallyExpanded: _selectedIndex >= 3 && _selectedIndex <= 5,
                                  children: [
                                    _buildSidebarItem(Icons.create, 'Create Template', 3, isSub: true),
                                    _buildSidebarItem(Icons.branding_watermark, 'Default Template', 4, isSub: true),
                                    _buildSidebarItem(Icons.select_all, 'Select Template', 5, isSub: true),
                                  ],
                                ),

                                // Schedule
                                _buildExpansionTile(
                                  icon: Icons.schedule,
                                  title: 'Schedule',
                                  initiallyExpanded: _selectedIndex >= 6 && _selectedIndex <= 10,
                                  children: [
                                    _buildSidebarItem(Icons.calendar_today, 'Schedule Allocate', 6, isSub: true),
                                    _buildSidebarItem(Icons.assignment_ind, 'Assign Device', 7, isSub: true),
                                    _buildSidebarItem(Icons.list, 'Schedule List', 8, isSub: true),
                                    _buildSidebarItem(Icons.date_range, 'Specific Ranges', 9, isSub: true),
                                    _buildSidebarItem(Icons.delete_sweep, 'Copy and Wipe Off', 10, isSub: true),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12), // Gap between sidebar and content
                // --- Animated View Panel ---
                
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12, right: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1), // Keep main panel mostly transparent
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: FadeTransition(
                      opacity: _viewFade,
                      child: SlideTransition(
                        position: _viewSlide,
                        child: _getSelectedView(),
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
  );
}

  // --- Dynamic Header Helper ---
  Widget _buildDynamicHeader() {
    bool isDashboard = _selectedIndex == 0;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: RichText(
        key: ValueKey(_selectedIndex),
        text: TextSpan(
          children: [
            TextSpan(
              text: "SRIHER ",
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(
              text: isDashboard ? "/ DISPLAY" : "/ SRIHER DISPLAY",
              style: const TextStyle(
                color: Colors.white, // White primary
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Sidebar UI Helpers ---
  Widget _buildSidebarItem(IconData icon, String title, int index, {bool isSub = false}) {
    final bool isSelected = _selectedIndex == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF64FFDA).withValues(alpha: 0.1) // Teal accent for dark theme
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: ListTile(
        dense: true,
        leading: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Icon(
            icon,
            key: ValueKey(isSelected ? '${index}_sel' : '${index}_unsel'),
            color: isSelected
                ? const Color(0xFF64FFDA) // Teal selected
                : (isSub ? Colors.white38 : Colors.grey.shade400),
            size: isSub ? 18 : 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: isSub ? 13 : 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
        contentPadding: isSub
            ? const EdgeInsets.only(left: 32, right: 8)
            : const EdgeInsets.symmetric(horizontal: 8),
        selected: isSelected,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: () => _selectIndex(index),
      ),
    );
  }

  Widget _buildExpansionTile({
    required IconData icon,
    required String title,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent, unselectedWidgetColor: Colors.white54),
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.blueAccent, size: 20), 
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white70)),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white54,
        initiallyExpanded: initiallyExpanded,
        childrenPadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _getSelectedView() {
    switch (_selectedIndex) {
      case 0: return const DashboardView();
      case 1: return const AddUserView();
      case 2: return const FileUploadView();
      case 3: return const CreateTemplateView();
      case 4: return const DefaultTemplateView();
      case 5: return const SelectTemplateView();
      case 6: return const ScheduleAllocateView();
      case 7: return const AssignDeviceView();
      case 8: return const ScheduleListView();
      case 9: return const SpecificRangesView();
      case 10: return const CopyWipeoffView();
      case 11: return const RoleView();
      case 12: return const DeviceMasterView();
      case 13: return const DepartmentView();
      case 14: return const LocationMasterView();
      case 15: return const MappingView();
      default: return const DashboardView();
    }
  }
}

/// Animated icon button with scale on press
class _AnimatedIconButton extends StatefulWidget {
  
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _AnimatedIconButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<_AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100), lowerBound: 0.85, upperBound: 1.0, value: 1.0);
    _scale = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: child,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          onPressed: () async {
            await _ctrl.reverse();
            await _ctrl.forward();
            widget.onPressed();
        
          },
          icon: Icon(widget.icon),
          color: widget.color,
          iconSize: 24, // Slightly smaller to fit in the circle
        ),
      ),
    );
  }
}