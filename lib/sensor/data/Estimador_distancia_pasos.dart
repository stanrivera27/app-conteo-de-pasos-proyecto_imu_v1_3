import 'dart:math';

// =================================================================
// PARTE 1: EL "CEREBRO" - La Lógica Difusa
// Esta clase es independiente y la puedes poner en su propio archivo.
// =================================================================
class ControladorDifusoK {
  // --- ETAPA 1: FUZIFICACIÓN (Convertir números a ideas) ---

  // Convierte la duración (en muestras) a grados de pertenencia 'Bajo', 'Medio', 'Alto'.
  Map<String, double> _fuzificarDuracion(double duracionEnMuestras) {
    // Validar entrada para evitar NaN
    if (!duracionEnMuestras.isFinite || duracionEnMuestras < 0) {
      duracionEnMuestras = 0.0;
    }

    // <-- VALORES ACTUALIZADOS SEGÚN TU TABLA DE TIEMPOS
    return {
      'Bajo': _triangular(duracionEnMuestras, 50, 67, 79),
      'Medio': _triangular(duracionEnMuestras, 67, 79, 105),
      'Alto': _triangular(duracionEnMuestras, 79, 105, 175),
    };
  }

  // Convierte la aceleración (en g) a grados de pertenencia 'Bajo', 'Medio', 'Alto'.
  Map<String, double> _fuzificarDiferenciaAceleracion(double diferencia) {
    // Validar entrada para evitar NaN
    if (!diferencia.isFinite || diferencia < 0) {
      diferencia = 0.0;
    }

    // <-- VALORES ACTUALIZADOS SEGÚN TU TABLA DE PASOS LONGITUD
    return {
      'Bajo': _triangular(diferencia, 2.3, 3.9, 5.22),
      'Medio': _triangular(diferencia, 3.9, 5.22, 5.92),
      'Alto': _triangular(diferencia, 5.22, 5.92, 11.16),
    };
  }

  // --- ETAPA 2: BASE DE REGLAS (3x3) ---
  // Esta es la inteligencia del sistema, basada en tu análisis.
  final Map<String, String> _baseDeReglas = {
    // Duración | Aceleración -> k
    'Bajo-Bajo': 'Bajo', 'Bajo-Medio': 'Bajo', 'Bajo-Alto': 'Medio',
    'Medio-Bajo': 'Bajo', 'Medio-Medio': 'Medio', 'Medio-Alto': 'Alto',
    'Alto-Bajo': 'Medio', 'Alto-Medio': 'Alto', 'Alto-Alto': 'Alto',
  };

  // --- ETAPA 3: DESDIFUSIÓN (Convertir ideas de nuevo a un número) ---
  double _desdifusificar(Map<String, double> gradosActivacion) {
    // <-- VALORES ACTUALIZADOS SEGÚN TU IMAGEN
    final Map<String, double> valoresK = {
      'Bajo': 0.38,
      'Medio': 0.43,
      'Alto': 0.48,
    };

    double numerador = 0.0;
    double denominador = 0.0;

    gradosActivacion.forEach((nivelK, grado) {
      // Validar que el grado sea finito
      if (grado.isFinite) {
        numerador += (valoresK[nivelK] ?? 0.0) * grado;
        denominador += grado;
      }
    });

    // Devuelve el promedio ponderado, o un valor por defecto si no se activó ninguna regla.
    if (denominador > 0 && numerador.isFinite) {
      double resultado = numerador / denominador;
      // Validar que el resultado sea finito y dentro de rangos razonables
      if (resultado.isFinite && resultado >= 0.1 && resultado <= 1.0) {
        return resultado;
      }
    }
    return 0.43; // Valor por defecto
  }

  // --- MÉTODO PÚBLICO PRINCIPAL ---
  // Este es el único método que llamarás desde fuera de la clase.
  double calcularK(double duracionEnMuestras, double diferenciaAceleracion) {
    // Validar entradas
    if (!duracionEnMuestras.isFinite || !diferenciaAceleracion.isFinite) {
      return 0.43; // Valor por defecto si hay valores inválidos
    }

    final gradosDuracion = _fuzificarDuracion(duracionEnMuestras);
    final gradosAceleracion = _fuzificarDiferenciaAceleracion(
      diferenciaAceleracion,
    );
    final Map<String, double> gradosActivacionK = {};

    // Inferencia: Aplicar las reglas
    gradosDuracion.forEach((nivelDur, gradoDur) {
      // Validar que el grado sea finito
      if (gradoDur.isFinite && gradoDur > 0) {
        gradosAceleracion.forEach((nivelAcel, gradoAcel) {
          // Validar que el grado sea finito
          if (gradoAcel.isFinite && gradoAcel > 0) {
            final regla = _baseDeReglas['$nivelDur-$nivelAcel'];
            if (regla != null) {
              final gradoActivacion = min(gradoDur, gradoAcel);
              // Validar que el grado de activación sea finito
              if (gradoActivacion.isFinite) {
                gradosActivacionK[regla] = max(
                  gradosActivacionK[regla] ?? 0.0,
                  gradoActivacion,
                );
              }
            }
          }
        });
      }
    });

    return _desdifusificar(gradosActivacionK);
  }

  // Función de ayuda para calcular la pertenencia a un triángulo
  double _triangular(double x, double a, double b, double c) {
    // Validar entradas para evitar NaN
    if (!x.isFinite || !a.isFinite || !b.isFinite || !c.isFinite) {
      return 0.0;
    }

    // Validar que los parámetros estén en orden correcto
    if (a > b || b > c || a == c) {
      return 0.0;
    }

    if (x <= a || x >= c) return 0.0;
    if (x == b) return 1.0;
    if (x > a && x < b) {
      double denominator = (b - a);
      if (denominator == 0) return 0.0;
      double result = (x - a) / denominator;
      return result.isFinite ? result : 0.0;
    }
    double denominator = (c - b);
    if (denominator == 0) return 0.0;
    double result = (c - x) / denominator;
    return result.isFinite ? result : 0.0;
  }
}
