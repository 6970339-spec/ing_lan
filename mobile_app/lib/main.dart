import 'package:flutter/material.dart';

void main() {
  runApp(const IngTrainerApp());
}

class IngTrainerApp extends StatelessWidget {
  const IngTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IngTrainer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('IngTrainer'),
        ),
      ),
    );
  }
}
