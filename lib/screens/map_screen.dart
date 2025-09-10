import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/node.dart';
import 'dart:math';
import '../algorithms/d_star_lite.dart';
//import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math' as math;

//para transparencia de imagen
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

//para trabajar con .json
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/poi.dart';

//para unificar con cesar
import '../sensor/data/conteopasostexteo.dart';
import '../sensor/global_sensor_manager.dart';
import '../sensor/data/sensor_processor.dart';
import '../widgets/graphbuilder.dart';
import '../sensor/guardar/savedata.dart';
import '../utils/background_processor.dart';
import '../utils/performance_monitor.dart';
import '../utils/map_grid_converter.dart';
import '../models/sensor_states.dart';

// Importación para navegación
import 'home_screen.dart';

Future<ui.Image> loadUiImage(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final bytes = data.buffer.asUint8List();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

// Map initialization context for tracking state and errors
class MapInitializationContext {
  bool gridInitialized = false;
  bool sensorsAvailable = false;
  bool animationsEnabled = false;
  bool poisLoaded = false;
  bool mapCreated = false;
  bool obstaclesLoaded = false;
  List<String> errors = [];
  DateTime? lastAttempt;
  int retryCount = 0;
  
  void addError(String error) {
    errors.add('${DateTime.now()}: $error');
    debugPrint('Map Init Error: $error');
  }
  
  void reset() {
    gridInitialized = false;
    sensorsAvailable = false;
    animationsEnabled = false;
    poisLoaded = false;
    mapCreated = false;
    obstaclesLoaded = false;
    errors.clear();
    lastAttempt = DateTime.now();
  }
  
  bool get hasMinimalRequirements => gridInitialized;
  bool get hasFullFunctionality => gridInitialized && sensorsAvailable && animationsEnabled && poisLoaded;
  
  String get statusSummary {
    final components = <String>[];
    if (gridInitialized) components.add('Grid');
    if (sensorsAvailable) components.add('Sensors');
    if (animationsEnabled) components.add('Animations');
    if (poisLoaded) components.add('POIs');
    if (obstaclesLoaded) components.add('Obstacles');
    
    return components.isEmpty ? 'No components initialized' : 'Initialized: ${components.join(", ")}}';
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  // Nuevas variables
  LatLng? startPoint; //punto de inicio
  LatLng? goalPoint; //punto destino
  bool selectingStart = true; //bandera para seleccionar el punto de inicio o destino
  // Nuevas variables
  // final int numRows = 800; //filas
  // final int numCols = 800; //columnas
  // Cambio para grilla cuadrada sin deformar mapa
  // Tamaño de la grilla (filas fijas, columnas se calculan)
  static const int kNumRows = 400;
  late int numRows;   // = kNumRows (se asigna en _recomputeGridMetrics)
  late int numCols;   // se calcula para que las celdas sean cuadradas
  late double latStep; // tamaño de celda en latitud
  late double lngStep; // tamaño de celda en longitud (igual a latStep)

  void _recomputeGridMetrics() {
    try {
      numRows = kNumRows;

      final latSpan = endBounds.latitude - startBounds.latitude;
      final lngSpan = endBounds.longitude - startBounds.longitude;

      // Validate spans before proceeding
      if (latSpan <= 0 || lngSpan <= 0) {
        throw Exception('Invalid coordinate spans: lat=$latSpan, lng=$lngSpan');
      }

      // Make square cells using latitude step
      latStep = latSpan / numRows;
      lngStep = latStep;

      // Adjust columns to cover the width without exceeding bounds
      numCols = (lngSpan / lngStep).floor();
      
      // Ensure minimum column count
      if (numCols <= 0) {
        numCols = 1;
        lngStep = lngSpan;
      }
      
      debugPrint('Grid metrics computed: ${numRows}x$numCols, latStep=$latStep, lngStep=$lngStep');
    } catch (e) {
      debugPrint('Error computing grid metrics: $e');
      // Set fallback values
      numRows = 400;
      numCols = 400;
      latStep = 0.001;
      lngStep = 0.001;
    }
  }

  //para seguir posicion  
  LatLng? _currentPosition;// Posición a  actual del usuario (fijada al seleccionar el inicio)
  
  double _deviceAngle = 0.0; //angulo de rotacion en radianes
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  AccelerometerEvent? _accelData;
  MagnetometerEvent? _magData;
  
  late List<List<Node>> grid;
  
  Set<Point<int>> obstacles = {};

  final MapController _mapController = MapController();
  // Aquí se almacenará la ruta calculada
  List<LatLng> path = [];

  LatLng startBounds = LatLng(6.241, -75.589); // esquina inferior izquierda
  LatLng endBounds = LatLng(6.242, -75.587); // esquina superior derecha

  List<POI> pointsOfInterest = []; // Todos los POIs desde el JSON
  List<POI> visiblePOIs = []; //Lista de POIS cercanos a la ruta

  // Global sensor manager integration
  GlobalSensorManager? _globalSensorManager;
  final GraphBuilder _graphBuilder = GraphBuilder();
  bool showgraph = false;
  
  // Arrow positioning and animation
  // ArrowState? _currentArrowState;
  // late MapGridConverter _gridConverter;
  LatLng? _arrowStartPosition;
  // List<ArrowState> _arrowPath = [];
  Timer? _arrowUpdateTimer;

  //para cuadros de texto
  int _stepCount = 0;
  double _distanceMeters = 0.0;
  bool _isCountingSteps = false;
  
  // Map initialization context
  final MapInitializationContext _initContext = MapInitializationContext();
  bool _mapInitializationFailed = false;

  @override
  void initState() {
    super.initState();
    _initializeMapComponents();
  }
  
  // Progressive initialization with error handling
  Future<void> _initializeMapComponents() async {
    _initContext.reset();
    _mapInitializationFailed = false;
    
    try {
      // Step 1: Grid metrics calculation (Critical)
      await _initializeGridMetrics();
      
      // Step 2: Load obstacles (Optional)
      await _initializeObstacles();
      
      // Step 3: Load POIs (Optional)
      await _initializePOIs();
      
      // Step 4: Initialize global sensor manager (Optional but important)
      await _initializeGlobalSensorManager();
      
      // Step 5: Initialize grid converter
      await _initializeGridConverter();
      
      // Step 6: Initialize animations (Optional)
      await _initializeAnimations();
      
      // Step 7: Initialize background processing
      await _initializeBackgroundProcessing();
      
      _initContext.mapCreated = true;
      debugPrint('Map initialization completed successfully: ${_initContext.statusSummary}');
      
    } catch (e) {
      _initContext.addError('Critical initialization failed: $e');
      _mapInitializationFailed = true;
      debugPrint('Map initialization failed: $e');
    }
    
    if (mounted) {
      setState(() {}); // Trigger rebuild with initialization results
    }
  }
  
  Future<void> _initializeGridMetrics() async {
    try {
      // Validate coordinate bounds before calculating grid
      if (!_validateCoordinateBounds()) {
        throw Exception('Invalid coordinate bounds');
      }
      
      _recomputeGridMetrics();
      
      // Validate calculated grid dimensions
      if (numRows <= 0 || numCols <= 0 || latStep <= 0 || lngStep <= 0) {
        throw Exception('Invalid grid dimensions calculated: rows=$numRows, cols=$numCols, latStep=$latStep, lngStep=$lngStep');
      }
      
      // Initialize grid safely
      grid = List.generate(
        numRows,
        (row) => List.generate(numCols, (col) => Node(row: row, col: col)),
      );
      
      // Mark walkable obstacles after grid initialization
      for (final obstacle in obstacles) {
        if (obstacle.x >= 0 && obstacle.x < numRows && 
            obstacle.y >= 0 && obstacle.y < numCols) {
          grid[obstacle.x][obstacle.y].walkable = false;
        }
      }
      
      _initContext.gridInitialized = true;
      debugPrint('Grid metrics initialized successfully: ${numRows}x$numCols');
    } catch (e) {
      _initContext.addError('Grid initialization failed: $e');
      // Try with default values as fallback
      try {
        numRows = 400;
        numCols = 400;
        latStep = 0.001;
        lngStep = 0.001;
        grid = List.generate(
          numRows,
          (row) => List.generate(numCols, (col) => Node(row: row, col: col)),
        );
        _initContext.gridInitialized = true;
        debugPrint('Grid initialized with default values');
      } catch (fallbackError) {
        _initContext.addError('Grid fallback failed: $fallbackError');
        rethrow; // This is critical, must work
      }
    }
  }
  
  Future<void> _initializeObstacles() async {
    try {
      await loadObstacles();
      _initContext.obstaclesLoaded = true;
    } catch (e) {
      _initContext.addError('Obstacles loading failed: $e');
      // Continue without obstacles - not critical
    }
  }
  
  Future<void> _initializePOIs() async {
    try {
      // Check if POI asset exists before loading
      if (!await _validatePOIAsset()) {
        _initContext.addError('POI asset validation failed');
        pointsOfInterest = [];
        return;
      }
      
      await loadPOIsFromJson();
      
      // Validate loaded POIs
      if (pointsOfInterest.isNotEmpty) {
        pointsOfInterest = pointsOfInterest.where((poi) => 
          _validatePOIData(poi)
        ).toList();
        debugPrint('Validated ${pointsOfInterest.length} POIs');
      }
      
      _initContext.poisLoaded = true;
    } catch (e) {
      _initContext.addError('POIs loading failed: $e');
      pointsOfInterest = [];
      // Continue without POIs - not critical
    }
  }
  
  Future<void> _initializeGlobalSensorManager() async {
    try {
      _globalSensorManager = GlobalSensorManager.getInstance();
      _globalSensorManager!.initialize();
      
      // Add listener for global sensor updates
      _globalSensorManager!.addListener(_onGlobalSensorUpdate);
      
      // Start arrow update timer
      _arrowUpdateTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
        _updateArrowPosition();
      });
      
      _initContext.sensorsAvailable = true;
      debugPrint('GlobalSensorManager initialized successfully');
    } catch (e) {
      _initContext.addError('Global sensor manager initialization failed: $e');
      // Continue without sensors - not critical
    }
  }
  
  Future<void> _initializeGridConverter() async {
    try {
      // _gridConverter = MapGridConverter(
      //   startBounds: startBounds,
      //   endBounds: endBounds,
      //   fixedRows: numRows,
      // );
      debugPrint('Grid converter initialization skipped (not implemented)');
    } catch (e) {
      _initContext.addError('Grid converter initialization failed: $e');
      debugPrint('WARNING: Grid converter initialization failed: $e');
    }
  }
  
  Future<void> _initializeAnimations() async {
    try {
      // Initialize shared animation controller for POI icons
      // if (mounted) {
      //   OptimizedAnimatedPOIIcon.initSharedController(this);
      // }
      _initContext.animationsEnabled = true;
      debugPrint('Animations initialization skipped (not implemented)');
    } catch (e) {
      _initContext.addError('Animation initialization failed: $e');
      _initContext.animationsEnabled = false;
      debugPrint('Animations disabled due to initialization error: $e');
      // Continue without animations - not critical
    }
  }
  
  Future<void> _initializeBackgroundProcessing() async {
    try {
      await BackgroundProcessor.instance.initialize();
      
      if (kDebugMode) {
        PerformanceMonitor.instance.startMonitoring();
      }
      
      debugPrint('Background processing initialized successfully');
    } catch (e) {
      _initContext.addError('Background processing failed: $e');
      debugPrint('WARNING: Background processing initialization failed: $e');
      // Continue without background processing - will affect path calculation
    }
  }
  
  // Validation methods for safe initialization
  bool _validateCoordinateBounds() {
    try {
      if (startBounds.latitude >= endBounds.latitude) {
        debugPrint('Invalid latitude bounds: start >= end');
        return false;
      }
      if (startBounds.longitude >= endBounds.longitude) {
        debugPrint('Invalid longitude bounds: start >= end');
        return false;
      }
      
      // Check if bounds are reasonable (not too small or too large)
      final latSpan = (endBounds.latitude - startBounds.latitude).abs();
      final lngSpan = (endBounds.longitude - startBounds.longitude).abs();
      
      if (latSpan < 0.0001 || lngSpan < 0.0001) {
        debugPrint('Bounds too small: lat=$latSpan, lng=$lngSpan');
        return false;
      }
      
      if (latSpan > 1.0 || lngSpan > 1.0) {
        debugPrint('Bounds too large: lat=$latSpan, lng=$lngSpan');
        return false;
      }
      
      return true;
    } catch (e) {
      debugPrint('Coordinate bounds validation failed: $e');
      return false;
    }
  }
  
  Future<bool> _validatePOIAsset() async {
    try {
      await rootBundle.loadString('assets/pois.json');
      return true;
    } catch (e) {
      debugPrint('POI asset validation failed: $e');
      return false;
    }
  }
  
  bool _validatePOIData(POI poi) {
    try {
      // Ensure grid is initialized before validating POI coordinates
      if (!_initContext.gridInitialized) {
        debugPrint('Cannot validate POI: grid not initialized');
        return false;
      }
      
      if (poi.cell.x < 0 || poi.cell.x >= numRows) {
        debugPrint('POI ${poi.name} x-coordinate outside bounds: ${poi.cell.x} (max: $numRows)');
        return false;
      }
      
      if (poi.cell.y < 0 || poi.cell.y >= numCols) {
        debugPrint('POI ${poi.name} y-coordinate outside bounds: ${poi.cell.y} (max: $numCols)');
        return false;
      }
      
      if (poi.name.isEmpty) {
        debugPrint('POI has empty name');
        return false;
      }
      
      return true;
    } catch (e) {
      debugPrint('POI data validation failed: $e');
      return false;
    }
  }

  //Proyecto Cesar - Global Sensor Manager
  @override
  void dispose() {
    try {
      // Remove listener from global sensor manager
      _globalSensorManager?.removeListener(_onGlobalSensorUpdate);
      
      _accelSub?.cancel();
      _magSub?.cancel();
      _gyroSubscription?.cancel();
      _compassUpdateTimer?.cancel();
      _arrowUpdateTimer?.cancel();
      
      BackgroundProcessor.instance.dispose();
      PerformanceMonitor.instance.dispose();
      
      // Dispose shared animation controller
      // OptimizedAnimatedPOIIcon.disposeSharedController();
    } catch (e) {
      debugPrint('Error in dispose: $e');
    }
    super.dispose();
  }
  
  // Global sensor data update handler
  void _onGlobalSensorUpdate() {
    _updateStepCountAndDistance();
    if (mounted) {
      setState(() {});
    }
  }
  
  // Update step count and distance from global sensor manager
  void _updateStepCountAndDistance() {
    if (_globalSensorManager == null) return;
    
    final sensorState = _globalSensorManager!.sensorState;
    _stepCount = sensorState.stepCount;
    _distanceMeters = sensorState.totalDistance;
    _isCountingSteps = sensorState.isRunning;
  }
  
  // Update arrow position based on global sensor data
  void _updateArrowPosition() {
    // Temporary disabled - requires ArrowState and MapGridConverter implementation
    /*
    if (_globalSensorManager == null || !_globalSensorManager!.isRunning || _arrowStartPosition == null) {
      return;
    }
    
    try {
      final positionState = _globalSensorManager!.positionState;
      
      if (positionState.isValid && positionState.accuracy > 0.1) {
        // Calculate new arrow state with smooth animation
        final newArrowState = _gridConverter.calculateArrowState(
          positionState,
          _arrowStartPosition!,
        );
        
        // Apply smooth transition if there's a previous arrow state
        if (_currentArrowState != null && newArrowState.isVisible) {
          // Smooth position transition
          final smoothPosition = ArrowAnimationHelper.calculateSmoothPosition(
            _currentArrowState!.position,
            newArrowState.position,
            0.3, // Lerp factor for smooth movement
          );
          
          // Smooth rotation transition
          final smoothRotation = ArrowAnimationHelper.calculateSmoothRotation(
            _currentArrowState!.rotation,
            newArrowState.rotation,
            0.4, // Lerp factor for rotation
          );
          
          // Calculate scale based on movement speed
          final currentSpeed = _globalSensorManager!.currentSpeed;
          final animatedScale = ArrowAnimationHelper.calculateScaleFromSpeed(currentSpeed);
          
          // Create smoothed arrow state
          _currentArrowState = newArrowState.copyWith(
            position: smoothPosition,
            rotation: smoothRotation,
            scale: animatedScale,
          );
        } else {
          // First arrow or not visible, use direct state
          _currentArrowState = newArrowState;
        }
        
        // Add to arrow path for trail visualization
        if (_currentArrowState != null && _currentArrowState!.isVisible) {
          // Only add to path if position has changed significantly
          final shouldAddToPath = _arrowPath.isEmpty ||
              ArrowAnimationHelper.calculateSmoothPosition(
                _arrowPath.last.position,
                _currentArrowState!.position,
                0.0,
              ) != _arrowPath.last.position; // Position changed
          
          if (shouldAddToPath) {
            _arrowPath.add(_currentArrowState!);
            
            // Limit path length to prevent memory issues
            if (_arrowPath.length > 100) {
              _arrowPath.removeAt(0);
            }
          }
        }
        
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Error updating arrow position: $e');
    }
    */
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planta 3 FIET - PSNEOPEC'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HomeScreen(),
                ),
              );
            },
            icon: const Icon(Icons.analytics),
            tooltip: 'Análisis de Datos',
          ),
        ],
      ),
      body: Stack(
        children: [
          RepaintBoundary(
            child: _buildSafeFlutterMap(),
          ),


          // Performance debug overlay (only in debug mode)
          if (kDebugMode)
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Performance',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    StreamBuilder<String>(
                      stream: _getPerformanceStream(),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? 'Monitoring...',
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Cuadros de texto y botón en la parte superior izquierda
          Positioned(
            top: 5,
            left: 0,
            child: Column(    
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white70,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Pasos: $_stepCount',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white70,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Distancia: ${_distanceMeters.toStringAsFixed(2)} m',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                // Route status indicator
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: path.isNotEmpty ? Colors.green.withOpacity(0.8) : Colors.orange.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    path.isNotEmpty ? 'Ruta: ${path.length} puntos' : 'Sin ruta',
                    style: const TextStyle(
                      fontSize: 14, 
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    if (_globalSensorManager == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sensores no disponibles')),
                      );
                      return;
                    }
                    
                    if (_globalSensorManager!.isRunning) {
                      // Stop sensors and reset arrow
                      _globalSensorManager!.stopSensors();
                      setState(() {
                        // _currentArrowState = null;
                        // _arrowPath.clear();
                        _arrowStartPosition = null;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sensores detenidos')),
                      );
                    } else {
                      // Start sensors and set arrow start position
                      _globalSensorManager!.startSensors();
                      
                      // Set arrow start position to current position or map center
                      if (startPoint != null) {
                        _arrowStartPosition = startPoint;
                      } else {
                        // Default to map center if no start point selected
                        _arrowStartPosition = LatLng(
                          (startBounds.latitude + endBounds.latitude) / 2,
                          (startBounds.longitude + endBounds.longitude) / 2,
                        );
                      }
                      
                      // Reset global sensor data for fresh start
                      _globalSensorManager!.resetData();
                      
                      setState(() {
                        // _currentArrowState = null;
                        // _arrowPath.clear();
                      });
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sensores iniciados - Comience a caminar')),
                      );
                    }
                  },
                  icon: Icon(_globalSensorManager?.isRunning == true ? Icons.stop : Icons.directions_walk),
                  label: Text(_globalSensorManager?.isRunning == true ? "Detener" : "Iniciar"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _globalSensorManager?.isRunning == true ? Colors.red : Colors.teal,
                    foregroundColor: Colors.white,
                    elevation: 3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            startPoint = null;
            goalPoint = null;
            path = [];
            selectingStart = true;
          });
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Point<int> latLngToGrid(LatLng point) {
    final row = ((point.latitude - startBounds.latitude) / latStep).floor();
    final col = ((point.longitude - startBounds.longitude) / lngStep).floor();

    return Point(row.clamp(0, numRows - 1), col.clamp(0, numCols - 1));
  }

  LatLng gridToLatLng(Node node) {
    final lat = startBounds.latitude + node.row * latStep + latStep / 2;
    final lng = startBounds.longitude + node.col * lngStep + lngStep / 2;

    return LatLng(
      lat, lng
    );
  }

  List<LatLng> getCellPolygon(int row, int col) {
    final  north = startBounds.latitude + row * latStep;
    final south = north + latStep;
    final west = startBounds.longitude + col * lngStep;
    final east = west + lngStep;
    return [
      LatLng(north, west),
      LatLng(north, east),
      LatLng(south, east),
      LatLng(south, west),
    ];
  }

  void calculatePath() async {
    debugPrint('=== CALCULATE PATH STARTED ===');
    
    if (startPoint == null || goalPoint == null) {
      debugPrint('ERROR: Start or goal point is null');
      debugPrint('Start point: $startPoint');
      debugPrint('Goal point: $goalPoint');
      return;
    }

    try {
      final startCell = latLngToGrid(startPoint!);
      final goalCell = latLngToGrid(goalPoint!);

      // Enhanced debug logging
      debugPrint('=== CALCULATING ROUTE ===');
      debugPrint('Start point: $startPoint');
      debugPrint('Goal point: $goalPoint');
      debugPrint('Start cell: $startCell');
      debugPrint('Goal cell: $goalCell');
      debugPrint('Grid initialized: ${_initContext.gridInitialized}');

      // Validation: same cell check
      if (startCell == goalCell) {
        debugPrint('ERROR: Start and goal are in the same cell');
        _showUserMessage('Selecciona un destino diferente al inicio', Colors.orange);
        return;
      }
      
      // Validate grid bounds
      if (startCell.x < 0 || startCell.x >= grid.length || 
          startCell.y < 0 || startCell.y >= grid[0].length ||
          goalCell.x < 0 || goalCell.x >= grid.length ||
          goalCell.y < 0 || goalCell.y >= grid[0].length) {
        debugPrint('ERROR: Points are outside grid bounds');
        _showUserMessage('Puntos fuera de los límites del mapa', Colors.red);
        return;
      }
      
      final startNode = grid[startCell.x][startCell.y];
      final goalNode = grid[goalCell.x][goalCell.y];

      // Validate nodes are walkable
      if (!startNode.walkable || !goalNode.walkable) {
        debugPrint('ERROR: Start or goal node is not walkable');
        debugPrint('Start walkable: ${startNode.walkable}');
        debugPrint('Goal walkable: ${goalNode.walkable}');
        _showUserMessage('Punto de inicio o destino no es accesible', Colors.orange);
        return;
      }

      // Show loading message
      _showUserMessage('Calculando ruta...', Colors.blue);

      // ATOMIC PATH CALCULATION AND UPDATE
      final calculatedPath = await _executePathCalculation(startNode, goalNode, startCell, goalCell);
      
      if (calculatedPath.isEmpty) {
        debugPrint('ERROR: No path found between points');
        _showUserMessage('No se encontró ruta entre los puntos', Colors.orange);
        return;
      }

      // Convert to coordinates
      final latLngPath = calculatedPath.map((node) => gridToLatLng(node)).toList();
      
      debugPrint('=== PATH CALCULATION SUCCESS ===');
      debugPrint('Path nodes: ${calculatedPath.length}');
      debugPrint('Path coordinates: ${latLngPath.length} points');
      debugPrint('First point: ${latLngPath.first}');
      debugPrint('Last point: ${latLngPath.last}');

      // ATOMIC STATE UPDATE - Single setState call for consistency
      if (mounted) {
        final routeCells = calculatedPath.map((n) => Point(n.row, n.col)).toList();
        final newVisiblePOIs = pointsOfInterest.where((poi) {
          return isPOINearRoute(poi.cell, routeCells);
        }).toList();

        setState(() {
          path = latLngPath;
          visiblePOIs = newVisiblePOIs;
        });

        debugPrint('=== STATE UPDATED SUCCESSFULLY ===');
        debugPrint('Final path length in state: ${path.length}');
        debugPrint('Visible POIs: ${visiblePOIs.length}');
        
        // Show success message
        _showUserMessage('Ruta calculada: ${latLngPath.length} puntos', Colors.green);
      }
    } catch (e, stackTrace) {
      debugPrint('=== PATH CALCULATION ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      _showUserMessage('Error calculando la ruta: $e', Colors.red);
    }
  }

  /// Execute path calculation with multiple fallback strategies
  Future<List<Node>> _executePathCalculation(Node startNode, Node goalNode, Point<int> startCell, Point<int> goalCell) async {
    debugPrint('=== EXECUTING PATH CALCULATION ===');
    
    // Strategy 1: Direct D* Lite calculation (most reliable)
    try {
      debugPrint('Trying direct D* Lite calculation...');
      final dStarLite = DStarLite(
        grid: grid,
        start: startNode,
        goal: goalNode,
      );
      final directPath = dStarLite.computeShortestPath();
      
      if (directPath.isNotEmpty) {
        debugPrint('Direct calculation SUCCESS: ${directPath.length} nodes');
        return directPath;
      } else {
        debugPrint('Direct calculation returned empty path');
      }
    } catch (directError) {
      debugPrint('Direct calculation FAILED: $directError');
    }

    // Strategy 2: Background processor (if direct fails)
    try {
      debugPrint('Trying background processor calculation...');
      final nodePath = await BackgroundProcessor.instance.calculatePath(
        grid: grid,
        startX: startCell.x,
        startY: startCell.y,
        goalX: goalCell.x,
        goalY: goalCell.y,
      ).timeout(Duration(seconds: 10)); // Add timeout
      
      if (nodePath.isNotEmpty) {
        debugPrint('Background processor SUCCESS: ${nodePath.length} nodes');
        return nodePath;
      } else {
        debugPrint('Background processor returned empty path');
      }
    } catch (bgError) {
      debugPrint('Background processor FAILED: $bgError');
    }

    debugPrint('=== ALL PATH CALCULATION STRATEGIES FAILED ===');
    return [];
  }

  /// Helper method for consistent user messaging
  void _showUserMessage(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  
  /// Simple viewport culling helper methods
  LatLngBounds _getVisibleBounds() {
    final camera = _mapController.camera;
    final bounds = camera.visibleBounds;
    const double padding = 0.1;
    
    final latSpan = bounds.north - bounds.south;
    final lngSpan = bounds.east - bounds.west;
    
    return LatLngBounds(
      LatLng(
        bounds.south - (latSpan * padding),
        bounds.west - (lngSpan * padding),
      ),
      LatLng(
        bounds.north + (latSpan * padding),
        bounds.east + (lngSpan * padding),
      ),
    );
  }
  
  bool _isPointVisible(LatLng point, LatLngBounds visibleBounds) {
    return point.latitude >= visibleBounds.south &&
           point.latitude <= visibleBounds.north &&
           point.longitude >= visibleBounds.west &&
           point.longitude <= visibleBounds.east;
  }
  
  int _calculateLOD(double zoomLevel) {
    if (zoomLevel < 16) return 20;
    if (zoomLevel < 17) return 10;
    if (zoomLevel < 18) return 5;
    if (zoomLevel < 19) return 2;
    return 1;
  }
  
  /// Get performance metrics stream for debug overlay
  Stream<String> _getPerformanceStream() {
    return Stream.periodic(const Duration(seconds: 1), (count) {
      if (!kDebugMode) return '';
      
      final metrics = PerformanceMonitor.instance.getMetrics();
      return 'FPS: ${metrics.currentFrameRate.toStringAsFixed(0)}\n'
             'Frame: ${metrics.averageFrameRate.toStringAsFixed(1)}fps\n'
             'Mem: ${metrics.currentMemoryUsage.toStringAsFixed(0)}MB\n'
             'Events: ${metrics.totalEvents}';
    });
  }

  List<Polyline> buildOptimizedGridLines() {
    final List<Polyline> lines = [];

    final endGridLat = startBounds.latitude + numRows * latStep;
    final endGridLng = startBounds.longitude + numCols * lngStep;
    
    // Get current zoom level for LOD
    final double zoomLevel = _mapController.camera?.zoom ?? 18;
    final int lod = _calculateLOD(zoomLevel);
    
    try {
      final visibleBounds = _getVisibleBounds();
      
      // Calculate visible range
      final startRow = ((visibleBounds.south - startBounds.latitude) / latStep).floor().clamp(0, numRows);
      final endRow = ((visibleBounds.north - startBounds.latitude) / latStep).ceil().clamp(0, numRows);
      final startCol = ((visibleBounds.west - startBounds.longitude) / lngStep).floor().clamp(0, numCols);
      final endCol = ((visibleBounds.east - startBounds.longitude) / lngStep).ceil().clamp(0, numCols);
      
      // Add horizontal lines with LOD
      for (int row = startRow; row <= endRow; row += lod) {
        final lat = startBounds.latitude + row * latStep;
        lines.add(
          Polyline(
            points: [LatLng(lat, startBounds.longitude), LatLng(lat, endGridLng)],
            color: Colors.black,
            strokeWidth: 0.3,
          )
        );
      }
      
      // Add vertical lines with LOD
      for (int col = startCol; col <= endCol; col += lod) {
        final lng = startBounds.longitude + col * lngStep;
        lines.add(
          Polyline(
            points: [LatLng(startBounds.latitude, lng), LatLng(endGridLat, lng)],
            color: Colors.black,
            strokeWidth: 0.3,
          )
        );
      }
    } catch (e) {
      // Fallback to simple grid with reduced density
      final gridStep = lod;
      for (int r = 0; r <= numRows; r += gridStep) {
        final lat = startBounds.latitude + r * latStep;
        lines.add(
          Polyline(
            points: [LatLng(lat, startBounds.longitude), LatLng(lat, endGridLng)],
            color: Colors.black.withOpacity(0.3),
            strokeWidth: 0.3,
          )
        );
      }
      
      for (int j = 0; j <= numCols; j += gridStep) {
        final lng = startBounds.longitude + j * lngStep;
        lines.add(
          Polyline(
            points: [LatLng(startBounds.latitude, lng), LatLng(endGridLat, lng)],
            color: Colors.black.withOpacity(0.3),
            strokeWidth: 0.3,
          )
        );
      }
    }

    return lines;
  }

  void toggleObstacle(LatLng latlng) async {
    final cell = latLngToGrid(latlng);

    setState(() {
      if (obstacles.contains(cell)) {
        // Desbloquear
        obstacles.remove(cell);
        grid[cell.x][cell.y].walkable = true;
      } else {
        // Bloquear
        obstacles.add(cell);
        grid[cell.x][cell.y].walkable = false;
      }
    });

    await saveObstacles();
  }

  //para trabajar con .json
  Future<void> saveObstacles() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/obstacles.json');

    final data = obstacles.map((p) => {'x': p.x, 'y': p.y}).toList();
    await file.writeAsString(jsonEncode(data));

    print('Obstáculos guardados en: ${file.path}');
  }

  Future<void> loadObstacles() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/obstacles.json');

    if (await file.exists()) {
      final contents = await file.readAsString();
      final List<dynamic> decoded = jsonDecode(contents);

      setState(() {
        for (var json in decoded) {
          final p = Point<int>(json['x'], json['y']);
          obstacles.add(p);
          //grid[p.x][p.y].walkable = false;
        }
      });

      print('Obstáculos cargados desde: ${file.path}');
    }
  }

  //para trabajar con shared preferences
  // [Future<void> saveObstacles() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final encoded = obstacles.map((p) => '${p.x},${p.y}').toList();
  //   await prefs.setStringList('obstacles', encoded);
  // }]

  // Future<void> loadObstacles() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final encoded = prefs.getStringList('obstacles') ?? [];
  //   setState(() {
  //     for (var e in encoded) {
  //       final parts = e.split(',');
  //       final p = Point(int.parse(parts[0]), int.parse(parts[1]));
  //       obstacles.add(p);
  //       grid[p.x][p.y].walkable = false;

  //     }
  //   });
  // }

  //para cargar POIS desde archivo JSON
  Future<void> loadPOIsFromJson() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/pois.json');
      final List<dynamic> jsonList = json.decode(jsonString);

      final List<POI> loadedPOIs = [];
      for (final jsonItem in jsonList) {
        try {
          final poi = POI.fromJson(jsonItem);
          // Validate POI before adding
          if (_validatePOIData(poi)) {
            loadedPOIs.add(poi);
          } else {
            debugPrint('Skipping invalid POI: ${jsonItem}');
          }
        } catch (e) {
          debugPrint('Error parsing POI from JSON: $e, data: $jsonItem');
        }
      }

      if (mounted) {
        setState(() {
          pointsOfInterest = loadedPOIs;
        });
      }
      debugPrint('Successfully loaded ${pointsOfInterest.length} valid POIs out of ${jsonList.length} total');
    } catch (e) {
      debugPrint('Error loading POIs from JSON: $e');
      // Set empty list as fallback
      if (mounted) {
        setState(() {
          pointsOfInterest = [];
        });
      }
      // Don't rethrow - POIs are optional
    }
  }

  //Para filtrar los POIS cercanos a la ruta calculada
  bool isPOINearRoute(Point<int> poiCell, List<Point<int>> routeCells,
      {int distance = 2}) {
    for (var cell in routeCells) {
      if ((poiCell.x - cell.x).abs() <= distance &&
          (poiCell.y - cell.y).abs() <= distance) {
        return true;
      }
    }
    return false;
  }

  //para seguir la orientacion tipo brijula - Optimized with throttling
  Timer? _compassUpdateTimer;
  void _startCompassTracking() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50), // Reduced frequency
    ).listen((AccelerometerEvent event) {
      _accelData = event;
      _throttledUpdateDeviceAngle();
    });

    _magSub = magnetometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50), // Reduced frequency
    ).listen((MagnetometerEvent event) {
      _magData = event;
      _throttledUpdateDeviceAngle();
    });
  }
  
  void _throttledUpdateDeviceAngle() {
    // Throttle compass updates to avoid excessive setState calls
    if (_compassUpdateTimer?.isActive == true) return;
    
    _compassUpdateTimer = Timer(const Duration(milliseconds: 100), () {
      _updateDeviceAngle();
    });
  }
  
  /// Get visible obstacles using simple bounds checking
  List<Point<int>> _getVisibleObstacles() {
    try {
      final visibleBounds = _getVisibleBounds();
      return obstacles.where((obstacle) {
        final latlng = gridToLatLng(Node(row: obstacle.x, col: obstacle.y));
        return _isPointVisible(latlng, visibleBounds);
      }).toList();
    } catch (e) {
      // Fallback to all obstacles if viewport culling fails
      return obstacles.toList();
    }
  }
  
  /// Get visible POIs using simple bounds checking
  List<POI> _getVisiblePOIs() {
    try {
      final visibleBounds = _getVisibleBounds();
      return visiblePOIs.where((poi) {
        final latlng = gridToLatLng(Node(row: poi.cell.x, col: poi.cell.y));
        return _isPointVisible(latlng, visibleBounds);
      }).toList();
    } catch (e) {
      // Fallback to all visible POIs if viewport culling fails
      return visiblePOIs;
    }
  }

  Widget _buildSafeFlutterMap() {
    // Check if initialization failed
    if (_mapInitializationFailed || !_initContext.hasMinimalRequirements) {
      return _buildInitializationErrorUI();
    }
    
    try {
      return FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: LatLng(
            (startBounds.latitude + endBounds.latitude) / 2,
            (startBounds.longitude + endBounds.longitude) / 2,
          ),
          initialZoom: 18,
          minZoom: 15,
          maxZoom: 22,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
          onTap: (tapPosition, latlng) {
            try {
              debugPrint('=== MAP TAP EVENT ===');
              debugPrint('Tap position: $latlng');
              debugPrint('Selecting start: $selectingStart');
              debugPrint('Current start point: $startPoint');
              debugPrint('Current goal point: $goalPoint');
              
              if (selectingStart) {
                setState(() {
                  startPoint = latlng;
                  selectingStart = false;
                  _currentPosition = latlng;
                  // Clear previous path when setting new start
                  path = [];
                });
                debugPrint('✓ Start point set to: $startPoint');
                if (_initContext.sensorsAvailable) {
                  _startCompassTracking();
                }
              } else {
                setState(() {
                  goalPoint = latlng;
                  selectingStart = true;
                  // Clear previous path when setting new goal
                  path = [];
                });
                debugPrint('Goal point set to: $goalPoint');
                
                // Calculate path if both points are set
                if (startPoint != null) {
                  debugPrint('Both points set, initiating path calculation...');
                  // Calculate path immediately after setState completes
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    calculatePath();
                  });
                } else {
                  debugPrint('Start point is null, cannot calculate path');
                }
              }
            } catch (e) {
              debugPrint('Error handling map tap: $e');
            }
          },
          onLongPress: (tapPosition, latlng) {
            try {
              toggleObstacle(latlng);
            } catch (e) {
              debugPrint('Error handling long press: $e');
            }
          },
        ),
        children: [
          // Image overlay - with fallback handling (BASE LAYER)
          if (_shouldShowMapImage())
            OverlayImageLayer(
              overlayImages: [
                OverlayImage(
                  bounds: LatLngBounds(startBounds, endBounds),
                  opacity: 1.0,
                  imageProvider: const AssetImage('assets/planta1.jpg'),
                  gaplessPlayback: true,
                ),
              ],
            ),

          // Polygons - cell highlights (BACKGROUND ELEMENTS)
          if (_initContext.gridInitialized)
            RepaintBoundary(
              child: PolygonLayer(
                polygons: _buildSafePolygons(),
              ),
            ),

          // Grid lines and Route polylines (NAVIGATION LAYER)
          RepaintBoundary(
            child: PolylineLayer(
              polylineCulling: true,
              polylines: _buildSafePolylines(),
            ),
          ),

          // Obstacle markers (OBSTACLE LAYER)
          if (_initContext.obstaclesLoaded)
            RepaintBoundary(
              child: MarkerLayer(
                markers: _getVisibleObstacles().map((point) {
                  final latlng = gridToLatLng(Node(row: point.x, col: point.y));
                  return Marker(
                    width: 6,
                    height: 6,
                    point: latlng,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // POI markers (INFORMATION LAYER)
          if (_initContext.poisLoaded)
            RepaintBoundary(
              child: MarkerLayer(
                markers: _getVisiblePOIs().map((poi) {
                  try {
                    final node = grid[poi.cell.x][poi.cell.y];
                    final latlng = gridToLatLng(node);
                    return Marker(
                      point: latlng,
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () {
                          _showPOIDialog(poi);
                        },
                        child: RepaintBoundary(
                          child: _initContext.animationsEnabled
                              ? const Icon(Icons.info, color: Colors.deepPurpleAccent, size: 28) // OptimizedAnimatedPOIIcon()
                              : const Icon(Icons.info, color: Colors.deepPurpleAccent, size: 28),
                        ),
                      ),
                    );
                  } catch (e) {
                    debugPrint('Error creating POI marker for ${poi.name}: $e');
                    // Return empty marker as fallback
                    return Marker(
                      point: const LatLng(0, 0),
                      width: 0,
                      height: 0,
                      child: const SizedBox.shrink(),
                    );
                  }
                }).where((marker) => marker.width > 0).toList(),
              ),
            ),

          // Navigation markers - START/GOAL/CURRENT POSITION (TOP LAYER)
          RepaintBoundary(
            child: MarkerLayer(
              markers: _buildSafeMarkers(),
            ),
          ),
        ],
      );
    } catch (e) {
      debugPrint('Error building FlutterMap: $e');
      _initContext.addError('FlutterMap build failed: $e');
      return _buildMapErrorUI(e.toString());
    }
  }
  
  Widget _buildInitializationErrorUI() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning, size: 72, color: Colors.orange),
              SizedBox(height: 24),
              Text(
                'Map Initialization Failed',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(_initContext.statusSummary),
                    if (_initContext.errors.isNotEmpty) ...[
                      SizedBox(height: 12),
                      Text(
                        'Recent Errors:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      SizedBox(height: 4),
                      ...(_initContext.errors.take(3).map((error) => 
                        Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(
                            error,
                            style: TextStyle(fontSize: 12, color: Colors.red[700]),
                          ),
                        )
                      )),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _retryInitialization,
                    icon: Icon(Icons.refresh),
                    label: Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _showDiagnosticInfo,
                    icon: Icon(Icons.info_outline),
                    label: Text('Details'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildMapErrorUI(String error) {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              'Map Rendering Failed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Technical Issue: $error',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _retryInitialization,
              child: Text('Restart App'),
            ),
          ],
        ),
      ),
    );
  }

  void _updateDeviceAngle() {
    if (_accelData == null || _magData == null) return;

    final ax = _accelData!.x;
    final ay = _accelData!.y;
    final az = _accelData!.z;

    final mx = _magData!.x;
    final my = _magData!.y;
    final mz = _magData!.z;

    final normA = math.sqrt(ax * ax + ay * ay + az * az);
    final normM = math.sqrt(mx * mx + my * my + mz * mz);

    if (normA == 0 || normM == 0) return;

    final axn = ax / normA;
    final ayn = ay / normA;
    final azn = az / normA;

    final mxn = mx / normM;
    final myn = my / normM;
    final mzn = mz / normM;

    final hx = myn * azn - mzn * ayn;
    final hy = mzn * axn - mxn * azn;
    final hz = mxn * ayn - myn * axn;

    final normH = math.sqrt(hx * hx + hy * hy + hz * hz);
    if (normH == 0.0) return;

    final hxNorm = hx / normH;
    final hyNorm = hy / normH;

    final angle = math.atan2(hyNorm, hxNorm); // ángulo en radianes

    setState(() {
      _deviceAngle = angle;
    });
  }
  
  // Helper methods for safe UI building
  bool _shouldShowMapImage() {
    try {
      // Check if the map overlay should be shown
      // Ensure grid is initialized before showing overlay
      return _initContext.gridInitialized;
    } catch (e) {
      debugPrint('Error checking map image availability: $e');
      return false;
    }
  }
  
  List<Marker> _buildSafeMarkers() {
    try {
      List<Marker> markers = [];
      
      if (startPoint != null) {
        markers.add(Marker(
          point: startPoint!,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.green, size: 50),
        ));
      }
      
      if (goalPoint != null) {
        markers.add(Marker(
          point: goalPoint!,
          width: 40,
          height: 40,
          child: const Icon(Icons.flag, color: Colors.red, size: 50),
        ));
      }
      
      // Add arrow path trail markers (if enabled) - DISABLED
      /*
      if (_arrowPath.isNotEmpty && _globalSensorManager?.isRunning == true) {
        for (int i = 0; i < _arrowPath.length - 1; i++) {
          final arrowState = _arrowPath[i];
          if (arrowState.isVisible) {
            markers.add(Marker(
              point: arrowState.position,
              width: 20,
              height: 20,
              child: RepaintBoundary(
                child: Opacity(
                  opacity: 0.4, // Trail markers are more transparent
                  child: Transform.rotate(
                    angle: arrowState.normalizedRotation * pi / 180,
                    child: Icon(
                      Icons.navigation,
                      color: Colors.blueGrey,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ));
          }
        }
      }
      */
      
      // Add current arrow marker (main position indicator) - DISABLED
      /*
      if (_currentArrowState != null && _currentArrowState!.isVisible) {
        markers.add(Marker(
          point: _currentArrowState!.position,
          width: _currentArrowState!.size,
          height: _currentArrowState!.size,
          child: RepaintBoundary(
            child: AnimatedOpacity(
              opacity: _currentArrowState!.opacity,
              duration: const Duration(milliseconds: 300),
              child: AnimatedScale(
                scale: _currentArrowState!.scale,
                duration: const Duration(milliseconds: 200),
                child: Transform.rotate(
                  angle: _currentArrowState!.normalizedRotation * pi / 180,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.navigation,
                      color: Colors.blue,
                      size: _currentArrowState!.size * 0.8,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ));
      }
      */
      
      // Legacy current position marker (fallback when no arrow state)
      if (_currentPosition != null && _initContext.sensorsAvailable) {
        markers.add(Marker(
          point: _currentPosition!,
          width: 60,
          height: 60,
          child: RepaintBoundary(
            child: Transform.rotate(
              angle: -_deviceAngle,
              child: const Icon(
                Icons.navigation,
                color: Colors.blue,
                size: 48,
              ),
            ),
          ),
        ));
      }
      
      return markers;
    } catch (e) {
      debugPrint('Error building markers: $e');
      return [];
    }
  }
  
  List<Polygon> _buildSafePolygons() {
    try {
      List<Polygon> polygons = [];
      
      if (startPoint != null) {
        polygons.add(Polygon(
          points: getCellPolygon(
            latLngToGrid(startPoint!).x,
            latLngToGrid(startPoint!).y,
          ),
          borderColor: Colors.green,
          borderStrokeWidth: 2,
          color: Colors.green.withOpacity(0.3),
        ));
      }
      
      if (goalPoint != null) {
        polygons.add(Polygon(
          points: getCellPolygon(
            latLngToGrid(goalPoint!).x,
            latLngToGrid(goalPoint!).y,
          ),
          borderColor: Colors.red,
          borderStrokeWidth: 2,
          color: Colors.red.withOpacity(0.3),
        ));
      }
      
      return polygons;
    } catch (e) {
      debugPrint('Error building polygons: $e');
      return [];
    }
  }
  
  List<Polyline> _buildSafePolylines() {
    try {
      List<Polyline> polylines = [];
      
      debugPrint('=== BUILDING POLYLINES ===');
      debugPrint('Path length: ${path.length}');
      debugPrint('Grid initialized: ${_initContext.gridInitialized}');
      
      // PRIORITY 1: ROUTE POLYLINES (HIGHEST PRIORITY)
      if (path.isNotEmpty && path.length >= 2) {
        debugPrint('=== ADDING ROUTE POLYLINES ===');
        debugPrint('Route points: ${path.length}');
        debugPrint('Route starts at: ${path.first}');
        debugPrint('Route ends at: ${path.last}');
        
        // Create white border first (renders underneath)
        final routeBorder = Polyline(
          points: path,
          color: Colors.white,
          strokeWidth: 10.0, // Wider border for maximum visibility
          isDotted: false,
          useStrokeWidthInMeter: false,
        );
        polylines.add(routeBorder);
        
        // Create main blue route on top
        final routePolyline = Polyline(
          points: path,
          color: Colors.blue.shade700, // Darker blue for better contrast
          strokeWidth: 6.0,
          isDotted: false,
          useStrokeWidthInMeter: false,
        );
        polylines.add(routePolyline);
        
        debugPrint('✓ Route polylines added: border + main route');
        debugPrint('✓ Route color: Blue (${Colors.blue.shade700})');
        debugPrint('✓ Route width: 6.0px with 10.0px white border');
        
      } else {
        if (path.isEmpty) {
          debugPrint('⚠️ WARNING: Path is empty - no route to display');
        } else {
          debugPrint('⚠️ WARNING: Path has only ${path.length} point(s) - need at least 2 for polyline');
        }
      }
      
      // PRIORITY 2: GRID LINES (BACKGROUND)
      if (_initContext.gridInitialized) {
        final gridLines = buildOptimizedGridLines();
        polylines.addAll(gridLines);
        debugPrint('Added ${gridLines.length} grid lines (background)');
      }
      
      debugPrint('=== POLYLINES BUILD COMPLETE ===');
      debugPrint('Total polylines: ${polylines.length}');
      debugPrint('Route polylines: ${path.isNotEmpty && path.length >= 2 ? 2 : 0} (border + main)');
      
      return polylines;
    } catch (e, stackTrace) {
      debugPrint('=== ERROR BUILDING POLYLINES ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Fallback: return at least grid lines
      try {
        if (_initContext.gridInitialized) {
          final fallbackGridLines = buildOptimizedGridLines();
          debugPrint('Fallback: returning ${fallbackGridLines.length} grid lines only');
          return fallbackGridLines;
        }
      } catch (gridError) {
        debugPrint('Fallback grid lines also failed: $gridError');
      }
      
      debugPrint('Returning empty polylines list as final fallback');
      return [];
    }
  }
  
  void _showPOIDialog(POI poi) {
    try {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(poi.name),
          content: Text(poi.description),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error showing POI dialog: $e');
    }
  }
  
  void _retryInitialization() {
    try {
      _initContext.retryCount++;
      _initializeMapComponents();
    } catch (e) {
      debugPrint('Error retrying initialization: $e');
    }
  }
  
  void _showDiagnosticInfo() {
    try {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Diagnostic Information'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Initialization Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Grid: ${_initContext.gridInitialized ? "✓" : "✗"}'),
                Text('Sensors: ${_initContext.sensorsAvailable ? "✓" : "✗"}'),
                Text('Animations: ${_initContext.animationsEnabled ? "✓" : "✗"}'),
                Text('POIs: ${_initContext.poisLoaded ? "✓" : "✗"}'),
                Text('Obstacles: ${_initContext.obstaclesLoaded ? "✓" : "✗"}'),
                SizedBox(height: 16),
                Text('Retry Count: ${_initContext.retryCount}'),
                if (_initContext.lastAttempt != null)
                  Text('Last Attempt: ${_initContext.lastAttempt}'),
                SizedBox(height: 16),
                if (_initContext.errors.isNotEmpty) ...[
                  Text('Error Log:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  ...(_initContext.errors.map((error) => 
                    Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        error,
                        style: TextStyle(fontSize: 10),
                      ),
                    )
                  )),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error showing diagnostic info: $e');
    }
  }
  


}

