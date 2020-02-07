import 'package:generate_xml_csv/generate_xml_csv.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;



void main() {
  test('readCSVFile', () {
    RegExp expCsv = new RegExp(r"([\w áéíóúÁÉÍÓÚüÜñÑ#<>|\.\?\/()-]+)");
    var str = "Esta;es;una;prueba";

    print("all...");
    Iterable<RegExpMatch> matches = expCsv.allMatches(str);
    for(var m in matches){
     print(m.group(0));
     print("..");
        }
    print("first....");
    var first = expCsv.firstMatch(str);
    print(first.group(0));

    print("string.....");
    var string = expCsv.stringMatch(str);
    print(string);

//    var a = expCsv.
  });
}
