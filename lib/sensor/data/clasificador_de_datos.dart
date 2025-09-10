class AnalizadorDeSenales {
  static List<double> crucesPorCero(List<double> senalFiltrada) {
    int n = senalFiltrada.length;
    List<double> vectorCruces = List.filled(n, 0.0);

    for (int i = 1; i < n; i++) {
      if ((senalFiltrada[i - 1] > 0 && senalFiltrada[i] <= 0) ||
          (senalFiltrada[i - 1] < 0 && senalFiltrada[i] >= 0)) {
        vectorCruces[i] = 1.0;
      } else if (senalFiltrada[i - 1].abs() < 0.01 && senalFiltrada[i] > 0) {
        vectorCruces[i] = 1.0;
      } else if (senalFiltrada[i - 1] > 0 && senalFiltrada[i].abs() < 0.01) {
        vectorCruces[i] = 1.0;
      }
    }
    return vectorCruces;
  }

  static List<double> deteccionPicos(
    List<double> senalFiltrada,
    double umbralpico,
  ) {
    int n = senalFiltrada.length;
    int bandera = 0;
    List<double> senalPositiva = List.filled(n, 0.0);
    List<double> picos = List.filled(n, 0.0);

    for (int i = 0; i < n; i++) {
      senalPositiva[i] = senalFiltrada[i] > umbralpico ? senalFiltrada[i] : 0.0;
    }

    for (int i = 0; i < n; i++) {
      if (i == 0) {
        picos[i] = 0.0;
      } else if (senalPositiva[i - 1] < senalPositiva[i]) {
        bandera = 0;
      } else if (senalPositiva[i - 1] != 0.0 && bandera == 0) {
        picos[i - 1] = 1.0;
        bandera = 1;
      }
    }

    return picos;
  }

  static List<double> deteccionValles(
    List<double> senalFiltrada,
    double umbralValles,
  ) {
    int N = senalFiltrada.length;
    int bandera = 0;
    List<double> senalNegativa = List.filled(N, 0.0);
    List<double> valles = List.filled(N, 0.0);

    for (int n = 0; n < N; n++) {
      if (senalFiltrada[n] < umbralValles) {
        senalNegativa[n] = senalFiltrada[n];
      } else {
        senalNegativa[n] = 0.0;
      }
    }

    for (int n = 0; n < N; n++) {
      if (n == 0) {
        valles[n] = 0.0;
      } else if (senalNegativa[n - 1] > senalNegativa[n]) {
        bandera = 0;
      } else if (senalNegativa[n - 1] != 0 && bandera == 0) {
        valles[n - 1] = 1.0;
        bandera = 1;
      }
    }

    return valles;
  }

  static List<double> unionCrucesPicosValles(
    List<double> cruces,
    List<double> picos,
    List<double> valles,
  ) {
    // Validación de entrada para evitar range errors
    if (cruces.isEmpty || picos.isEmpty || valles.isEmpty) {
      return <double>[];
    }

    // Encontrar la longitud mínima para evitar acceso fuera de límites
    final minLength = [
      cruces.length,
      picos.length,
      valles.length,
    ].reduce((a, b) => a < b ? a : b);
    List<double> vectorCPV = List.filled(minLength, 0.0);

    for (int n = 0; n < minLength; n++) {
      if (cruces[n] == 1.0) {
        vectorCPV[n] = 1.0;
      }
    }

    for (int n = 0; n < minLength; n++) {
      if (picos[n] == 1.0) {
        vectorCPV[n] = 2.0;
      }
    }

    for (int n = 0; n < minLength; n++) {
      if (valles[n] == 1.0) {
        vectorCPV[n] = 3.0;
      }
    }

    return vectorCPV;
  }
}
