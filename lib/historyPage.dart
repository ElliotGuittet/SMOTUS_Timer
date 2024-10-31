import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
        child: Text(
          "Aucune session enregistrée pour le moment.",
          style: TextStyle(color: Colors.white),
        ),
      )
          : ListView.builder(
        itemCount: history.length,
        itemBuilder: (context, index) {
          final entry = history[index];
          final date = entry['date'].toDate(); // Conversion de Timestamp en DateTime

          // Calcul des minutes et secondes
          final int workTime = entry['workTime'];
          final int minutes = workTime ~/ 60; // Minutes
          final int seconds = workTime % 60;  // Secondes

          return ListTile(
            title: Text(
              "Date : ${DateFormat('dd/MM/yyyy – HH:mm').format(date)}", // Format de la date
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              "Sessions : ${entry['sessions']} - Temps de travail total : $minutes' $seconds''", // Format des minutes et secondes
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      ),
    );
  }
}
