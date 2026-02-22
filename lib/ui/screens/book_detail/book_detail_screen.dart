import 'package:flutter/material.dart';

class BookDetailScreen extends StatelessWidget {
  const BookDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Entries'),
      ),
      body: const Center(
        child: Text('Detailed view of all entries will appear here.'),
      ),
    );
  }
}
