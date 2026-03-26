with open('lib/screens/dashboard_screen.dart', 'r') as f:
    text = f.read()

marker = "borderRadius: BorderRadius.circular(1),"
pos1 = text.find(marker)
pos2 = text.find("const SizedBox(height: 12),", pos1)
if pos1 != -1 and pos2 != -1:
    new_text = text[:pos1 + len(marker)] + """
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
""" + text[pos2:]
    with open('lib/screens/dashboard_screen.dart', 'w') as f:
        f.write(new_text)
