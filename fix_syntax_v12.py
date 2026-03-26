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
            ),
const SizedBox(height: 12),"""

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
            ),
            const SizedBox(height: 12),"""

text = text.replace(bad, good)
with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(text)
