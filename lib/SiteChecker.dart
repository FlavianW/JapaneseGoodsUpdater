import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;


Future<int> extractResultsBooth(String artistName) async {
  try {
    // Encode l'artiste en format URL
    String encodedArtistName = Uri.encodeComponent(artistName);
    String url = 'https://booth.pm/en/search/$encodedArtistName'+'?in_stock=true';

    // Envoie la requête HTTP
    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      String htmlContent = response.body;

      // Parse le contenu HTML
      dom.Document document = parser.parse(htmlContent);

      // Recherche la balise spécifique avec le sélecteur CSS
      // NOTE: Ce sélecteur doit être ajusté selon la structure de la page et ce que vous essayez de trouver
      dom.Element? specificTag = document.querySelector(".u-d-flex.u-align-items-center.u-pb-300.u-tpg-body2.u-justify-content-between > b");

      if (specificTag != null) {
        // Extraire le nombre de la chaîne de texte
        RegExp regExp = RegExp(r'\d+'); // Regex pour trouver des chiffres
        Iterable<RegExpMatch> matches = regExp.allMatches(specificTag.text);

        if (matches.isNotEmpty) {
          // Convertit le premier match trouvé en nombre
          return int.parse(matches.first.group(0) ?? '0');
        } else {
          return 0; // Retourne 0 si aucun nombre n'est trouvé
        }
      } else {
        return 0; // Retourne 0 si le tag n'est pas trouvé
      }
    } else {
      print('Failed to load webpage');
      return 0; // En cas d'échec du chargement de la page
    }
  } catch (e) {
    print('Error parsing HTML: $e');
    return 0; // Retourne 0 en cas d'erreur
  }
}

Future<int> extractResultsMandarake(String artistName) async {
  try {
    String encodedArtistName = Uri.encodeComponent(artistName);
    String url = 'https://order.mandarake.co.jp/order/listPage/list?soldOut=1&keyword=$encodedArtistName&lang=en';

    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      String htmlContent = response.body;

      dom.Document document = parser.parse(htmlContent);

      dom.Element? resultCountElement = document.querySelector('div.count');

      if (resultCountElement != null) {
        String resultText = resultCountElement.text;

        RegExp regExp = RegExp(r'\d+');
        Iterable<RegExpMatch> matches = regExp.allMatches(resultText);

        if (matches.isNotEmpty) {
          return int.parse(matches.first.group(0) ?? '0');
        } else {
          return 0;
        }
      } else {
        return 0;
      }
    } else {
      print('Failed to load webpage');
      return 0;
    }
  } catch (e) {
    print('Error parsing HTML: $e');
    return 0;
  }
}

Future<int> extractResultsMelonbooks(String artistName) async {
  try {
    String encodedArtistName = Uri.encodeComponent(artistName);
    String url = 'https://www.melonbooks.co.jp/search/search.php?mode=search&search_disp=&category_id=0&text_type=&name=$encodedArtistName';

    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      String htmlContent = response.body;

      dom.Document document = parser.parse(htmlContent);

      dom.Element? resultCountElement = document.querySelector('#contents > div > div.search-console > div > div > p');

      if (resultCountElement != null) {
        // Le texte devrait être quelque chose comme "X件" où X est le nombre de résultats
        String resultText = resultCountElement.text;

        RegExp regExp = RegExp(r'\d+');
        Iterable<RegExpMatch> matches = regExp.allMatches(resultText);

        if (matches.isNotEmpty) {
          return int.parse(matches.first.group(0) ?? '0');
        } else {
          return 0;
        }
      } else {
        return 0;
      }
    } else {
      print('Failed to load webpage');
      return 0;
    }
  } catch (e) {
    print('Error parsing HTML: $e');
    return 0;
  }
}

