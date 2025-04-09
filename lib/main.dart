import 'package:flutter/material.dart';
import 'screens/home_page.dart';
import 'screens/scanner_page.dart';
import 'screens/answer_key_page.dart'; // Make sure this import exists

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bubble Scanner',
      initialRoute: '/',
      routes: {
        '/': (context) => HomePage(),
        '/scanner': (context) => ScannerPage(),
        // You can REMOVE '/answerKey' from here if you're using onGenerateRoute
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/answerKey') {
          final args = settings.arguments as int?;
          return MaterialPageRoute(
            builder: (context) =>
                AnswerKeyPage(totalQuestions: args ?? 60),
          );
        }
        return null;
      },
    );
  }
}
