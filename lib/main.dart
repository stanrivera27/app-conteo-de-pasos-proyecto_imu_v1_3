import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';

void main() {
  // Capture Flutter errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      print('Flutter Error: ${details.exception}');
      print('Stack trace: ${details.stack}');
    }
  };

  // Capture other errors with proper async zone handling
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Add small delay to ensure Flutter binding is fully ready
    await Future.delayed(const Duration(milliseconds: 100));
    
    runApp(const MyApp());
  }, (error, stack) {
    if (kDebugMode) {
      print('Uncaught error: $error');
      print('Stack trace: $stack');
    }
    // Log error for debugging but don't crash the app
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'main',
      context: ErrorDescription('Uncaught error in main'),
    ));
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi App Flutter - IMU Step Counter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      builder: (context, widget) {
        // Global error handler
        ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Error de la Aplicación'),
              backgroundColor: Colors.red,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'La aplicación ha encontrado un error',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (kDebugMode) ...[
                      Text(
                        'Error: ${errorDetails.exception}',
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Try to restart the app
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const MapScreen()),
                          (route) => false,
                        );
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        };
        return widget ?? const SizedBox();
      },
      home: const SafeAppHome(),
    );
  }
}

class SafeAppHome extends StatefulWidget {
  const SafeAppHome({super.key});

  @override
  State<SafeAppHome> createState() => _SafeAppHomeState();
}

class _SafeAppHomeState extends State<SafeAppHome> {
  bool _initializationFailed = false;
  String? _initError;
  
  @override
  void initState() {
    super.initState();
    _attemptInitialization();
  }
  
  Future<void> _attemptInitialization() async {
    try {
      // Add a small delay to ensure everything is ready
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Check if mounted before proceeding
      if (!mounted) return;
      
      // Try to initialize the main screen
      setState(() {
        _initializationFailed = false;
        _initError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _initializationFailed = true;
          _initError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializationFailed) {
      return _buildErrorScreen();
    }
    
    return FutureBuilder<Widget>(
      future: _buildMainScreen(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }
        
        if (snapshot.hasError) {
          return _buildErrorScreen(error: snapshot.error.toString());
        }
        
        return snapshot.data ?? _buildErrorScreen();
      },
    );
  }
  
  Future<Widget> _buildMainScreen() async {
    try {
      // Attempt to build MapScreen with error handling
      return const MapScreen();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading MapScreen, falling back to HomeScreen: $e');
      }
      // Fallback to HomeScreen if MapScreen fails
      try {
        return const HomeScreen();
      } catch (homeError) {
        if (kDebugMode) {
          print('Error loading HomeScreen: $homeError');
        }
        throw 'Both MapScreen and HomeScreen failed to initialize';
      }
    }
  }
  
  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ECDC4)),
            ),
            const SizedBox(height: 24),
            Text(
              'Inicializando aplicación...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withAlpha(200),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configurando sensores y componentes',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withAlpha(150),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildErrorScreen({String? error}) {
    final displayError = error ?? _initError ?? 'Error desconocido';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error de Inicialización'),
        backgroundColor: Colors.orange,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF0A0E27),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.warning_amber_outlined,
                  size: 64,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Error al inicializar la aplicación',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'La aplicación encontró un problema durante la inicialización. Por favor, intenta una de las siguientes opciones:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withAlpha(200),
                ),
                textAlign: TextAlign.center,
              ),
              if (kDebugMode && displayError.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withAlpha(100)),
                  ),
                  child: Text(
                    'Error técnico: $displayError',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              
              // Action buttons
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _initializationFailed = false;
                          _initError = null;
                        });
                        _attemptInitialization();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar Inicialización'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4ECDC4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const HomeScreen()),
                        );
                      },
                      icon: const Icon(Icons.home),
                      label: const Text('Ir a Pantalla de Análisis'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const MapScreen()),
                        );
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('Intentar Cargar Mapa'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}