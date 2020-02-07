import 'dart:io';
import 'package:xml/xml.dart' as xml;

/// Use [pathCsv] as a file with all information
/// Use [pathMapping] as a file with the new structure that will be added to the [pathOldXML] file.
/// The principal aspect within the the [pathCsv] and [pathMapping] is both have the tags `par_codigo_parametro` and `name`
/// that tag will be used as a matcher key.
/// Use [pathOldXML] as a file that will be updated
void generateXMLFile(String pathCsv, String pathMapping, String pathOldXML,
    String fileXmlTags) {
  // Read all files as a list of Strings
  List<String> linesCsv = File(pathCsv).readAsLinesSync();
  List<String> linesMap = File(pathMapping).readAsLinesSync();
  List<String> linesOldXML = File(pathOldXML).readAsLinesSync();

  var camposOCRcsv = List<Map>();
  //region Filling the Model with csv
  for (var line_csv in linesCsv) {
    RegExp cleanXML = new RegExp(r'(.*[#;!$%^&*()\\\/?]?)000');

    line_csv = line_csv.replaceAllMapped(RegExp(r';'), (Match m) => '@');
    line_csv = line_csv.replaceAllMapped(
        RegExp(r'[#;!$%^&*()\\\/?]@'), (Match m) => '000@');
    line_csv = line_csv.replaceAllMapped(RegExp(r'<'), (Match m) => '&lt;');
    line_csv = line_csv.replaceAllMapped(RegExp(r'>'), (Match m) => '&gt;');

    /// Capture information with regex
    RegExp expCsv = RegExp(r'([\w áéíóúÁÉÍÓÚüÜñÑ#<>&|\/\.\?\/();\-]+)|\B');
    var matches_csv = expCsv.allMatches(line_csv);
    var tempOCR = List<String>();
    for (var match in matches_csv) {
      var matchText = match.group(0);
      matchText = cleanXML.firstMatch(matchText) != null
          ? cleanXML.firstMatch(matchText).group(1)
          : matchText;
      tempOCR.add(matchText);
    }
    camposOCRcsv.add(_generateMapfromXML(fileXmlTags, tempOCR));
  }
  //endregion

  var mapFile = List<Map>();
  //region Capture parcodigo key
  RegExp expMap_tag = RegExp(r'<(.*)>(.+|\B)<.*>');
  var tempMap = Map();

  /// Filling the model with mapping
  for (var line_map in linesMap) {
    if (expMap_tag.stringMatch(line_map) == null) continue;
    tempMap[expMap_tag.firstMatch(line_map).group(1)] =
        expMap_tag.firstMatch(line_map).group(2);
    if (expMap_tag.firstMatch(line_map).group(1) == 'name') {
      mapFile.add(tempMap);
      tempMap = Map();
    }
  }
  //endregion

  //region Joing the models
  for (var m in mapFile) {
    Map c;
    if (m['campo'] == null) {
      // TODO firstWhere is not a good idea due to there is duplicated information.
      c = camposOCRcsv.firstWhere(
          (s) =>
              s['parrafo_pantalla'] == m['parrafo_pantalla'] &&
              s['par_codigo_parametro'] == m['par_codigo_parametro'],
          orElse: () => null);
    } else {
      c = camposOCRcsv.firstWhere(
          (s) =>
              s['parrafo_pantalla'] == m['parrafo_pantalla'] &&
              s['par_codigo_parametro'] == m['par_codigo_parametro'] &&
              s['campo'] == m['campo'],
          orElse: () => null);
    }
    if (c == null) {
      camposOCRcsv.add(_generateMapfromMap(fileXmlTags, m));
      continue;
    }

    if(c['name'] != 'undefined'){
      camposOCRcsv.add(_generateMapfromMap(fileXmlTags, m));
      camposOCRcsv.last.forEach((ck, cv) {
        c.forEach((mk, mv) {//cloned
          if (ck == mk && ck!='name' && ck != 'seleccion') {
            camposOCRcsv.last[ck] = mv;
          }
        });
      });
    }else {
      c.forEach((ck, cv) {
        m.forEach((mk, mv) {
          if (ck == mk) {
            c[ck] = mv;
          }
        });
      });
    }

    if(c['catalogo-jerarquia'] != 'indefined')
      {
        c['catalogo-jerarquia'] = getJerarquiaCatalogo(c['forma_asignacion'], c['catalogo-jerarquia']);
      }
  }
  //endregion

  //Create a new file
  RegExp match_tag = RegExp(r'\s*<name>(.*)<\/name>');
  List<String> newXML = List<String>();
  for (var xml in linesOldXML) {
    if (match_tag.firstMatch(xml) == null) {
      newXML.add(xml);
      continue;
    }

    var nameMatch = match_tag.firstMatch(xml).group(1);
    if (nameMatch != null) {
      var campoOCR = camposOCRcsv.firstWhere((mer) => mer['name'] == nameMatch, orElse: () => null);
      if(campoOCR == null)continue;
      var stringXMLname = '';
      campoOCR.forEach((k,v){
        stringXMLname+="<$k>$v</$k>\n";
      });
      newXML.add(stringXMLname);
    } else {
      newXML.add(xml);
    }
  }

//save new file
  new Directory('new_files').createSync();
  RegExp new_file =  RegExp(r'([\w]+.xml)');
  final nameFile = 'new_files\\'+new_file.firstMatch(pathOldXML).group(0);
  final file =
      File(nameFile);
  // Prettify the xml structure.
  final pretty =
      xml.parse(newXML.join("\n")).toXmlString(pretty: true, indent: '\t');

  var sink = file.openWrite();
  sink.write(pretty);

  sink.close();
  print("File saved on $nameFile");
}

