class ProcesamientoEventos {
  /// Devuelve la matriz acortada con procesamiento completo
  List<List<double>> matrizAcortada(
    List<double> unionCrucesPicosVallesList,
    List<double> ventana,
  ) {
    List<double> indices = List.generate(
      unionCrucesPicosVallesList.length,
      (index) => index.toDouble(),
    );

    final (
      simbolosFiltrados,
      magnitudesFiltradas,
      tiemposFiltrados,
    ) = filtrarSimbolosCero(unionCrucesPicosVallesList, ventana, indices);

    final datosProcesados = procesarSimbolosConsecutivos(
      simbolosFiltrados,
      magnitudesFiltradas,
      tiemposFiltrados,
    );

    return filtrarCrucesConsecutivos(datosProcesados);
  }

  /// Devuelve la matriz acortada con procesamiento completo (versión con heading de 4 filas)
  List<List<double>> matrizAcortadaConHeading(
    List<double> unionCrucesPicosVallesList,
    List<double> ventana,
    List<double> headingWindow,
  ) {
    List<double> indices = List.generate(
      unionCrucesPicosVallesList.length,
      (index) => index.toDouble(),
    );

    // Filtrar heading data usando los mismos índices que los eventos
    final headingCorrelacionado = <double>[];
    for (final index in indices) {
      final idx = index.toInt();
      if (idx >= 0 && idx < headingWindow.length) {
        headingCorrelacionado.add(headingWindow[idx]);
      } else {
        headingCorrelacionado.add(0.0);
      }
    }

    final (
      simbolosFiltrados,
      magnitudesFiltradas,
      tiemposFiltrados,
      headingFiltrado,
    ) = filtrarSimbolosCeroConHeading(
      unionCrucesPicosVallesList,
      ventana,
      indices,
      headingCorrelacionado,
    );

    final datosProcesados = procesarSimbolosConsecutivosConHeading(
      simbolosFiltrados,
      magnitudesFiltradas,
      tiemposFiltrados,
      headingFiltrado,
    );

    return filtrarCrucesConsecutivosConHeading(datosProcesados);
  }

  /// Elimina los ceros
  (List<double>, List<double>, List<double>) filtrarSimbolosCero(
    List<double> simbolosList,
    List<double> magnitudesList,
    List<double> tiemposList,
  ) {
    final simbolosFiltrados = <double>[];
    final magnitudesFiltradas = <double>[];
    final tiemposFiltrados = <double>[];

    // Encontrar la longitud mínima para evitar range errors
    final minLength = [
      simbolosList.length,
      magnitudesList.length,
      tiemposList.length,
    ].reduce((a, b) => a < b ? a : b);

    for (int i = 0; i < minLength; i++) {
      if (simbolosList[i] != 0) {
        simbolosFiltrados.add(simbolosList[i]);
        magnitudesFiltradas.add(magnitudesList[i]);
        tiemposFiltrados.add(tiemposList[i]);
      }
    }

    return (simbolosFiltrados, magnitudesFiltradas, tiemposFiltrados);
  }

  /// Elimina los ceros (versión con 4 filas incluyendo heading)
  (List<double>, List<double>, List<double>, List<double>)
  filtrarSimbolosCeroConHeading(
    List<double> simbolosList,
    List<double> magnitudesList,
    List<double> tiemposList,
    List<double> headingList,
  ) {
    final simbolosFiltrados = <double>[];
    final magnitudesFiltradas = <double>[];
    final tiemposFiltrados = <double>[];
    final headingFiltrado = <double>[];

    // Encontrar la longitud mínima para evitar range errors
    final minLength = [
      simbolosList.length,
      magnitudesList.length,
      tiemposList.length,
      headingList.length,
    ].reduce((a, b) => a < b ? a : b);

    for (int i = 0; i < minLength; i++) {
      if (simbolosList[i] != 0) {
        simbolosFiltrados.add(simbolosList[i]);
        magnitudesFiltradas.add(magnitudesList[i]);
        tiemposFiltrados.add(tiemposList[i]);
        headingFiltrado.add(headingList[i]);
      }
    }

    return (
      simbolosFiltrados,
      magnitudesFiltradas,
      tiemposFiltrados,
      headingFiltrado,
    );
  }

