import os
import re

def process_file(filepath):
    if not os.path.exists(filepath): return
    with open(filepath, 'r') as f:
        c = f.read()

    # 1. replace `.assignedTherapistId` getter with `.assignedTherapistIds.firstOrNull ?? 'unassigned'`
    # but only in expressions evaluating it as a string
    c = re.sub(r'\.assignedTherapistId(?!\s*:)', ".assignedTherapistIds.firstOrNull ?? 'unassigned'", c)
    c = re.sub(r'\.assignedUserId(?!\s*:)', ".assignedUserIds.firstOrNull ?? 'unassigned'", c)
    c = re.sub(r'\.therapistId(?!\s*:)', ".therapistIds.firstOrNull ?? 'unassigned'", c)

    # 2. replace constructor arguments `assignedTherapistId: X` with `assignedTherapistIds: [X]`
    # wait, if X is 'unassigned', we could map it to empty list, or just leave it.
    c = re.sub(r'assignedTherapistId:\s*([^,]+),', r'assignedTherapistIds: [\1],', c)
    c = re.sub(r'assignedUserId:\s*([^,]+),', r'assignedUserIds: [\1],', c)
    c = re.sub(r'therapistId:\s*([^,]+),', r'therapistIds: [\1],', c)

    with open(filepath, 'w') as f:
        f.write(c)

files = [
  'lib/providers/app_state.dart',
  'lib/screens/client_creation_screen.dart',
  'lib/screens/client_profile_screen.dart',
  'lib/screens/clients_list_screen.dart',
  'lib/services/pdf_generator_service.dart',
  'lib/widgets/dialogs/client_creator.dart',
  'lib/widgets/dialogs/entity_creator.dart',
  'lib/widgets/dialogs/phase_editor.dart',
  'lib/widgets/dialogs/subtask_editor.dart',
  'lib/widgets/dialogs/task_editor.dart'
]

for file in files: process_file(file)

with open('lib/providers/app_state.dart', 'r') as f:
    app_state = f.read()
    app_state = app_state.replace('role: role,', 'role: role, userColor: Colors.purple, // hardcoded for MVP defaults\n')
with open('lib/providers/app_state.dart', 'w') as f:
    f.write(app_state)

