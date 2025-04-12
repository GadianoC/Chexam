import 'package:flutter/material.dart';

class StudentAnswerPage extends StatelessWidget {
  final Map<int, String> answers;

  StudentAnswerPage({required this.answers});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Student Answers')),
      body: ListView(
        children: answers.entries
            .map((e) => ListTile(
                  title: Text("Q${e.key}: ${e.value}"),
                ))
            .toList(),
      ),
    );
  }
}
