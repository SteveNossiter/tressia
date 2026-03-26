with open('lib/screens/dashboard_screen.dart', 'r') as f:
    text = f.read()

# Replace using string slices to avoid whitespace issues
marker = "borderRadius: BorderRadius.circular(1),"
start_pos = text.find(marker)
next_block = "const SizedBox(height: 16),"
end_pos = text.find(next_block, start_pos)

if start_pos != -1 and end_pos != -1:
    new_content = text[:start_pos + len(marker)] + """
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
            """ + text[end_pos:]
    with open('lib/screens/dashboard_screen.dart', 'w') as f:
        f.write(new_content)
