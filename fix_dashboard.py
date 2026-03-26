with open('lib/screens/dashboard_screen.dart', 'r') as f:
    lines = f.readlines()

# find exact start and end to replace
start_idx = 1147 - 1  # 0-indexed for 1147
end_idx = 1656  # slice 1656 lines out

new_lines = lines[:start_idx] + [
"""          ],
        ),
      ),
    );
  }

  Widget _buildWeekGantt(BuildContext context, List<Project> projects, List<ProjectTask> tasks, List<Subtask> subtasks, BoxConstraints constraints) {
    return _buildDayGantt(context, projects, tasks, subtasks, constraints);
  }

  Widget _buildMonthGantt(BuildContext context, List<Project> projects, List<ProjectTask> tasks, List<Subtask> subtasks, BoxConstraints constraints) {
    return _buildDayGantt(context, projects, tasks, subtasks, constraints);
  }

  Widget _buildYearGantt(BuildContext context, List<Project> projects, List<ProjectTask> tasks, List<Subtask> subtasks, BoxConstraints constraints) {
    return _buildDayGantt(context, projects, tasks, subtasks, constraints);
  }

"""
] + lines[end_idx:]

with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.writelines(new_lines)
