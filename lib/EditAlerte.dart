import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';

class EditAlerte extends StatefulWidget {
  final String uid;
  final String alerteId;

  final VoidCallback onAlertAdded;

  const EditAlerte(
      {Key? key,
      required this.uid,
      required this.alerteId,
      required this.onAlertAdded})
      : super(key: key);

  @override
  _EditAlerteState createState() => _EditAlerteState();
}

class _EditAlerteState extends State<EditAlerte> {
  final FirebaseFirestore firestoreInstance = FirebaseFirestore.instance;
  TextEditingController artistController = TextEditingController();
  int days = 1;
  int hours = 0;
  int minutes = 0;
  bool sendNotifications = false;
  bool YahooJapanAuction = false;
  bool YahooJapanShopping = false;
  bool Melonbooks = false;
  bool Rakuten = false;
  bool Booth = false;
  bool Surugaya = false;
  bool Toranoana = false;
  bool Mandarake = false;
  File? _image;
  String imageBase = '';
  Widget? imageUrlWidget; // Déclaration de imageUrlWidget

  @override
  void initState() {
    super.initState();
    loadAlertData();
  }

  void loadAlertData() async {
    print(widget.uid);
    print(widget.alerteId);
    try {
      var existingAlerts = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('alerts')
          .where('artist', isEqualTo: widget.alerteId)
          .limit(1)
          .get();

      if (existingAlerts.docs.isNotEmpty) {
        // Accédez aux données du premier document (car vous avez limité à 1)
        var alertData = existingAlerts.docs[0].data() as Map<String, dynamic>;
        print(alertData);
        setState(() {
          artistController.text = alertData['artist'] ?? '';
          days = alertData['days'] ?? 1;
          hours = alertData['hours'] ?? 0;
          minutes = alertData['minutes'] ?? 0;
          sendNotifications = alertData['sendNotifications'] ?? false;
          YahooJapanAuction = alertData['sites']['YahooJapanAuction'] ?? false;
          YahooJapanShopping =
              alertData['sites']['YahooJapanShopping'] ?? false;
          Melonbooks = alertData['sites']['Melonbooks'] ?? false;
          Rakuten = alertData['sites']['Rakuten'] ?? false;
          Booth = alertData['sites']['Booth'] ?? false;
          Surugaya = alertData['sites']['Surugaya'] ?? false;
          Toranoana = alertData['sites']['Toranoana'] ?? false;
          Mandarake = alertData['sites']['Mandarake'] ?? false;
          imageBase = alertData['imageUrl'] ?? '';

          // Vérifiez si vous avez une imageUrl dans les données de l'alerte
          if (alertData['imageUrl'] != null) {
            imageUrlWidget = Image.network(alertData['imageUrl']);
          }
        });
      }
    } catch (e) {
      print("Error loading alert data: $e");
    }
  }