/// Gets the Jerarquia or Catalog from the text
String getJerarquiaCatalogo(String catjer, String texto) {
  String jeraraquiaMatch;
  if (catjer == 'CATÁLOGO')
    return texto.split('-')[0];
  else {
    if (texto == 'undefined' || texto == '')
      return 'undefined';
    else {
      RegExp getCatalogo = new RegExp(r'(?=\w\d\/?)[\w\d\/?]{4,9}');
      jeraraquiaMatch = getCatalogo.firstMatch(texto).group(0);
    }
    return jeraraquiaMatch;
  }
}

/// Generate model from tags.txt
Map<dynamic, dynamic> _generateMapfromXML(
    String fileXmlTags, List<String> values) {
  List<String> linesXmlTags = File(fileXmlTags).readAsLinesSync();
  var mapXML = Map();
  for (var line in linesXmlTags) {
    if(!values.isNotEmpty){mapXML[RegExp(r'<(.*)></.*>').firstMatch(line).group(1)] = 'undefined';continue;};
    if (values.first != '') { //TODO values.first != '' significa llenar con undefined los campos xls que están en blanco. Estos campos pueden ser retirados.
      mapXML[RegExp(r'<(.*)></.*>').firstMatch(line).group(1)] = values.first;
      values.removeAt(0);
    } else {
      mapXML[RegExp(r'<(.*)></.*>').firstMatch(line).group(1)] = 'undefined';
      values.removeAt(0);
    }
  }
  return mapXML;
}
/// Generate Map from other Map object
Map _generateMapfromMap(String fileXmlTags, Map otherMap) {
  List<String> linesXmlTags = File(fileXmlTags).readAsLinesSync();
  var mapXML = Map();
  for (var line in linesXmlTags)
    mapXML[RegExp(r'<(.*)></.*>').firstMatch(line).group(1)] = 'undefined';
  if (otherMap.isNotEmpty) {
    otherMap.forEach((ok, ov) {
      mapXML.forEach((mk, mv) {
        if (ok == mk) mapXML[ok] = ov;
      });
    });
  }
  return mapXML;
}
