import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DaylySportLocator {
  Future<Directory> getOrCreateDaylySportDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final daylySportDir = Directory(p.join(docsDir.path, 'daylySport'));
    if (!await daylySportDir.exists()) {
      await daylySportDir.create(recursive: true);
    }
    return daylySportDir;
  }
}