import 'package:flutter/material.dart';

class CreerAlerte extends StatefulWidget {
  final String uid;

  CreerAlerte({Key? key, required this.uid}) : super(key: key);

  @override
  _CreerAlerteState createState() => _CreerAlerteState();
}

class _CreerAlerteState extends State<CreerAlerte> {
  String artiste = '';
  int jours = 1, heures = 0, minutes = 0;
  bool sendNotifications = false;

  bool site1Checked = false;
  bool site2Checked = false;
  bool site3Checked = false;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Créer une Alerte"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(labelText: "Artist"),
              onChanged: (value) {
                artiste = value;
              },
            ),
            Row(
              children: [
                Expanded(
                  child: TimeCard(
                    label: "Jours",
                    minValue: 1,
                    maxValue: 7,
                    onChanged: (val) => setState(() => jours = val),
                  ),
                ),
                Expanded(
                  child: TimeCard(
                    label: "Heures",
                    minValue: 0,
                    maxValue: 23,
                    onChanged: (val) => setState(() => heures = val),
                  ),
                ),
                Expanded(
                  child: TimeCard(
                    label: "Minutes",
                    minValue: 0,
                    maxValue: 59,
                    onChanged: (val) => setState(() => minutes = val),
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              title: Text("Send notifications even if there are no new items"),
              value: sendNotifications,
              onChanged: (bool? newValue) {
                setState(() {
                  sendNotifications = newValue ?? false;
                });
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                "Sites to check",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Column(
              children: [
                // ... vos autres widgets ...
                CheckboxListTile(
                  title: Text("Site 1"),
                  value: site1Checked,
                  onChanged: (bool? newValue) {
                    setState(() {
                      site1Checked = newValue ?? false;
                    });
                  },
                ),
                CheckboxListTile(
                  title: Text("Site 2"),
                  value: site2Checked,
                  onChanged: (bool? newValue) {
                    setState(() {
                      site2Checked = newValue ?? false;
                    });
                  },
                ),
                CheckboxListTile(
                  title: Text("Site 3"),
                  value: site3Checked,
                  onChanged: (bool? newValue) {
                    setState(() {
                      site3Checked = newValue ?? false;
                    });
                  },
                ),
                // Bouton de soumission
                ElevatedButton(
                  onPressed: () {
                    // Logique pour soumettre l'alerte
                  },
                  child: Text('Soumettre l\'alerte'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TimeCard extends StatefulWidget {
  final String label;
  final int minValue, maxValue;
  final Function(int) onChanged;

  TimeCard({required this.label, required this.minValue, required this.maxValue, required this.onChanged});

  @override
  _TimeCardState createState() => _TimeCardState();
}

class _TimeCardState extends State<TimeCard> {
  int currentValue = 0;

  @override
  void initState() {
    super.initState();
    currentValue = widget.minValue;
  }

  @override
  Widget build(BuildContext context) {
    List<DropdownMenuItem<int>> menuItems = List.generate(
      widget.maxValue - widget.minValue + 1,
          (index) => DropdownMenuItem(value: widget.minValue + index, child: Text('${widget.minValue + index}')),
    );

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Text(widget.label),
          DropdownButton<int>(
            value: currentValue,
            items: menuItems,
            onChanged: (int? newValue) {
              setState(() {
                currentValue = newValue!;
                widget.onChanged(currentValue);
              });
            },
          ),
        ],
      ),
    );
  }
}