  /// Procesa símbolos consecutivos para reducir duplicados
  List<List<double>> procesarSimbolosConsecutivos(
    List<double> simbolosFiltrados,
    List<double> magnitudesFiltradas,
    List<double> tiemposFiltrados,
  ) {
    final datosProcesados = [
      <double>[], // símbolos
      <double>[], // magnitudes
      <double>[], // tiempos
    ];

    // Validación de dimensiones
    final minLength = [
      simbolosFiltrados.length,
      magnitudesFiltradas.length,
      tiemposFiltrados.length,
    ].reduce((a, b) => a < b ? a : b);

    if (minLength == 0) {
      return datosProcesados;
    }

    int? simboloActual;
    double? mejorMagnitud;
    double? mejorTiempo;

    for (int i = 0; i < minLength; i++) {
      final simbolo = simbolosFiltrados[i].toInt();
      final magnitud = magnitudesFiltradas[i];
      final tiempo = tiemposFiltrados[i];

      if (simbolo != simboloActual) {
        if (simboloActual != null && simboloActual != 1) {
          datosProcesados[0].add(simboloActual.toDouble());
          datosProcesados[1].add(mejorMagnitud!);
          datosProcesados[2].add(mejorTiempo!);
        }

        simboloActual = simbolo;

        if (simbolo == 1) {
          datosProcesados[0].add(1.0);
          datosProcesados[1].add(magnitud);
          datosProcesados[2].add(tiempo);
          simboloActual = null;
        } else {
          mejorMagnitud = magnitud;
          mejorTiempo = tiempo;
        }
      } else {
        if (simbolo == 2 && mejorMagnitud != null && magnitud > mejorMagnitud) {
          mejorMagnitud = magnitud;
          mejorTiempo = tiempo;
        } else if (simbolo == 3 &&
            mejorMagnitud != null &&
            magnitud < mejorMagnitud) {
          mejorMagnitud = magnitud;
          mejorTiempo = tiempo;
        }
      }
    }

    if (simboloActual != null && simboloActual != 1) {
      datosProcesados[0].add(simboloActual.toDouble());
      datosProcesados[1].add(mejorMagnitud!);
      datosProcesados[2].add(mejorTiempo!);
    }

    return datosProcesados;
  }

  /// Procesa símbolos consecutivos para reducir duplicados (versión con heading)
  List<List<double>> procesarSimbolosConsecutivosConHeading(
    List<double> simbolosFiltrados,
    List<double> magnitudesFiltradas,
    List<double> tiemposFiltrados,
    List<double> headingFiltrado,
  ) {
    final datosProcesados = [
      <double>[], // símbolos
      <double>[], // magnitudes
      <double>[], // tiempos
      <double>[], // heading
    ];

    // Validación de dimensiones
    final minLength = [
      simbolosFiltrados.length,
      magnitudesFiltradas.length,
      tiemposFiltrados.length,
      headingFiltrado.length,
    ].reduce((a, b) => a < b ? a : b);

    if (minLength == 0) {
      return datosProcesados;
    }

    int? simboloActual;
    double? mejorMagnitud;
    double? mejorTiempo;
    double? mejorHeading;

    for (int i = 0; i < minLength; i++) {
      final simbolo = simbolosFiltrados[i].toInt();
      final magnitud = magnitudesFiltradas[i];
      final tiempo = tiemposFiltrados[i];
      final heading = headingFiltrado[i];

      if (simbolo != simboloActual) {
        if (simboloActual != null && simboloActual != 1) {
          datosProcesados[0].add(simboloActual.toDouble());
          datosProcesados[1].add(mejorMagnitud!);
          datosProcesados[2].add(mejorTiempo!);
          datosProcesados[3].add(mejorHeading!);
        }

        simboloActual = simbolo;

        if (simbolo == 1) {
          datosProcesados[0].add(1.0);
          datosProcesados[1].add(magnitud);
          datosProcesados[2].add(tiempo);
          datosProcesados[3].add(heading);
          simboloActual = null;
        } else {
          mejorMagnitud = magnitud;
          mejorTiempo = tiempo;
          mejorHeading = heading;
        }
      } else {
        if (simbolo == 2 && mejorMagnitud != null && magnitud > mejorMagnitud) {
          mejorMagnitud = magnitud;
          mejorTiempo = tiempo;
          mejorHeading = heading;
        } else if (simbolo == 3 &&
            mejorMagnitud != null &&
            magnitud < mejorMagnitud) {
          mejorMagnitud = magnitud;
          mejorTiempo = tiempo;
          mejorHeading = heading;
        }
      }
    }

    if (simboloActual != null && simboloActual != 1) {
      datosProcesados[0].add(simboloActual.toDouble());
      datosProcesados[1].add(mejorMagnitud!);
      datosProcesados[2].add(mejorTiempo!);
      datosProcesados[3].add(mejorHeading!);
    }

    return datosProcesados;
  }

