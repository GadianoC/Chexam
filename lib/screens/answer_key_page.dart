import 'package:flutter/material.dart';

class AnswerKeyPage extends StatefulWidget {
  final int totalQuestions;

  const AnswerKeyPage({required this.totalQuestions});

  @override
  _AnswerKeyPageState createState() => _AnswerKeyPageState();
}

class _AnswerKeyPageState extends State<AnswerKeyPage> {
  late List<String> correctAnswers;

  @override
  void initState() {
    super.initState();
    correctAnswers = List.filled(widget.totalQuestions, 'A'); // Default to A
  }

  void saveAnswers() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Save'),
        content: Text('Are you sure you want to save this answer key?'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            child: Text('Confirm'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      Map<int, String> answerKey = {
        for (int i = 0; i < correctAnswers.length; i++) i + 1: correctAnswers[i]
      };

      Navigator.pop(context, answerKey); // Return to previous screen with key
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Set Answer Key')),
      body: ListView.builder(
        itemCount: widget.totalQuestions,
        itemBuilder: (context, index) {
          return ListTile(
            leading: Text('Q${index + 1}'),
            title: DropdownButton<String>(
              value: correctAnswers[index],
              items: ['A', 'B', 'C', 'D']
                  .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                  .toList(),
              onChanged: (val) {
                setState(() => correctAnswers[index] = val!);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: saveAnswers,
        label: Text('Save'),
        icon: Icon(Icons.check),
      ),
    );
  }
}