// Shared animation controller for all POI icons to optimize performance
class OptimizedAnimatedPOIIcon extends StatelessWidget {
  // Use static shared controller to avoid creating multiple animation controllers
  static AnimationController? _sharedController;
  static Animation<double>? _scaleAnimation;
  static bool _isInitialized = false;
  
  static void initSharedController(TickerProvider vsync) {
    if (_isInitialized && _sharedController != null) return;
    
    try {
      _sharedController?.dispose(); // Dispose previous controller if any
      _sharedController = AnimationController(
        vsync: vsync,
        duration: const Duration(seconds: 2),
      );
      
      _scaleAnimation = Tween(begin: 1.0, end: 1.2).animate(CurvedAnimation(
        parent: _sharedController!,
        curve: Curves.easeInOut,
      ));
      
      _sharedController!.repeat(reverse: true);
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing shared controller: $e');
      _sharedController = null;
      _scaleAnimation = null;
      _isInitialized = false;
    }
  }
  
  static void disposeSharedController() {
    try {
      _sharedController?.dispose();
    } catch (e) {
      debugPrint('Error disposing shared controller: $e');
    } finally {
      _sharedController = null;
      _scaleAnimation = null;
      _isInitialized = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always check initialization state and controller validity
    if (!_isInitialized || _sharedController == null || _scaleAnimation == null) {
      // Fallback to static icon if controller not properly initialized
      return const Icon(Icons.info, color: Colors.deepPurpleAccent, size: 28);
    }
    
    try {
      return AnimatedBuilder(
        animation: _scaleAnimation!,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation!.value,
            child: const Icon(Icons.info, color: Colors.deepPurpleAccent, size: 28),
          );
        },
      );
    } catch (e) {
      debugPrint('Error in OptimizedAnimatedPOIIcon build: $e');
      // Return static icon as fallback
      return const Icon(Icons.info, color: Colors.deepPurpleAccent, size: 28);
    }
  }
}

class AnimatedPOIIcon extends StatefulWidget {
  @override
  _AnimatedPOIIconState createState() => _AnimatedPOIIconState();
}

//para animacion de icono de POI
class _AnimatedPOIIconState extends State<AnimatedPOIIcon>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    try {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 1),
      );
      _controller?.repeat(reverse: true);
    } catch (e) {
      debugPrint('Error initializing AnimationController: $e');
      _controller = null;
    }
  }

  @override
  void dispose() {
    try {
      _controller?.dispose();
    } catch (e) {
      debugPrint('Error disposing AnimationController: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If controller is null, return static icon
    if (_controller == null) {
      return const Icon(Icons.info, color: Colors.deepPurpleAccent, size: 28);
    }
    
    try {
      return ScaleTransition(
        scale: Tween(begin: 1.0, end: 1.3).animate(CurvedAnimation(
          parent: _controller!,
          curve: Curves.easeInOut,
        )),
        child: const Icon(Icons.info, color: Colors.deepPurpleAccent, size: 28),
      );
    } catch (e) {
      debugPrint('Error in AnimatedPOIIcon build: $e');
      // Return static icon as fallback
      return const Icon(Icons.info, color: Colors.deepPurpleAccent, size: 28);
    }
  }
}
