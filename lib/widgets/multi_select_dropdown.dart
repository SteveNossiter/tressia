import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/clinic_settings.dart' show AppUser;

class MultiSelectDropdown extends StatefulWidget {
  final String title;
  final List<AppUser> users;
  final List<String> selectedIds;
  final Function(List<String>) onChanged;

  const MultiSelectDropdown({
    Key? key,
    required this.title,
    required this.users,
    required this.selectedIds,
    required this.onChanged,
  }) : super(key: key);

  @override
  _MultiSelectDropdownState createState() => _MultiSelectDropdownState();
}

class _MultiSelectDropdownState extends State<MultiSelectDropdown> {
  void _showDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              title: Text(widget.title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: ListBody(
                  children: widget.users.map((user) {
                    final isSelected = widget.selectedIds.contains(user.id);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(user.name, style: GoogleFonts.outfit()),
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            widget.selectedIds.add(user.id);
                          } else {
                            widget.selectedIds.remove(user.id);
                          }
                        });
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onChanged(widget.selectedIds.toList());
                  },
                  child: Text('Done', style: GoogleFonts.outfit()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> selectedNames = widget.users
        .where((u) => widget.selectedIds.contains(u.id))
        .map((u) => u.name)
        .toList();

    return InkWell(
      onTap: _showDialog,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                selectedNames.isEmpty
                    ? 'Select ${widget.title}'
                    : selectedNames.join(', '),
                style: GoogleFonts.outfit(
                  color: selectedNames.isEmpty
                      ? Theme.of(context).hintColor
                      : Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Theme.of(context).hintColor),
          ],
        ),
      ),
    );
  }
}
