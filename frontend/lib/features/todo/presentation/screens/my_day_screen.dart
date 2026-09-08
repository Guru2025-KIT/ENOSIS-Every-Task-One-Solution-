import 'package:flutter/material.dart';

class MyDayScreen extends StatelessWidget {
  const MyDayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('To-Do List')),
      body: const Center(child: Text('To-Do feature is under maintenance.')),
    );
  }
}