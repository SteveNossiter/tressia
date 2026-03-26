import re

with open('lib/screens/dashboard_screen.dart', 'r') as f:
    code = f.read()

# Fix Border.all that have width 0.0 or null
# and replace Border(top: ...) with Border.all when possible or fix them

# Specific fix for the 0.0 width in uniform borders
code = re.sub(r'width: 0\.0', r'width: 0.1', code) # Hairline but non-zero, though transparent 1.0 is safer

# Change the urgency based borders to use 1.0 width transparent if not urgent
code = re.sub(r'width: ([\w]+)Urgency > 0 \? 2\.0 : 0\.1', r'width: \1Urgency > 0 ? 2.0 : 1.0', code)
code = re.sub(r'color: ([\w]+)Urgency == 2 \? Colors\.red : \(([\w]+)Urgency == 1 \? Colors\.amber : Colors\.transparent\)', 
              r'color: \1Urgency == 2 ? Colors.red : (\2Urgency == 1 ? Colors.amber : Colors.transparent)', code)

# Ensure no Border(...) with BorderRadius exists in my new subtask card replacement
# The previous patch might have missed some old versions or matched incorrectly if I didn't verify the whole file.

with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(code)
