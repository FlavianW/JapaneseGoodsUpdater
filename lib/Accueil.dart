import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:japanesegoodstool/EditAlerte.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'TaskManager.dart';
import 'package:workmanager/workmanager.dart';
import 'login.dart';
import 'CreerAlerte.dart';
import 'dart:convert';



Future<Map<String, dynamic>?> fetchUserData(String uid) async {
  try {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return userDoc.data() as Map<String, dynamic>?;
  } catch (e) {
    return null;
  }
}


class Artiste {
  String nom;
  bool alertesActivees;
  String? imageUrl;
  bool isTaskActive;
  bool notifzero;
  int days;
  int hours;
  int minutes;

  Artiste({required this.nom, this.alertesActivees = false, this.imageUrl, this.isTaskActive = false, this.notifzero = false, this.days = 0, this.hours = 0, this.minutes = 0});

  Map<String, dynamic> toJson() {
    return {
      'nom': nom,
      'notifzero': alertesActivees,
      'imageUrl': imageUrl,
      'isTaskActive': isTaskActive,
      'days': days,
      'hours': hours,
      'minutes': minutes,
    };
  }


  factory Artiste.fromJson(Map<String, dynamic> json) {
    return Artiste(
      nom: json['nom'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      isTaskActive: json['isTaskActive'] as bool? ?? false,
      days: json['days'] as int? ?? 0,
      hours: json['hours'] as int? ?? 0,
      minutes: json['minutes'] as int? ?? 0,
    );
  }
}



class Accueil extends StatefulWidget {
  final String uid;

  const Accueil({Key? key, required this.uid}) : super(key: key);

  @override
  _AccueilState createState() => _AccueilState();

}

class _AccueilState extends State<Accueil> {
  List<Artiste> listeArtistes = [];

  void reloadAlerts() async {
    await loadAlerts();
  }

  void navigateToCreerAlerte() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) =>
          CreerAlerte(uid: widget.uid, onAlertAdded: reloadAlerts),
    ));
  }

  @override
  void initState() {
    super.initState();
    print("InitState dans _AccueilState");
    loadAlerts();

  }

  Future<void> loadAlerts() async {
    var userAlerts = await FirebaseFirestore.instance.collection('users')
        .doc(widget.uid)
        .collection('alerts')
        .get();

    print("Alertes récupérées depuis Firestore: ${userAlerts.docs.length}");

    var loadedArtistes = userAlerts.docs.map((doc) {
      return Artiste(
        nom: doc.data()['artist'] as String,
        alertesActivees: doc.data()['sendNotifications'] as bool,
        imageUrl: doc.data()['imageUrl'] as String?,
        days: doc.data()['days'] as int,
        hours: doc.data()['hours'] as int,
        minutes: doc.data()['minutes'] as int,
      );
    }).toList();

    final prefs = await SharedPreferences.getInstance();
    List<String>? artistesString = prefs.getStringList('artistes');
    Map<String, bool> isTaskActiveMap = {};
    if (artistesString != null) {
      for (var str in artistesString) {
        var artiste = Artiste.fromJson(json.decode(str));
        isTaskActiveMap[artiste.nom] = artiste.isTaskActive;
      }
    }

    for (var artiste in loadedArtistes) {
      artiste.isTaskActive = isTaskActiveMap[artiste.nom] ?? false;
    }

    if (mounted) {
      setState(() {
        listeArtistes = loadedArtistes;
        print(loadedArtistes);

      });
    }
  }

  Future<void> signOut(BuildContext context) async {
    // Se déconnecter de FirebaseAuth
    await FirebaseAuth.instance.signOut();

    await TaskManager.cancelAllTasks();
    // Obtenir l'instance de SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Effacer toutes les données dans SharedPreferences
    await prefs.clear();

    // Naviguer vers la page de connexion
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HomePage"),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: fetchUserData(widget.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text("Erreur de chargement des données"));
          } else if (snapshot.hasData) {
            String nickname = snapshot.data?['nickname'] ?? 'Utilisateur';
            return Column(
              children: [
                const SizedBox(height: 60),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Hello $nickname',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: listeArtistes.isEmpty
                      ? Center( // Centre si la liste est vide
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Create your first alert with the button',
                          style: TextStyle(
                            fontWeight: FontWeight.bold, // Ajoutez cette ligne pour le gras
                            fontSize: 16, // Ajustez la taille de la police si nécessaire
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            navigateToCreerAlerte();
                          },
                          child: const Text('Create an alert'),
                        ),
                      ],
                    ),
                  )
                      : ListeArtistesWidget(uid: widget.uid, listeArtistes: listeArtistes), // Affiche la liste des artistes
                ),
              ],
            );
          } else {
            return const Center(child: Text("Pas d'alertes"));
          }
        },
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero, // Important pour s'assurer que le DrawerHeader n'a pas de padding supplémentaire
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                  'Menu',
                  style: TextStyle(color: Colors.white, fontSize: 24)
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Accueil'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Paramètres'),
              onTap: () {
                // Naviguer vers la page des paramètres
              },
            ),
            // ... Autres éléments du menu, si nécessaire
            // Placez le ListTile de déconnexion en bas de la liste
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
              onTap: () => signOut(context),
            ),
          ],
        ),
      ),
    );
  }
}


