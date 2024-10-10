import 'package:flutter/material.dart';

class HistoryPage extends StatelessWidget {
  final List<Map<String, dynamic>> history;

  HistoryPage({required this.history});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Historique"),
      ),
      body: history.isEmpty
          ? const Center(
              child: Text("Aucune session enregistrée pour le moment."))
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final entry = history[index];
                return ListTile(
                  title: Text(
                    "Date : ${entry['date']}",
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    "Sessions : ${entry['sessions']} - Temps de travail total : ${entry['workTime'] ~/ 60 + 1} minutes",
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
