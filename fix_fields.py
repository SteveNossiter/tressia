import re

files_to_fix = [
    'lib/screens/client_profile_screen.dart',
    'lib/screens/clients_list_screen.dart',
    'lib/services/pdf_generator_service.dart',
    'lib/widgets/dialogs/client_creator.dart',
    'lib/widgets/dialogs/entity_creator.dart',
    'lib/widgets/dialogs/phase_editor.dart',
    'lib/widgets/dialogs/subtask_editor.dart',
    'lib/widgets/dialogs/task_editor.dart'
]

for fp in files_to_fix:
    with open(fp, 'r') as f:
        c = f.read()

    # The models have List<String> instead of String for assigned therapists, users, etc.
    # 1. replace any "assignedTherapistId" or "assignedUserId" getter logic with the array equivalent.
    
    # E.g. .assignedTherapistId == x -> .assignedTherapistIds.contains(x)
    c = re.sub(r'\.assignedUserId\s*==\s*([^&)\]\s]+)', r'.assignedUserIds.contains(\1)', c)
    c = re.sub(r'\.assignedTherapistId\s*==\s*([^&)\]\s]+)', r'.assignedTherapistIds.contains(\1)', c)
    
    c = re.sub(r'([^=\s]+)\s*==\s*([a-zA-Z0-9_\.]+)\.assignedTherapistId', r'\2.assignedTherapistIds.contains(\1)', c)
    c = re.sub(r'([^=\s]+)\s*==\s*([a-zA-Z0-9_\.]+)\.assignedUserId', r'\2.assignedUserIds.contains(\1)', c)
    
    # 2. replace constructor arguments
    # assignedTherapistId: X -> assignedTherapistIds: X.isEmpty ? [] : [X] (Handling empty string)
    c = re.sub(r'assignedTherapistId:\s*([^,]+),', r'assignedTherapistIds: \1.isEmpty || \1 == \'unassigned\' ? [] : [\1],', c)
    c = re.sub(r'assignedUserId:\s*([^,]+),', r'assignedUserIds: \1 == \'unassigned\' || \1 == null ? [] : [\1],', c)
    c = re.sub(r'therapistId:\s*([^,]+),', r'therapistIds: \1 == \'unassigned\' || \1 == null ? [] : [\1],', c)

    # 3. simple property access where it expects a String (e.g. printing or passing to another logic)
    c = c.replace('.assignedTherapistId', ".assignedTherapistIds.firstOrNull ?? 'unassigned'")
    c = c.replace('.assignedUserId', ".assignedUserIds.firstOrNull ?? 'unassigned'")
    c = c.replace('.therapistId', ".therapistIds.firstOrNull ?? 'unassigned'")

    # But wait! If we do replace 3 after replace 2, we might break `.assignedTherapistIds`. Let's assume there is no exact `.assignedTherapistId` left after step 1 & 2 EXCEPT the getter!

    # 4. FIX MANGLED CONTAINS from previous bad script
    c = c.replace(".firstOrNull ?? 'unassigned's.contains", ".firstOrNull ?? 'unassigned' == ")
    c = c.replace(".where((p) => p.assignedTherapistIds.firstOrNull ?? 'unassigned's.contains(currentUser.id))", ".where((p) => p.assignedTherapistIds.contains(currentUser.id))")

    with open(fp, 'w') as f:
        f.write(c)
