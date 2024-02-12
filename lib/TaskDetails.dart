import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import 'SiteChecker.dart';

class TaskDetails extends StatefulWidget {
  final String userId;
  final String artiste;

  const TaskDetails({Key? key, required this.userId, required this.artiste})
      : super(key: key);

  @override
  _TaskDetailsState createState() => _TaskDetailsState();
}

class _TaskDetailsState extends State<TaskDetails> {
  Map<String, dynamic>? lastCheck;
  Map<String, dynamic>? siteFirstCheck;
  Map<String, int> differences = {};
  DocumentSnapshot? documentSnapshot;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    FirebaseFirestore firestoreInstance = FirebaseFirestore.instance;

    var querySnapshot = await firestoreInstance
        .collection('users')
        .doc(widget.userId)
        .collection('alerts')
        .where('artist', isEqualTo: widget.artiste)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      this.documentSnapshot = querySnapshot.docs.first;
      Map<String, dynamic>? data = this.documentSnapshot!.data() as Map<String, dynamic>?;

      setState(() {
        lastCheck = data?['LastCheck'] ?? data?['SiteFirstCheck'];
        siteFirstCheck = this.documentSnapshot!.get('SiteFirstCheck');
      });
      calculateDifferences();
    }
  }

  Future<void> resetButton() async {
    if (lastCheck != null && documentSnapshot != null) {
      FirebaseFirestore firestoreInstance = FirebaseFirestore.instance;

      firestoreInstance
          .collection('users')
          .doc(widget.userId)
          .collection('alerts')
          .doc(documentSnapshot?.id)
          .update({
        'SiteFirstCheck': lastCheck,
      });

      setState(() {
        differences = differences.map((key, value) => MapEntry(key, 0));
      });
    }
  }

  void calculateDifferences() {
    siteFirstCheck?.forEach((key, valueFirstCheck) {
      int valueLastCheck = lastCheck?[key] ?? 0;
      differences[key] =
          (valueFirstCheck - valueLastCheck).clamp(0, valueFirstCheck);
    });
  }

  Future<Map<String, int>> checkAndExecuteSiteFunctions(
      Map<String, bool> sites, String artistName) async {
    Map<String, int> siteResults = {};

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

    return siteResults;
  }

  Widget buildSiteLink(String siteName, String baseUrl) {
    return ListTile(
      title: Text(siteName),
      trailing: IconButton(
        icon: Icon(Icons.open_in_new),
        onPressed: () => launchURL(baseUrl, widget.artiste),
      ),
    );
  }

  Widget buildDifferenceWidget(String siteName) {
    int difference = differences[siteName] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: InkWell(
        onTap: () => launchURL(siteName, widget.artiste),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        siteName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.open_in_new, color: Colors.blue),
                    ],
                  ),
                  Text(
                    '$difference',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: difference > 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String getBaseUrl(String siteName, String artistName) {
    String encodedArtistName = Uri.encodeComponent(artistName);
    switch (siteName) {
      case 'Booth':
        return 'https://booth.pm/en/search/$encodedArtistName' +
            '?in_stock=true&sort=new';
      case 'Mandarake':
        return 'https://order.mandarake.co.jp/order/listPage/list?soldOut=1&keyword=$encodedArtistName' +
            '&lang=en';
      case 'Melonbooks':
        return 'https://www.melonbooks.co.jp/search/search.php?mode=search&search_disp=&category_id=0&text_type=&name=$encodedArtistName';
      case 'Rakuten':
        return 'https://search.rakuten.co.jp/search/mall/$encodedArtistName' +
            '/?sf=1&s=4';
      case 'Surugaya':
        return 'https://www.suruga-ya.com/en/products?keyword=$encodedArtistName' +
            '&btn_search=&in_stock=f&sort=updated_date_desc';
      case 'Toranoana':
        return 'https://ecs.toranoana.jp/tora/ec/app/catalog/list/?searchWord=$encodedArtistName' +
            '&searchBackorderFlg=1&searchUsedItemFlg=1&searchDisplay=0&detailSearch=true';
      default:
        return ''; // return empty string else
    }
  }

  Future<void> launchURL(String baseUrl, String artistName) async {
    final String finalUrl = getBaseUrl(baseUrl, artistName);
    final Uri url = Uri.parse(finalUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not launch $finalUrl')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.artiste),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: lastCheck == null || siteFirstCheck == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(50.0),
                  child: Text(
                    "Recap",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: differences.keys.map((siteName) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: buildDifferenceWidget(siteName),
                      );
                    }).toList(),
                  ),
                ),
                // Reset Button
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: ElevatedButton(
                    onPressed: () => resetButton(),
                    child: Text('Reset'),
                  ),
                ),
              ],
            ),
    );
  }
}
