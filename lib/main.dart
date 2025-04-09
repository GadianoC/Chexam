import 'package:flutter/material.dart';
import 'screens/home_page.dart'; 
import 'screens/scanner_page.dart';  

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
      },
    );
  }
}
