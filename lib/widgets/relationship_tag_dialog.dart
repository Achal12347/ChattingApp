import 'package:flutter/material.dart';

class RelationshipTagDialog extends StatefulWidget {
  final String? initialTag;
  final Function(String) onTagSelected;

  const RelationshipTagDialog({
    Key? key,
    this.initialTag,
    required this.onTagSelected,
  }) : super(key: key);

  @override
  _RelationshipTagDialogState createState() => _RelationshipTagDialogState();
}

class _RelationshipTagDialogState extends State<RelationshipTagDialog> {
  final List<String> predefinedTags = [
    'Friend',
    'Family',
    'Work',
    'Acquaintance',
    'Other'
  ];
  String? selectedTag;
  TextEditingController customTagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedTag = widget.initialTag;
    if (selectedTag != null && !predefinedTags.contains(selectedTag)) {
      customTagController.text = selectedTag!;
      selectedTag = 'Other';
    }
  }

  @override
  void dispose() {
    customTagController.dispose();
    super.dispose();
  }

  void _submit() {
    String tagToSave;
    if (selectedTag == 'Other') {
      tagToSave = customTagController.text.trim();
      if (tagToSave.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a custom tag')),
        );
        return;
      }
    } else if (selectedTag != null) {
      tagToSave = selectedTag!;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a tag')),
      );
      return;
    }
    widget.onTagSelected(tagToSave);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tag Relationship'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...predefinedTags.map((tag) {
              return RadioListTile<String>(
                title: Text(tag),
                value: tag,
                groupValue: selectedTag,
                onChanged: (value) {
                  setState(() {
                    selectedTag = value;
                  });
                },
              );
            }).toList(),
            if (selectedTag == 'Other')
              TextField(
                controller: customTagController,
                decoration: const InputDecoration(
                  labelText: 'Custom Tag',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
