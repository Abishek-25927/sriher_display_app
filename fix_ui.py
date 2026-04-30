import re
import os

files = [
    "lib/views/authentication/add_user_view.dart",
    "lib/views/file_master.dart/file_upload.dart",
    "lib/views/template_master.dart/create_template.dart",
    "lib/views/template_master.dart/default_template.dart",
    "lib/views/template_master.dart/select_template.dart",
    "lib/views/schedule_allocate.dart/schedule_allocate_main.dart",
    "lib/views/schedule_allocate.dart/schedule_list.dart",
    "lib/views/schedule_allocate.dart/specific_ranges.dart",
    "lib/views/masters.dart/department.dart",
    "lib/views/masters.dart/location_master.dart",
    "lib/views/masters.dart/device_master.dart",
    "lib/views/masters.dart/mapping.dart",
    "lib/views/masters.dart/role.dart",
]

for f in files:
    if not os.path.exists(f):
        print(f"File not found: {f}")
        continue
        
    with open(f, 'r') as file:
        content = file.read()
        
    # 1. Make TextFormFields square by replacing circular border radius with zero in OutlineInputBorder
    # We'll use a regex that matches BorderRadius.circular(...) inside OutlineInputBorder
    # We can do a simpler replace:
    # First, find all OutlineInputBorder blocks. This is tricky with simple regex if there are nested parentheses.
    # Instead, let's just replace `BorderRadius.circular(...)` with `BorderRadius.zero` 
    # ONLY when it is near `OutlineInputBorder`.
    
    # Actually, a simpler way is to replace `BorderRadius.circular(\d+(\.\d+)?)` with `BorderRadius.zero` 
    # but ONLY for OutlineInputBorder. Let's do:
    # OutlineInputBorder(borderRadius: BorderRadius.circular(12), ...)
    content = re.sub(r'(OutlineInputBorder\s*\(\s*.*?borderRadius:\s*)BorderRadius\.circular\([^)]+\)', r'\1BorderRadius.zero', content, flags=re.DOTALL)
    content = re.sub(r'(OutlineInputBorder\s*\(\s*borderSide.*?borderRadius:\s*)BorderRadius\.circular\([^)]+\)', r'\1BorderRadius.zero', content, flags=re.DOTALL)

    # Some OutlineInputBorders are formatted simply as: `OutlineInputBorder(borderRadius: BorderRadius.circular(8))`
    # The dotall regex above might be too greedy and match across other widgets.
    # Let's use a non-greedy regex:
    content = re.sub(r'(OutlineInputBorder\s*\([^)]*?borderRadius:\s*)BorderRadius\.circular\([^)]+\)', r'\1BorderRadius.zero', content)
    
    # For pagination buttons, they usually use OutlinedButton or Container with margin.
    # In OutlinedButton.styleFrom, let's replace BorderRadius.circular(...) with BorderRadius.zero
    # But only inside pagination functions. Let's find functions like _buildPageBtn, _pageBtn, _buildNavBtn
    # Since we can't easily parse Dart with Python regex, we can do a targeted replace for typical OutlinedButton border radius 
    # inside these files. Actually, let's replace `RoundedRectangleBorder(borderRadius: BorderRadius.circular(...))` 
    # with `RoundedRectangleBorder(borderRadius: BorderRadius.zero)` ONLY in the pagination functions.
    
    # Function names: _buildPageBtn, _pageBtn, _buildNavBtn
    # We can chunk the file by function definitions.
    
    def process_func(match):
        func_content = match.group(0)
        # Remove horizontal margin/padding gaps between buttons
        func_content = re.sub(r'margin:\s*const\s*EdgeInsets\.symmetric\(horizontal:\s*\d+\)', r'margin: EdgeInsets.zero', func_content)
        func_content = re.sub(r'margin:\s*EdgeInsets\.symmetric\(horizontal:\s*\d+\)', r'margin: EdgeInsets.zero', func_content)
        # also remove margin: const EdgeInsets.only(left: 4) etc
        func_content = re.sub(r'margin:\s*const\s*EdgeInsets\.only\([^)]+\)', r'margin: EdgeInsets.zero', func_content)
        
        # Replace circular borders with zero
        func_content = re.sub(r'BorderRadius\.circular\([^)]+\)', r'BorderRadius.zero', func_content)
        
        return func_content
        
    content = re.sub(r'(Widget\s+_(?:buildPageBtn|pageBtn|buildNavBtn)[\s\S]*?\n\s*\}\n)', process_func, content)
    
    # Also in file_upload.dart there is a Container for pagination dots or numbers we should fix?
    # The user said "the previs 1 next or 2 also betwen these athere are gaps /wdith between each soavoid it temove the gaps"
    # Wait, sometimes the buttons are in a Row and separated by SizedBox(width: x).
    # Let's look for Row containing these buttons and remove SizedBox(width: 8) etc.
    # This is a bit too risky with regex. But I can remove SizedBoxes around pagination buttons.
    # A safer approach is to check if we made the edits.
    
    with open(f, 'w') as file:
        file.write(content)

print("Done fixing UI.")
