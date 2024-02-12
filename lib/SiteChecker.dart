import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;

//For every function it will check the website and return the amount of articles IN STOCK

Future<int> extractResultsBooth(String artistName) async {
  try {
    String encodedArtistName = Uri.encodeComponent(artistName);
    String url = 'https://booth.pm/en/search/$encodedArtistName?in_stock=true';
    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      dom.Document document = parser.parse(response.body);
      dom.Element? specificTag = document.querySelector(
          ".u-d-flex.u-align-items-center.u-pb-300.u-tpg-body2.u-justify-content-between > b");

      if (specificTag != null) {
        RegExp regExp = RegExp(r'\d+');
        Iterable<RegExpMatch> matches = regExp.allMatches(specificTag.text);
        if (matches.isNotEmpty) {
          return int.parse(matches.first.group(0) ?? '0');
        }
      }
    }
    return 0;
  } catch (e) {
    return 0;
  }
}

Future<int> extractResultsMandarake(String artistName) async {
  try {
    String encodedArtistName = Uri.encodeComponent(artistName);
    String url =
        'https://order.mandarake.co.jp/order/listPage/list?soldOut=1&keyword=$encodedArtistName&lang=en';
    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      dom.Document document = parser.parse(response.body);
      dom.Element? resultCountElement = document.querySelector('div.count');

      if (resultCountElement != null) {
        RegExp regExp = RegExp(r'\d+');
        Iterable<RegExpMatch> matches =
            regExp.allMatches(resultCountElement.text);
        if (matches.isNotEmpty) {
          return int.parse(matches.first.group(0) ?? '0');
        }
      }
    }
    return 0;
  } catch (e) {
    return 0;
  }
}

Future<int> extractResultsMelonbooks(String artistName) async {
  try {
    String encodedArtistName = Uri.encodeComponent(artistName);
    String url =
        'https://www.melonbooks.co.jp/search/search.php?mode=search&search_disp=&category_id=0&text_type=&name=$encodedArtistName';
    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      dom.Document document = parser.parse(response.body);
      dom.Element? resultCountElement = document.querySelector(
          '#contents > div > div.search-console > div > div > p');

      if (resultCountElement != null) {
        RegExp regExp = RegExp(r'\d+');
        Iterable<RegExpMatch> matches =
            regExp.allMatches(resultCountElement.text);
        if (matches.isNotEmpty) {
          return int.parse(matches.first.group(0) ?? '0');
        }
      }
    }
    return 0;
  } catch (e) {
    return 0;
  }
}

Future<int> extractResultsRakuten(String searchQuery) async {
  try {
    String encodedSearchQuery = Uri.encodeComponent(searchQuery);
    String url =
        'https://search.rakuten.co.jp/search/mall/$encodedSearchQuery/?sf=1';
    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      dom.Document document = parser.parse(response.body);
      dom.Element? resultCountElement = document.querySelector(
          '#root > div.dui-container.nav > div > div > div.item.breadcrumb-model.breadcrumb.-fluid > div > span.count._medium');

      if (resultCountElement != null) {
        RegExp regExp = RegExp(r'（(\d{1,3}(,\d{3})*)件）');
        Iterable<RegExpMatch> matches =
            regExp.allMatches(resultCountElement.text);
        if (matches.isNotEmpty) {
          String totalResults =
              matches.first.group(1)?.replaceAll(',', '') ?? '0';
          return int.parse(totalResults);
        }
      }
    }
    return 0;
  } catch (e) {
    return 0;
  }
}

Future<int> extractResultsSurugaya(String searchQuery) async {
  try {
    String encodedSearchQuery = Uri.encodeComponent(searchQuery);
    String url =
        'https://www.suruga-ya.com/en/products?keyword=$encodedSearchQuery&btn_search=&in_stock=f';
    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      dom.Document document = parser.parse(response.body);
      dom.Element? resultCountElement =
          document.querySelector('.alert-total-products');

      if (resultCountElement != null) {
        RegExp regExp = RegExp(r'over\s+(\d+)\s+results');
        var match = regExp.firstMatch(resultCountElement.text);
        if (match != null && match.groupCount >= 1) {
          return int.parse(match.group(1) ?? '0');
        }
      }
    }
    return 0;
  } catch (e) {
    return 0;
  }
}

Future<int> extractResultsToranoana(String searchQuery) async {
  try {
    String encodedSearchQuery = Uri.encodeComponent(searchQuery);
    String url =
        'https://ecs.toranoana.jp/tora/ec/app/catalog/list/?searchWord=$encodedSearchQuery&searchBackorderFlg=1&searchUsedItemFlg=1&searchDisplay=0&detailSearch=true';
    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      var document = parser.parse(response.body);
      var productCountElement = document.querySelector(
          '#search-result-container > nav > div.ui-tabs-01 > div > a:nth-child(1) > span > span');

      if (productCountElement != null) {
        RegExp regExp = RegExp(r'\d+');
        var match = regExp.firstMatch(productCountElement.text);
        if (match != null) {
          return int.parse(match.group(0)!);
        }
      }
    }
    return 0;
  } catch (e) {
    return 0;
  }
}
