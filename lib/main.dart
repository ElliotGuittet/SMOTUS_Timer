import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'historyPage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
            channelKey: 'basic_channel',
            channelName: 'Basic notifications',
            channelDescription: 'Notifications channel for basic test')
      ],
      debug: true);
  runApp(SmotusTimer());
}

class SmotusTimer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TimerPage(),
    );
  }
}

class TimerPage extends StatefulWidget {
  @override
  _TimerPageState createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  // Variables pour le Timer
  int shortWorkTime = 30; // 25 minutes de travail en secondes
  int shortBreakTime = 10; // 5 minutes de pause
  int longWorkTime = 45 * 60; // 45 minutes de travail
  int longBreakTime = 15 * 60; // 15 minutes de pause
  int timeRemaining = 25 * 60; // par défaut 25 minutes
  bool isWorkPeriod = true; // Période de travail ou de pause
  Timer? _timer;
  bool isRunning = false;
  bool isPaused = false;

  int completedSessions = 0;
  int totalWorkTime = 0; // Temps de travail total en secondes
  int currentWorkTime = 0; // Temps de travail de la session en cours

  // Mode selection (25/5 ou 45/15)
  bool isShortBreak = true;

  // Variables pour l'utilisateur connecté
  User? _currentUser;

  final player = AudioPlayer();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });

    // Vérifie si un utilisateur est déjà connecté au lancement de l'application
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      setState(() {
        _currentUser = user; // Met à jour la variable de l'utilisateur connecté
      });
    });

    super.initState();
  }

  // Méthode de connexion
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // L'utilisateur a annulé la connexion

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      setState(() {
        _currentUser = userCredential.user; // Met à jour l'utilisateur connecté
      });

      return _currentUser;
    } catch (e) {
      print("Erreur de connexion : $e");
      return null;
    }
  }

  // Méthode de déconnexion
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    setState(() {
      _currentUser = null; // Réinitialise l'utilisateur
    });
    print('Déconnexion réussie');
  }

  void _startStopTimer() {
    if (isRunning) {
      _timer?.cancel();
      setState(() {
        isRunning = false;
        isPaused = true;
      });
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (timeRemaining > 0) {
            timeRemaining--;
          } else {
            _switchPeriods(); // Basculer entre travail et pause
          }
        });
      });

      if (isWorkPeriod && isRunning) {
        currentWorkTime++;
      }

      setState(() {
        isRunning = true;
        isPaused = false;
      });
    }
  }

  void _resetTimer() {
    _timer?.cancel();

    // Enregistrer la session si du travail a été réalisé
    if (currentWorkTime > 0) {
      completedSessions++;
      totalWorkTime += currentWorkTime; // Ajoute le temps de travail actuel à la somme totale

      // Ajouter l'entrée à Firestore
      _saveHistoryToFirestore();
    }

    // Réinitialiser le Timer
    setState(() {
      timeRemaining = isShortBreak ? shortWorkTime : longWorkTime;
      isWorkPeriod = true;
      isRunning = false;
      isPaused = false;
      currentWorkTime = 0; // Réinitialiser le temps de travail actuel
    });
  }

  void triggerNotification(next) {
    if (next == "nextPause") {
      AwesomeNotifications().createNotification(
          content: NotificationContent(
              id: 10,
              channelKey: 'basic_channel',
              title: 'SMOTUS Timer',
              body: 'Félicitations ! Vous méritez cette pause'));
    } else if (next == "nextWork") {
      AwesomeNotifications().createNotification(
          content: NotificationContent(
              id: 10,
              channelKey: 'basic_channel',
              title: 'SMOTUS Timer',
              body: "C'est l'heure de vous mettre au travail."));
    }
  }

  // Méthode pour basculer entre travail et pause et envoyer une notification
  void _switchPeriods() {
    if (isWorkPeriod) {
      // Si on est en période de travail, passer à la pause
      triggerNotification("nextPause");
      player.play(AssetSource('sounds/start_break.mp3'));
      setState(() {
        isWorkPeriod = false;
        timeRemaining = isShortBreak ? shortBreakTime : longBreakTime;
      });
    } else {
      // Si on est en pause, revenir à la période de travail
      triggerNotification("nextWork");
      player.play(AssetSource('sounds/start_work.mp3'));
      setState(() {
        isWorkPeriod = true;
        timeRemaining = isShortBreak ? shortWorkTime : longWorkTime;
      });
    }
  }

  void _setMode(bool isShort) {
    setState(() {
      isShortBreak = isShort;
      timeRemaining = isShort ? shortWorkTime : longWorkTime;
      isWorkPeriod = true;
      isRunning = false; // Pause en attendant le nouveau départ
      _timer?.cancel();
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _saveHistoryToFirestore() async {
    if (_currentUser != null) {
      await _firestore.collection('user_sessions').add({
        'userId': _currentUser!.uid,
        'startTime': DateTime.now(),
        'sessions': completedSessions,
        'totalWorkTime': totalWorkTime,
      });
      print('Historique sauvegardé avec succès dans Firestore');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fond noir
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Affiche les informations de l'utilisateur connecté
            _currentUser == null
                ? ElevatedButton(
              onPressed: () async {
                User? user = await signInWithGoogle();
                if (user != null) {
                  print('Connexion réussie : ${user.displayName}');
                } else {
                  print("Échec de la connexion");
                }
              },
              child: const Text('Connexion avec Google'),
            )
                : Column(
              children: [
                Text(
                  "Bienvenue, ${_currentUser!.displayName}",
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
                ElevatedButton(
                  onPressed: signOut,
                  style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text("Déconnexion"),
                ),
              ],
            ),
            // Titre et Timer
            const Text(
              "SMOTUS Timer",
              style: TextStyle(fontSize: 40.0, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              isPaused
                  ? "En pause"
                  : isWorkPeriod
                  ? "Phase de travail"
                  : "Repos ! Prends une pause",
              style: TextStyle(
                fontSize: 24.0,
                color: isPaused
                    ? Colors.yellow
                    : (isWorkPeriod ? Colors.green : Colors.blue),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _formatTime(timeRemaining),
              style: const TextStyle(
                  fontSize: 64.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  onPressed: _startStopTimer,
                  style: ElevatedButton.styleFrom(foregroundColor: Colors.blue),
                  child: Text(isRunning ? 'PAUSE' : 'START'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _resetTimer,
                  style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('STOP'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Radio(
                  value: true,
                  groupValue: isShortBreak,
                  onChanged: (bool? value) {
                    if (value != null) {
                      _setMode(value);
                    }
                  },
                ),
                const Text('25/5', style: TextStyle(color: Colors.white)),
                Radio(
                  value: false,
                  groupValue: isShortBreak,
                  onChanged: (bool? value) {
                    if (value != null) {
                      _setMode(value);
                    }
                  },
                ),
                const Text('45/15', style: TextStyle(color: Colors.white)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => HistoryPage(history: [],)),
                    );
                  },
                  child: const Text("Voir l'historique"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
