import 'dart:io';
import 'dart:convert';  // <-- necesario para jsonEncode
import 'package:path_provider/path_provider.dart';

class GuardarDatos {
  static Future<void> guardarMatrizJson(List<List<double>> matriz, String nombreArchivo) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$nombreArchivo.json';  // mejor extensión para JSON
    final file = File(path);

    final contenido = jsonEncode(matriz);
    await file.writeAsString(contenido);
  }
}
