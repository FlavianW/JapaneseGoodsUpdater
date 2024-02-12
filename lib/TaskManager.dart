import 'dart:async';
import 'dart:convert';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:japanesegoodstool/SiteChecker.dart';
import 'package:firebase_core/firebase_core.dart';

Set<String> _cancelledTasks = {};

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      initialNotificationTitle: 'JGT running in the background',
      initialNotificationContent: '',

    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
    ),
  );
  service.startService();
}

Future<void> setTaskEnabled(String taskName, bool isEnabled,
    {required int days,
    required int hours,
    required int minutes,
    required String userId,
    required String artistName,
    required bool notifzero,
    required bool FirstCheck}) async {
  if (isEnabled) {
    String taskJson = json.encode({
      'taskName': taskName,
      'nextRun': DateTime.now()
          .add(Duration(days: days, hours: hours, minutes: minutes))
          .toIso8601String(),
      'userId': userId,
      'artistName': artistName,
      'days': days,
      'hours': hours,
      'minutes': minutes,
      'notifzero': notifzero,
    });

    final prefs = await SharedPreferences.getInstance();
    final tasks = prefs.getStringList('tasks') ?? [];
    tasks.add(taskJson);
    _cancelledTasks.remove(taskName);
    await prefs.setStringList('tasks', tasks);

    if (FirstCheck) {
      await addOrUpdateAlertList(userId, artistName);
    }
  }
}

Future<void> addOrUpdateAlertList(String userId, String artistName) async {
  final firestoreInstance = FirebaseFirestore.instance;

  var querySnapshot = await firestoreInstance
      .collection('users')
      .doc(userId)
      .collection('alerts')
      .where('artist', isEqualTo: artistName)
      .limit(1)
      .get();

  // Check if doc exists
  if (querySnapshot.docs.isNotEmpty) {
    var documentSnapshot = querySnapshot.docs.first;
    var documentId = documentSnapshot.id; // get doc ID

    Map<String, dynamic>? sites =
        documentSnapshot.data()['sites'] as Map<String, dynamic>?;

    Map<String, bool> booleanSites = {};
    sites?.forEach((key, value) {
      booleanSites[key] = value as bool;
    });

    checkAndExecuteSiteFunctions(booleanSites, artistName).then((siteResults) {
      firestoreInstance
          .collection('users')
          .doc(userId)
          .collection('alerts')
          .doc(documentId)
          .update({
            'SiteFirstCheck': siteResults,
          })
          .then((_) => print("Nouvel élément ajouté à la liste avec succès"))
          .catchError(
              (error) => print("Erreur lors de l'ajout à la liste : $error"));
    });
  }
}

Future<Map<String, int>> checkAndExecuteSiteFunctions(
    Map<String, bool> sites, String artistName) async {
  Map<String, int> siteResults = {};

  // For every site we check if the user enabled it while creating the alert
  for (var site in sites.entries) {
    if (site.value) {
      int results = 0;
      switch (site.key) {
        case 'Booth':
          results = await extractResultsBooth(artistName);
          break;
        case 'Mandarake':
          results = await extractResultsMandarake(artistName);
          break;
        case 'Melonbooks':
          results = await extractResultsMelonbooks(artistName);
          break;
        case 'Rakuten':
          results = await extractResultsRakuten(artistName);
          break;
        case 'Surugaya':
          results = await extractResultsSurugaya(artistName);
          break;
        case 'Toranoana':
          results = await extractResultsToranoana(artistName);
          break;
        default:
      }
      siteResults[site.key] = results;
    }
  }

  return siteResults; // return the map with the results
}

Future<void> cancelTask(String taskName) async {
  final prefs = await SharedPreferences.getInstance();
  final tasks = prefs.getStringList('tasks') ?? [];
  final updatedTasks = tasks.where((taskJson) {
    final task = json.decode(taskJson);
    bool isTaskNameDifferent = task['taskName'] != taskName;
    if (!isTaskNameDifferent) {
      _cancelledTasks.add(taskName);
    }
    return isTaskNameDifferent;
  }).toList();

  await prefs.setStringList('tasks', updatedTasks);
}

