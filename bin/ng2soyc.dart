library soyc;

import 'dart:convert' show JSON;
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import 'package:quiver/strings.dart';

int sizeThreshold = 500;  // in bytes

main(List<String> rawArgs) {
  var runner = new CommandRunner('soyc',
    'Story of your compile for Dart');
  runner.argParser.addOption('size_threshold', abbr: 't', callback: (String val) {
    if (val == null) return;
    sizeThreshold = int.parse(val);
  });
  runner.addCommand(new GroupCommand());
  runner.run(rawArgs);
}

class GroupCommand extends Command {
  final name = 'group';
  final description =
      'groups code size by dot-separated library sub-name convention';

  GroupCommand() {
  }

  @override
  run() async {
    if (argResults.rest.isEmpty) {
      throw 'Dump file not specified';
    }
    final jsFilePath = argResults.rest.single;
    if (!jsFilePath.endsWith('.dart.js')) {
      throw 'Not a .dart.js file: ${jsFilePath}';
    }
    final totalJsSize = await new File(jsFilePath).length();
    final dumpFilePath = '${path.withoutExtension(jsFilePath)}.info.json';
    final dumpJson = JSON.decode(new File(dumpFilePath).readAsStringSync());
    int ng2Bytes = 0;
    int ngDepsBytes = 0;
    int dartBytes = 0;
    int otherBytes = 0;
    int totalAccountedFor = 0;
    final subCats = <String, int>{};
    dumpJson['elements']['library'].forEach((_, Map lib) {
      String name = lib['name'];
      bool isNg2 = name.startsWith('angular');
      bool isNgDep = name.contains('.ng_deps.');
      bool isDart = name.startsWith('dart.');
      int size = lib['size'];
      if (isNgDep) {
        ngDepsBytes += size;
      } else if (isNg2) {
        ng2Bytes += size;
      } else if (isDart) {
        dartBytes += size;
      } else {
        otherBytes += size;
      }

      // report size for every sub-category
      if (!isNgDep) {
        final parts = name.split('.').toList();
        for (int i = 1; i <= parts.length; i++) {
          String subCat = parts.take(i).join('.');
          if (!subCats.containsKey(subCat)) {
            subCats[subCat] = 0;
          }
          subCats[subCat] += size;
        }
      }

      totalAccountedFor += size;
    });

    thickSpacer();
    print('Code size report for: ${jsFilePath}');
    thickSpacer();
    printCategory('True total file size:', totalJsSize, totalJsSize);
    thinSpacer();
    printCategory('ng2', ng2Bytes, totalJsSize);
    printCategory('ng_deps', ngDepsBytes, totalJsSize);
    printCategory('dart runtime libs', dartBytes, totalJsSize);
    printCategory('other', otherBytes, totalJsSize);
    printCategory('unaccounted for', totalJsSize - totalAccountedFor, totalJsSize);
    thinSpacer();
    print('breakdown');
    thinSpacer();
    (subCats.keys.toList()..sort()).forEach((String cat) {
      int size = subCats[cat];
      printCategory(cat, size, totalJsSize);
    });
    thickSpacer();
  }
}

void printCategory(String name, int size, int total) {
  double pct = 100 * size.toDouble() / total.toDouble();
  if (size < sizeThreshold) {
    // too much detail
    return;
  }
  var pctFmt = pct.toStringAsFixed(2);
  print('${name}: ${size} bytes (${pctFmt}%)');
}

const LINE_LENGTH = 80;
final THICK_SPACER = repeat('=', LINE_LENGTH);
void thickSpacer() {
  print(THICK_SPACER);
}

final THIN_SPACER = repeat('-', LINE_LENGTH);
void thinSpacer() {
  print(THIN_SPACER);
}