class ListeArtistesWidget extends StatefulWidget {
  final String uid;
  final List<Artiste> listeArtistes; // Ajoutez ce paramètre
  const ListeArtistesWidget({Key? key, required this.uid, required this.listeArtistes}) : super(key: key);

  @override
  _ListeArtistesWidgetState createState() => _ListeArtistesWidgetState();
}

class _ListeArtistesWidgetState extends State<ListeArtistesWidget> {
  List<Artiste> listeArtistes = [];
  bool isLoading = true; // Ajout d'un indicateur de chargement

  Future<void> saveArtistsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> artistesString = listeArtistes.map((artiste) =>
        json.encode(artiste.toJson())).toList();
    await prefs.setStringList('artistes', artistesString);
    print("SharedPreferences après la mise à jour: $artistesString");
  }

  Future<void> loadArtistsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? artistesString = prefs.getStringList('artistes');
    if (artistesString != null) {
      var tempArtistes = artistesString.map((str) =>
          Artiste.fromJson(json.decode(str))).toList();
      setState(() {
        listeArtistes = tempArtistes;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }


  void navigateToCreerAlerte() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) =>
          CreerAlerte(uid: widget.uid, onAlertAdded: reloadAlerts),
    ));
  }

  Future<void> reloadAlerts() async {
    var userAlerts = await FirebaseFirestore.instance.collection('users')
        .doc(widget.uid)
        .collection('alerts')
        .get();

    List<Artiste> loadedArtistes = userAlerts.docs.map((doc) {
      return Artiste(
        nom: doc.data()['artist'] as String,
        alertesActivees: doc.data()['sendNotifications'] as bool,
        imageUrl: doc.data()['imageUrl'] as String?,
        days: doc.data()['days'] as int,
        hours: doc.data()['hours'] as int,
        minutes: doc.data()['minutes'] as int,
      );
    }).toList();

    // Chargement de l'état isTaskActive depuis SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    List<String>? artistesString = prefs.getStringList('artistes');
    Map<String, bool> isTaskActiveMap = {};
    if (artistesString != null) {
      for (var str in artistesString) {
        var artiste = Artiste.fromJson(json.decode(str));
        isTaskActiveMap[artiste.nom] = artiste.isTaskActive;
      }
    }

    // Appliquer l'état isTaskActive aux artistes chargés depuis Firestore
    for (var artiste in loadedArtistes) {
      var nomArtiste = artiste.nom;
      if (isTaskActiveMap.containsKey(nomArtiste)) {
        artiste.isTaskActive = isTaskActiveMap[nomArtiste]!;
      }
    }

    if (mounted) {
      setState(() {
        listeArtistes = loadedArtistes;
      });
    }
  }


  @override
  void initState() {
    super.initState();
    reloadAlerts(); // Chargez les artistes et mettez à jour leur état
    isLoading = false;
  }


  Future<void> loadAlerts() async {
    var userAlerts = await FirebaseFirestore.instance.collection('users')
        .doc(widget.uid)
        .collection('alerts')
        .get();

    var loadedArtistes = userAlerts.docs.map((doc) {
      return Artiste(
        nom: doc.data()['artist'] as String,
        alertesActivees: doc.data()['sendNotifications'] as bool,
        imageUrl: doc.data()['imageUrl'] as String?,
        days: doc.data()['days'] as int,
        hours: doc.data()['hours'] as int,
        minutes: doc.data()['minutes'] as int,
      );
    }).toList();

    // Chargement de l'état isTaskActive depuis SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    List<String>? artistesString = prefs.getStringList('artistes');
    Map<String, bool> isTaskActiveMap = {};
    if (artistesString != null) {
      for (var str in artistesString) {
        var artiste = Artiste.fromJson(json.decode(str));
        isTaskActiveMap[artiste.nom] = artiste.isTaskActive;
      }
    }

    // Appliquer l'état isTaskActive aux artistes chargés depuis Firestore
    for (var artiste in loadedArtistes) {
      var nomArtiste = artiste.nom;
      if (isTaskActiveMap.containsKey(nomArtiste)) {
        artiste.isTaskActive = isTaskActiveMap[nomArtiste]!;
      }
    }

    if (mounted) {
      setState(() {
        listeArtistes = loadedArtistes;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Text(
                  '${listeArtistes.length} ${listeArtistes.length == 1
                      ? "alert"
                      : "alerts"}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: listeArtistes.length,
                  itemBuilder: (context, index) {
                    Artiste artiste = listeArtistes[index];
                    bool hasImage = artiste.imageUrl != null &&
                        artiste.imageUrl!.isNotEmpty;

                    return GestureDetector(
                      onLongPress: () =>
                          showEditDeleteDialog(context, artiste, index),
                      child: Card(
                        elevation: 4.0,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        child: Stack(
                          children: [
                            const SizedBox(height: 160),
                            if (hasImage)
                              Positioned.fill(
                                child: ClipRect(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      image: DecorationImage(
                                        image: NetworkImage(artiste.imageUrl!),
                                        fit: BoxFit.cover,
                                        colorFilter: ColorFilter.mode(
                                            Colors.black.withOpacity(0.5),
                                            BlendMode.dstATop),
                                      ),
                                    ),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                          sigmaX: 2, sigmaY: 2),
                                      child: Container(
                                          color: Colors.black.withOpacity(0.0)),
                                    ),
                                  ),
                                ),
                              ),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 25, vertical: 10),
                              title: Text(artiste.nom, style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                              trailing: Switch(
                                value: artiste.isTaskActive,
                                onChanged: (bool value) async {
                                  setState(() {
                                    artiste.isTaskActive = value;
                                    listeArtistes[index] = artiste;
                                  });
                                  await saveArtistsToPrefs();
                                  String taskName = "task_${artiste.nom}";
                                  if (value) {
                                    TaskManager.setTaskScheduled(
                                        taskName, true, artiste.days,
                                        artiste.hours, artiste.minutes, widget.uid, artiste.nom);
                                  } else {
                                    TaskManager.cancelTask(taskName);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 20.0,
            left: 0.0,
            right: 0.0,
            child: Center(
              child: FloatingActionButton(
                onPressed: navigateToCreerAlerte,
                child: const Icon(Icons.add),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Future<void> onDeletePressed(Artiste artiste, int index) async {
    TaskManager.cancelTask("task_${artiste.nom}");
    try {
      // Requête pour trouver le document basé sur le nom de l'artiste
      var querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('alerts')
          .where('artist', isEqualTo: artiste.nom) // Utilisez le champ exact utilisé pour stocker le nom de l'artiste
          .limit(1) // S'il y a plusieurs documents avec le même nom, cela limitera à un seul résultat
          .get();

      // Si le document existe, supprimez-le
      if (querySnapshot.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .collection('alerts')
            .doc(querySnapshot.docs.first.id)
            .delete();
      }
    } catch (e) {
      print("Erreur lors de la suppression de l'artiste: $e");
    }

    // Supprimer l'image de Google Storage, si elle existe
    if (artiste.imageUrl != null && artiste.imageUrl!.isNotEmpty) {
      FirebaseStorage.instance.refFromURL(artiste.imageUrl!).delete();
    }
    setState(() {
      listeArtistes.removeAt(index);
    });
    await saveArtistsToPrefs(); // Votre méthode existante pour sauvegarder dans SharedPreferences
  }


  void showEditDeleteDialog(BuildContext context, Artiste artiste, int index) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Do you want to edit or delete the alert for ${artiste.nom}?"),
          actions: <Widget>[
            TextButton(
              child: Text("Edit"),
              onPressed: () {
                Navigator.of(context).pop(); // Fermez d'abord la boîte de dialogue
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EditAlerte(
                      uid: widget.uid,
                      alerteId: artiste.nom,
                      onAlertAdded: () {
                        // Vous pourriez vouloir recharger les alertes après avoir édité
                        reloadAlerts();
                      },
                    ),
                  ),
                );
              },
            ),
            TextButton(
              child: Text("Delete"),
              onPressed: () async {
                await onDeletePressed(artiste, index);
                Navigator.of(context).pop(); // Fermez la boîte de dialogue
              },
            ),
          ],
        );
      },
    );
  }
}