bool _timerInitialized = false;

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if (_timerInitialized) {
    return;
  }
  _timerInitialized = true;
  await Firebase.initializeApp();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('ic_notification');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // By far the hardest method in the whole app, the problem is with flutter background fetch
  // When the background task is finished I delete it and create the same one but with
  // nextRun updated, I couldn't change only nextRun on the fly, this might lead to some
  // "unfixable bug??"
  Timer.periodic(Duration(minutes: 1), (timer) async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    List<String>? tasks = prefs.getStringList('tasks');
    if (tasks == null) return;

    List<String> newTasks = [];

    for (String taskJson in tasks) {
      final Map<String, dynamic> task = json.decode(taskJson);
      final DateTime nextRun = DateTime.parse(task['nextRun']);

      if (now.isAfter(nextRun) && !_cancelledTasks.contains(task['taskName'])) {
        final firestoreInstance = FirebaseFirestore.instance;
        int notificationId =
            DateTime.now().millisecondsSinceEpoch.remainder(100000);

        var querySnapshot = await firestoreInstance
            .collection('users')
            .doc(task['userId'].toString())
            .collection('alerts')
            .where('artist', isEqualTo: task['artistName'].toString())
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          var documentSnapshot = querySnapshot.docs.first;
          var documentId = documentSnapshot.id;

          Map<String, dynamic>? sites =
              documentSnapshot.data()['sites'] as Map<String, dynamic>?;

          Map<String, bool> booleanSites = {};
          sites?.forEach((key, value) {
            booleanSites[key] = value as bool;
          });

          var currentSiteResults = documentSnapshot.data()?['SiteFirstCheck']
                  as Map<String, dynamic>? ??
              {};
          var newSiteResults = await checkAndExecuteSiteFunctions(
              booleanSites, task['artistName'].toString());
          int totalNewItems = 0;
          newSiteResults.forEach((site, newCount) {
            int currentCount = currentSiteResults[site] ?? 0;
            int newItems = newCount - currentCount;
            if (newItems > 0) {
              totalNewItems += newItems;
            }
          });

          if (totalNewItems == 0 && task['notifzero'] == true) {
            var androidDetails = AndroidNotificationDetails(
              'channelId',
              'channelName',
              channelDescription: 'channelDescription',
              importance: Importance.high,
              priority: Priority.high,
            );
            var platformDetails = NotificationDetails(android: androidDetails);
            await flutterLocalNotificationsPlugin.show(
              notificationId,
              'No new items - ${task['artistName']}',
              'There are no new items for ${task['artistName']}.',
              platformDetails,
            );
          }
          if (totalNewItems > 0) {
            var androidDetails = AndroidNotificationDetails(
              'channelId',
              'channelName',
              channelDescription: 'channelDescription',
              importance: Importance.high,
              priority: Priority.high,
            );
            var platformDetails = NotificationDetails(android: androidDetails);
            await flutterLocalNotificationsPlugin.show(
              notificationId,
              'New items - ${task['artistName']}',
              'There are $totalNewItems new items for ${task['artistName']}.',
              platformDetails,
            );
          }
          await firestoreInstance
              .collection('users')
              .doc(task['userId'].toString())
              .collection('alerts')
              .doc(documentId)
              .update({'LastCheck': newSiteResults});
        }

        await cancelTask(task['taskName']);

        // Recreate the task with the new nextRun using setTaskEnabled
        await setTaskEnabled(
          task['taskName'],
          true,
          days: int.tryParse(task['days'].toString()) ?? 0,
          hours: int.tryParse(task['hours'].toString()) ?? 0,
          minutes: int.tryParse(task['minutes'].toString()) ?? 15,
          userId: task['userId'],
          artistName: task['artistName'],
          notifzero: task['notifzero'],
          FirstCheck: false,
        );
      } else {
        // If the task does not need to be executed yet, keep it as is
        if (!_cancelledTasks.contains(task['taskName'])) {
          newTasks.add(taskJson);
        }
      }
    }
  });
}

DateTime calculateNextRun(int days, int hours, int minutes) {
  return DateTime.now()
      .add(Duration(days: days, hours: hours, minutes: minutes));
}