  /// Filtra los cruces consecutivos, dejando solo el primero de cada grupo
  List<List<double>> filtrarCrucesConsecutivos(List<List<double>> datosCrudos) {
    final simbolosFiltrados = <double>[];
    final magnitudesFiltrados = <double>[];
    final tiemposFiltrados = <double>[];

    // Validación de entrada
    if (datosCrudos.isEmpty || datosCrudos[0].isEmpty) {
      return [simbolosFiltrados, magnitudesFiltrados, tiemposFiltrados];
    }

    // Verificar que todas las filas tengan la misma longitud
    final expectedLength = datosCrudos[0].length;
    for (int row = 1; row < datosCrudos.length; row++) {
      if (datosCrudos[row].length != expectedLength) {
        return [simbolosFiltrados, magnitudesFiltrados, tiemposFiltrados];
      }
    }

    int i = 0;
    while (i < datosCrudos[0].length) {
      final simbolo = datosCrudos[0][i];

      if (simbolo == 1) {
        // Guarda solo el primer cruce por cero
        simbolosFiltrados.add(1.0);
        magnitudesFiltrados.add(datosCrudos[1][i]);
        tiemposFiltrados.add(datosCrudos[2][i]);

        // Salta todos los cruces consecutivos
        while (i + 1 < datosCrudos[0].length && datosCrudos[0][i + 1] == 1) {
          i++;
        }
      } else {
        simbolosFiltrados.add(simbolo);
        magnitudesFiltrados.add(datosCrudos[1][i]);
        tiemposFiltrados.add(datosCrudos[2][i]);
      }

      i++;
    }

    return [simbolosFiltrados, magnitudesFiltrados, tiemposFiltrados];
  }

  /// Filtra los cruces consecutivos, dejando solo el primero de cada grupo (versión con heading)
  List<List<double>> filtrarCrucesConsecutivosConHeading(
    List<List<double>> datosCrudos,
  ) {
    final simbolosFiltrados = <double>[];
    final magnitudesFiltrados = <double>[];
    final tiemposFiltrados = <double>[];
    final headingFiltrado = <double>[];

    // Validación de entrada
    if (datosCrudos.isEmpty || datosCrudos[0].isEmpty) {
      return [
        simbolosFiltrados,
        magnitudesFiltrados,
        tiemposFiltrados,
        headingFiltrado,
      ];
    }

    // Verificar que todas las filas tengan la misma longitud y que haya al menos 4 filas
    if (datosCrudos.length < 4) {
      return [
        simbolosFiltrados,
        magnitudesFiltrados,
        tiemposFiltrados,
        headingFiltrado,
      ];
    }

    final expectedLength = datosCrudos[0].length;
    for (int row = 1; row < 4; row++) {
      if (datosCrudos[row].length != expectedLength) {
        return [
          simbolosFiltrados,
          magnitudesFiltrados,
          tiemposFiltrados,
          headingFiltrado,
        ];
      }
    }

    int i = 0;
    while (i < datosCrudos[0].length) {
      final simbolo = datosCrudos[0][i];

      if (simbolo == 1) {
        // Guarda solo el primer cruce por cero
        simbolosFiltrados.add(1.0);
        magnitudesFiltrados.add(datosCrudos[1][i]);
        tiemposFiltrados.add(datosCrudos[2][i]);
        headingFiltrado.add(datosCrudos[3][i]);

        // Salta todos los cruces consecutivos con validación de límites
        while (i + 1 < datosCrudos[0].length &&
            i + 1 < datosCrudos[1].length &&
            i + 1 < datosCrudos[2].length &&
            i + 1 < datosCrudos[3].length &&
            datosCrudos[0][i + 1] == 1) {
          i++;
        }
      } else {
        // Validar que i esté dentro de límites para todas las filas antes de acceder
        if (i < datosCrudos[1].length &&
            i < datosCrudos[2].length &&
            i < datosCrudos[3].length) {
          simbolosFiltrados.add(simbolo);
          magnitudesFiltrados.add(datosCrudos[1][i]);
          tiemposFiltrados.add(datosCrudos[2][i]);
          headingFiltrado.add(datosCrudos[3][i]);
        }
      }

      i++;
    }

    return [
      simbolosFiltrados,
      magnitudesFiltrados,
      tiemposFiltrados,
      headingFiltrado,
    ];
  }
}