  void updateAlert() async {
    try {
      Map<String, dynamic> updateData = {
        'artist': artistController.text,
        'days': days,
        'hours': hours,
        'minutes': minutes,
        'sendNotifications': sendNotifications,
        'sites': {
          'YahooJapanAuction': YahooJapanAuction,
          'YahooJapanShopping': YahooJapanShopping,
          'Melonbooks': Melonbooks,
          'Rakuten': Rakuten,
          'Booth': Booth,
          'Surugaya': Surugaya,
          'Toranoana': Toranoana,
          'Mandarake': Mandarake,
        },
      };

      Future<String> uploadImage(File image) async {
        String extension = path.extension(image.path);

        if (extension.toLowerCase() != '.png' &&
            extension.toLowerCase() != '.jpg') {
          throw Exception('Only PNG and JPG files are allowed');
        }

        String fileName = 'alerts/${widget.uid}/${DateTime.now().millisecondsSinceEpoch}$extension';
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
        UploadTask uploadTask = storageRef.putFile(image);
        await uploadTask;
        return await storageRef.getDownloadURL();
      }

      Future<void> deleteImage(String imageUrl) async {
        try {
          Reference storageRef = FirebaseStorage.instance.refFromURL(imageUrl);
          await storageRef.delete();
        } catch (e) {
          print("Error deleting image: $e");
        }
      }

      if (_image != null) {
        // Uploadez l'image et obtenez l'URL
        String imageUrl = await uploadImage(_image!);
        updateData['imageUrl'] = imageUrl;

        // Supprimez l'ancienne image de Firebase Storage si elle existe
        if (imageBase.isNotEmpty) {
          await deleteImage(imageBase);
        }
      } else {
        // Si aucune nouvelle image n'est sélectionnée, conservez l'URL de l'image existante
        updateData['imageUrl'] = imageBase;
      }

      var querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('alerts')
          .where('artist', isEqualTo: widget.alerteId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        var documentId =
            querySnapshot.docs.first.id; // Récupérez l'ID du document

        await firestoreInstance
            .collection('users')
            .doc(widget.uid)
            .collection('alerts')
            .doc(documentId)
            .update(updateData)
            .then((_) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Alert updated")));
          widget.onAlertAdded(); // Appeler le rappel après la mise à jour
          Navigator.pop(context); // Retour à l'écran précédent
        }).catchError((error) {
          print("Error updating alert: $error");
          // Gérer l'erreur ici, peut-être afficher un message à l'utilisateur
        });
      }
    } catch (e) {
      print("Error updating alert: $e");
    }
  }

  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();

    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 600,
      imageQuality: 100,
    );

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);

      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Cropper',
            toolbarColor: Colors.deepOrange,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: true,
          )
        ],
      );

      if (croppedFile != null) {
        print("Selected image path: ${croppedFile.path}");
        setState(() {
          _image = File(croppedFile.path);
          imageUrlWidget =
              null; // Réinitialisez imageUrlWidget pour supprimer l'image précédente
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Edit Alert"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: artistController,
                decoration: InputDecoration(
                  labelText: "Artist",
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TimeCard(
                      label: "Days",
                      minValue: 1,
                      maxValue: 7,
                      value: days,
                      onChanged: (val) => setState(() => days = val),
                    ),
                  ),
                  Expanded(
                    child: TimeCard(
                      label: "Hours",
                      minValue: 0,
                      maxValue: 23,
                      value: hours,
                      onChanged: (val) => setState(() => hours = val),
                    ),
                  ),
                  Expanded(
                    child: TimeCard(
                      label: "Minutes",
                      minValue: 0,
                      maxValue: 59,
                      value: minutes,
                      onChanged: (val) => setState(() => minutes = val),
                    ),
                  ),
                ],
              ),
              CheckboxListTile(
                title: const Text(
                    "Send notifications even if there are no new items"),
                value: sendNotifications,
                onChanged: (bool? newValue) {
                  setState(() {
                    sendNotifications = newValue ?? false;
                  });
                },
              ),
              _buildSiteCheckbox("Yahoo! Japan Auction", YahooJapanAuction,
                  (value) => setState(() => YahooJapanAuction = value!)),
              _buildSiteCheckbox("Yahoo! Japan Shopping", YahooJapanShopping,
                  (value) => setState(() => YahooJapanShopping = value!)),
              _buildSiteCheckbox("Melonbooks", Melonbooks,
                  (value) => setState(() => Melonbooks = value!)),
              _buildSiteCheckbox("Rakuten", Rakuten,
                  (value) => setState(() => Rakuten = value!)),
              _buildSiteCheckbox(
                  "Booth", Booth, (value) => setState(() => Booth = value!)),
              _buildSiteCheckbox("Surugaya", Surugaya,
                  (value) => setState(() => Surugaya = value!)),
              _buildSiteCheckbox("Toranoana", Toranoana,
                  (value) => setState(() => Toranoana = value!)),
              _buildSiteCheckbox("Mandarake", Mandarake,
                  (value) => setState(() => Mandarake = value!)),
              if (imageUrlWidget != null) imageUrlWidget!,
              if (_image != null)
                Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.width * 10 / 16,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: FileImage(_image!),
                    ),
                  ),
                ),
              ElevatedButton(
                onPressed: pickImage,
                child: Text(_image == null ? "Choose Image" : "Change Image"),
              ),
              ElevatedButton(
                onPressed: updateAlert,
                child: const Text('Update Alert'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSiteCheckbox(
      String title, bool value, void Function(bool?) onChanged) {
    return CheckboxListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}

class TimeCard extends StatefulWidget {
  final String label;
  final int minValue, maxValue, value;
  final Function(int) onChanged;

  const TimeCard(
      {Key? key,
      required this.label,
      required this.minValue,
      required this.maxValue,
      required this.value,
      required this.onChanged})
      : super(key: key);

  @override
  _TimeCardState createState() => _TimeCardState();
}

class _TimeCardState extends State<TimeCard> {
  @override
  Widget build(BuildContext context) {
    List<DropdownMenuItem<int>> menuItems = List.generate(
      widget.maxValue - widget.minValue + 1,
      (index) => DropdownMenuItem(
          value: widget.minValue + index,
          child: Text('${widget.minValue + index}')),
    );

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Text(widget.label),
          DropdownButton<int>(
            value: widget.value,
            items: menuItems,
            onChanged: (int? newValue) {
              setState(() {
                widget.onChanged(newValue ?? 0);
              });
            },
          ),
        ],
      ),
    );
  }
}
