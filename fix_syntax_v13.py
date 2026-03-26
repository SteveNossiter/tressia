with open('lib/screens/dashboard_screen.dart', 'r') as f:
    text = f.read()

bad = """                    if (isPhase)
                      Container(
                        width: rowWidth,
                        height: 1,
                        decoration: BoxDecoration(
                          color: theme.dividerColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(1),
                      ),
                    ),
              ],
            ),"""

# Let's count the braces. 
# Container( width, height, decoration: BoxDecoration( color, borderRadius ) )
# should be 2 closing for Container.
# Then ], for children.
# Then ), for Stack.
# Then ), for SizedBox.
# Then ), for _buildGanttRow body.

good = """                    if (isPhase)
                      Container(
                        width: rowWidth,
                        height: 1,
                        decoration: BoxDecoration(
                          color: theme.dividerColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                  ],
                ),
              ),
            ),"""

text = text.replace(bad, good)
with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(text)