Future<int> extractResultsRakuten(String searchQuery) async {
  try {
    // Encode le terme de recherche pour l'URL
    String encodedSearchQuery = Uri.encodeComponent(searchQuery);
    // Construit l'URL de recherche Rakuten avec le terme de recherche encodé
    String url = 'https://search.rakuten.co.jp/search/mall/$encodedSearchQuery'+'/?sf=1';

    // Envoie la requête HTTP et attend la réponse
    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      String htmlContent = response.body; // Obtient le contenu de la réponse

      // Parse le contenu HTML pour créer un document DOM
      dom.Document document = parser.parse(htmlContent);

      // Utilise le sélecteur CSS pour trouver l'élément avec le nombre de résultats
      dom.Element? resultCountElement = document.querySelector('#root > div.dui-container.nav > div > div > div.item.breadcrumb-model.breadcrumb.-fluid > div > span.count._medium');

      if (resultCountElement != null) {
        // Extrait le texte, qui est attendu sous la forme "1〜3件 （3件）"
        String resultText = resultCountElement.text;

        RegExp regExp = RegExp(r'（(\d{1,3}(,\d{3})*)件）'); // Cette expression régulière vise la partie entre parenthèses
        Iterable<RegExpMatch> matches = regExp.allMatches(resultText);

        if (matches.isNotEmpty) {
          // Extrait le nombre total de résultats à partir du match
          String totalResults = matches.first.group(1)?.replaceAll(',', '') ?? '0'; // Supprime les virgules avant de convertir
          return int.parse(totalResults);
        } else {
          return 0; // Retourne 0 si aucun nombre n'est trouvé
        }
      } else {
        return 0; // Retourne 0 si l'élément n'est pas trouvé
      }
    } else {
      print('Failed to load webpage');
      return 0; // Retourne 0 en cas d'échec de la requête
    }
  } catch (e) {
    print('Error parsing HTML: $e');
    return 0; // Retourne 0 en cas d'erreur lors du parsing
  }
}


Future<int> extractResultsSurugaya(String searchQuery) async {
  try {
    // Encode le terme de recherche pour l'URL
    String encodedSearchQuery = Uri.encodeComponent(searchQuery);
    // Construit l'URL de recherche Surugaya avec le terme de recherche encodé
    String url = 'https://www.suruga-ya.com/en/products?keyword=$encodedSearchQuery&btn_search=&in_stock=f';

    // Envoie la requête HTTP et attend la réponse
    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      String htmlContent = response.body; // Obtient le contenu de la réponse

      // Parse le contenu HTML pour créer un document DOM
      dom.Document document = parser.parse(htmlContent);

      // Utilise le sélecteur CSS pour trouver l'élément avec le nombre de résultats
      dom.Element? resultCountElement = document.querySelector('.alert-total-products');
      if (resultCountElement != null) {
        // Extrait le texte, qui est attendu sous la forme "1-10 of over 10 results"
        String resultText = resultCountElement.text.trim();
        // Utilise RegExp pour extraire le nombre total de résultats
        RegExp regExp = RegExp(r'over\s+(\d+)\s+results');
        var match = regExp.firstMatch(resultText);
        if (match != null && match.groupCount >= 1) {
          // Convertit la chaîne capturée en un entier et le retourne
          return int.parse(match.group(1) ?? '0');
        } else {
          return 0; // Retourne 0 si aucun nombre n'est trouvé
        }
      } else {
        return 0; // Retourne 0 si l'élément n'est pas trouvé
      }
    } else {
      print('Failed to load webpage');
      return 0; // Retourne 0 en cas d'échec de la requête
    }
  } catch (e) {
    print('Error parsing HTML: $e');
    return 0; // Retourne 0 en cas d'erreur lors du parsing
  }
}

Future<int> extractResultsToranoana(String searchQuery) async {
  try {
    // Encode le terme de recherche pour l'URL
    String encodedSearchQuery = Uri.encodeComponent(searchQuery);
    // Construit l'URL de recherche Toranoana avec le terme de recherche encodé
    String url = 'https://ecs.toranoana.jp/tora/ec/app/catalog/list/?searchWord=$encodedSearchQuery&searchBackorderFlg=1&searchUsedItemFlg=1&searchDisplay=0&detailSearch=true';

    // Envoie la requête HTTP et attend la réponse
    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      String htmlContent = response.body; // Obtient le contenu de la réponse
      // Parse le contenu HTML pour créer un document DOM
      var document = parser.parse(htmlContent);

      // Utilise le sélecteur CSS pour trouver la balise meta avec le nom "description"
      var metaDescription = document.querySelector('meta[name="description"]');

      if (metaDescription != null) {
        // Extrait le contenu de l'attribut "content"
        String content = metaDescription.attributes['content'] ?? '';

        // Recherche du nombre à l'aide d'une expression régulière
        final RegExp regExp = RegExp(r'\d+');
        final match = regExp.firstMatch(content);

        if (match != null) {
          // Conversion du nombre extrait en entier
          return int.parse(match.group(0)!);
        }
      }
      return 0; // Retourne 0 si l'élément ou le nombre n'est pas trouvé
    } else {
      print('Failed to load webpage');
      return 0; // Retourne 0 en cas d'échec de la requête
    }
  } catch (e) {
    print('Error: $e');
    return 0; // Retourne 0 en cas d'erreur lors du parsing ou de la requête
  }
}


