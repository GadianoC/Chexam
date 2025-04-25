import 'package:chexam_prototype/screens/scanner_page.dart';
import 'package:flutter/material.dart';
import 'options_page.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home Page'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            tooltip: 'Options',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => OptionsPage()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // Go to Scanner Button
            ElevatedButton(
              onPressed: () {
                // Reset scan flag before navigating to scanner
                ScannerPageState.hasScannedThisSession = false;
                Navigator.pushNamed(context, '/scanner');
              },
              child: Text('Go to Scanner'),
            ),

            SizedBox(height: 20),

            // 🔽 Add This: Set Answer Key Button with Item Count Dialog
            ElevatedButton(
              onPressed: () async {
                final totalItems = await showDialog<int>(
                  context: context,
                  builder: (context) {
                    int selectedNumber = 10;

                    return AlertDialog(
                      title: Text('How many items?'),
                      content: StatefulBuilder(
                        builder: (context, setState) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Select number of exam items:'),
                              Slider(
                                value: selectedNumber.toDouble(),
                                min: 10,
                                max: 60,
                                divisions: 50,
                                label: selectedNumber.toString(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedNumber = value.toInt();
                                  });
                                },
                              ),
                              Text('$selectedNumber items'),
                            ],
                          );
                        },
                      ),
                      actions: [
                        TextButton(
                          child: Text('Cancel'),
                          onPressed: () => Navigator.pop(context),
                        ),
                        ElevatedButton(
                          child: Text('Continue'),
                          onPressed: () =>
                              Navigator.pop(context, selectedNumber),
                        ),
                      ],
                    );
                  },
                );

                if (totalItems != null) {
                  final answerKey = await Navigator.pushNamed(
                    context,
                    '/answerKey',
                    arguments: totalItems,
                  );

                  if (answerKey is Map<int, String>) {
                    print('Received answer key: $answerKey');
                  }
                }
              },
              child: Text('Set Answer Key'),
            ),
          ],
        ),
      ),
    );
  }
}
