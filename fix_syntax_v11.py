with open('lib/screens/dashboard_screen.dart', 'r') as f:
    text = f.read()

bad1 = "                          borderRadius: BorderRadius.circular(1),\n                          ),\n                        ],\n                      ),\n                    ),\n                  );\n                }),"
good1 = "                          borderRadius: BorderRadius.circular(1),\n                        ),\n                      ),"

text = text.replace(bad1, good1)

bad2 = "                          borderRadius: BorderRadius.circular(1),\n                          ),\n                        ],\n                      ),\n                    );\n                  }),"
good2 = "                          borderRadius: BorderRadius.circular(1),\n                        ),\n                      ),"

text = text.replace(bad2, good2)

with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(text)
