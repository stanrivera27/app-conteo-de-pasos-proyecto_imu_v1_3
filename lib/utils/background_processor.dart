import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/node.dart';
import '../algorithms/d_star_lite.dart';
import 'performance_monitor.dart';

class BackgroundProcessor {
  static BackgroundProcessor? _instance;
  static BackgroundProcessor get instance => _instance ??= BackgroundProcessor._();
  
  BackgroundProcessor._();

  Isolate? _processingIsolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  bool _isInitialized = false;
  
  final Map<String, Completer<dynamic>> _pendingOperations = {};
  int _operationCounter = 0;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      PerformanceMonitor.instance.recordEvent('background_processor_init_start');
      
      _receivePort = ReceivePort();
      
      // Crear isolate para procesamiento en background
      _processingIsolate = await Isolate.spawn(
        _isolateEntryPoint,
        _receivePort!.sendPort,
      );

      // Configurar listener para mensajes del isolate
      _receivePort!.listen(_handleIsolateMessage);
      
      // Esperar confirmación de inicialización
      await _sendCommand('init', null);
      
      _isInitialized = true;
      PerformanceMonitor.instance.recordEvent('background_processor_init_complete');
      
      if (kDebugMode) {
        print('BackgroundProcessor initialized successfully');
      }
    } catch (e) {
      PerformanceMonitor.instance.recordEvent('background_processor_init_error');
      if (kDebugMode) {
        print('Failed to initialize BackgroundProcessor: $e');
      }
      rethrow;
    }
  }

  static void _isolateEntryPoint(SendPort mainSendPort) {
    final isolateReceivePort = ReceivePort();
    mainSendPort.send(isolateReceivePort.sendPort);

    isolateReceivePort.listen((message) {
      _handleIsolateCommand(message, mainSendPort);
    });
  }

  static void _handleIsolateCommand(dynamic message, SendPort mainSendPort) {
    try {
      final Map<String, dynamic> command = Map<String, dynamic>.from(message);
      final String operation = command['operation'];
      final String operationId = command['id'];
      final dynamic data = command['data'];

      dynamic result;

      switch (operation) {
        case 'init':
          result = 'initialized';
          break;
          
        case 'calculatePath':
          result = _calculatePathInIsolate(data);
          break;
          
        case 'processLargeDataset':
          result = _processLargeDatasetInIsolate(data);
          break;
          
        case 'optimizeGrid':
          result = _optimizeGridInIsolate(data);
          break;
          
        default:
          result = {'error': 'Unknown operation: $operation'};
      }

      mainSendPort.send({
        'id': operationId,
        'result': result,
        'success': true,
      });

    } catch (e) {
      mainSendPort.send({
        'id': message['id'],
        'error': e.toString(),
        'success': false,
      });
    }
  }

  static List<Node> _calculatePathInIsolate(Map<String, dynamic> data) {
    try {
      // Reconstruir grid desde datos serializados
      final List<List<Map<String, dynamic>>> gridData = 
          List<List<Map<String, dynamic>>>.from(data['grid']);
      
      final grid = gridData.map((row) =>
        row.map((nodeData) => Node(
          row: nodeData['row'],
          col: nodeData['col'],
        )).toList()
      ).toList();

      final startX = data['startX'] as int;
      final startY = data['startY'] as int;
      final goalX = data['goalX'] as int;
      final goalY = data['goalY'] as int;

      if (kDebugMode) {
        print('ISOLATE: Grid size: ${grid.length}x${grid.isNotEmpty ? grid[0].length : 0}');
        print('ISOLATE: Start: ($startX, $startY), Goal: ($goalX, $goalY)');
      }

      // Configurar obstáculos
      final obstacles = List<List<bool>>.from(data['obstacles']);
      for (int i = 0; i < grid.length; i++) {
        for (int j = 0; j < grid[i].length; j++) {
          if (i < obstacles.length && j < obstacles[i].length) {
            grid[i][j].walkable = !obstacles[i][j];
          }
        }
      }

      // Validate start and goal are within bounds and walkable
      if (startX < 0 || startX >= grid.length || startY < 0 || startY >= grid[0].length) {
        if (kDebugMode) {
          print('ISOLATE ERROR: Start point out of bounds');
        }
        return [];
      }
      
      if (goalX < 0 || goalX >= grid.length || goalY < 0 || goalY >= grid[0].length) {
        if (kDebugMode) {
          print('ISOLATE ERROR: Goal point out of bounds');
        }
        return [];
      }

      if (!grid[startX][startY].walkable) {
        if (kDebugMode) {
          print('ISOLATE ERROR: Start point is not walkable');
        }
        return [];
      }

      if (!grid[goalX][goalY].walkable) {
        if (kDebugMode) {
          print('ISOLATE ERROR: Goal point is not walkable');
        }
        return [];
      }

      // Ejecutar D* Lite
      final dStarLite = DStarLite(
        grid: grid,
        start: grid[startX][startY],
        goal: grid[goalX][goalY],
      );
      
      final path = dStarLite.computeShortestPath();
      
      if (kDebugMode) {
        print('ISOLATE: Path computation result: ${path?.length ?? 0} nodes');
      }

      return path ?? [];
    } catch (e) {
      if (kDebugMode) {
        print('ISOLATE ERROR: Error calculating path in isolate: $e');
      }
      return [];
    }
  }

  static Map<String, dynamic> _processLargeDatasetInIsolate(Map<String, dynamic> data) {
    try {
      final List<double> dataset = List<double>.from(data['dataset']);
      final String operation = data['operation'];

      switch (operation) {
        case 'statistics':
          return _calculateStatistics(dataset);
        case 'filter':
          return _filterDataset(dataset, data['threshold']);
        case 'smooth':
          return _smoothDataset(dataset, data['windowSize']);
        default:
          return {'error': 'Unknown dataset operation'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Map<String, dynamic> _calculateStatistics(List<double> data) {
    if (data.isEmpty) return {'error': 'Empty dataset'};

    final sorted = [...data]..sort();
    final sum = data.reduce((a, b) => a + b);
    final mean = sum / data.length;
    
    final variance = data.map((x) => (x - mean) * (x - mean))
        .reduce((a, b) => a + b) / data.length;
    
    return {
      'mean': mean,
      'median': sorted[sorted.length ~/ 2],
      'min': sorted.first,
      'max': sorted.last,
      'variance': variance,
      'stdDev': sqrt(variance),
      'count': data.length,
    };
  }

  static Map<String, dynamic> _filterDataset(List<double> data, double threshold) {
    final filtered = data.where((x) => x.abs() >= threshold).toList();
    return {
      'filtered': filtered,
      'originalCount': data.length,
      'filteredCount': filtered.length,
    };
  }

  static Map<String, dynamic> _smoothDataset(List<double> data, int windowSize) {
    if (data.length < windowSize) return {'smoothed': data};

    final smoothed = <double>[];
    
    for (int i = 0; i < data.length; i++) {
      final start = (i - windowSize ~/ 2).clamp(0, data.length);
      final end = (i + windowSize ~/ 2 + 1).clamp(0, data.length);
      
      final window = data.sublist(start, end);
      final average = window.reduce((a, b) => a + b) / window.length;
      smoothed.add(average);
    }

    return {'smoothed': smoothed};
  }

  static Map<String, dynamic> _optimizeGridInIsolate(Map<String, dynamic> data) {
    try {
      final List<List<bool>> obstacles = 
          List<List<bool>>.from(data['obstacles']);
      
      final int rows = obstacles.length;
      final int cols = obstacles.isNotEmpty ? obstacles[0].length : 0;

      // Optimizaciones de grid
      final clusters = _findObstacleClusters(obstacles);
      final corridors = _findCorridors(obstacles);
      final chokePoints = _findChokePoints(obstacles);

      return {
        'clusters': clusters,
        'corridors': corridors,
        'chokePoints': chokePoints,
        'rows': rows,
        'cols': cols,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static List<Map<String, dynamic>> _findObstacleClusters(List<List<bool>> obstacles) {
    // Implementación básica de clustering de obstáculos
    final visited = List.generate(
      obstacles.length, 
      (_) => List.filled(obstacles[0].length, false)
    );
    
    final clusters = <Map<String, dynamic>>[];
    
    for (int i = 0; i < obstacles.length; i++) {
      for (int j = 0; j < obstacles[i].length; j++) {
        if (obstacles[i][j] && !visited[i][j]) {
          final cluster = _exploreCluster(obstacles, visited, i, j);
          if (cluster['size'] > 1) {
            clusters.add(cluster);
          }
        }
      }
    }
    
    return clusters;
  }

  static Map<String, dynamic> _exploreCluster(
    List<List<bool>> obstacles, 
    List<List<bool>> visited, 
    int startX, 
    int startY
  ) {
    final stack = <List<int>>[[startX, startY]];
    final clusterPoints = <List<int>>[];
    int minX = startX, maxX = startX, minY = startY, maxY = startY;

    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      final x = current[0];
      final y = current[1];

      if (x < 0 || x >= obstacles.length || 
          y < 0 || y >= obstacles[0].length || 
          visited[x][y] || !obstacles[x][y]) {
        continue;
      }

      visited[x][y] = true;
      clusterPoints.add([x, y]);
      
      minX = minX < x ? minX : x;
      maxX = maxX > x ? maxX : x;
      minY = minY < y ? minY : y;
      maxY = maxY > y ? maxY : y;

      // Explorar vecinos (4-conectividad)
      stack.addAll([
        [x + 1, y], [x - 1, y],
        [x, y + 1], [x, y - 1]
      ]);
    }

    return {
      'points': clusterPoints,
      'size': clusterPoints.length,
      'bounds': {'minX': minX, 'maxX': maxX, 'minY': minY, 'maxY': maxY},
    };
  }

  static List<Map<String, dynamic>> _findCorridors(List<List<bool>> obstacles) {
    // Implementación simplificada de detección de corredores
    final corridors = <Map<String, dynamic>>[];
    
    for (int i = 1; i < obstacles.length - 1; i++) {
      for (int j = 1; j < obstacles[i].length - 1; j++) {
        if (!obstacles[i][j]) {
          // Verificar si es un corredor horizontal o vertical
          final isHorizontalCorridor = obstacles[i-1][j] && obstacles[i+1][j] && 
                                      !obstacles[i][j-1] && !obstacles[i][j+1];
          final isVerticalCorridor = obstacles[i][j-1] && obstacles[i][j+1] && 
                                    !obstacles[i-1][j] && !obstacles[i+1][j];
          
          if (isHorizontalCorridor || isVerticalCorridor) {
            corridors.add({
              'x': i,
              'y': j,
              'type': isHorizontalCorridor ? 'horizontal' : 'vertical'
            });
          }
        }
      }
    }
    
    return corridors;
  }

  static List<Map<String, int>> _findChokePoints(List<List<bool>> obstacles) {
    // Implementación básica de detección de puntos críticos
    final chokePoints = <Map<String, int>>[];
    
    for (int i = 1; i < obstacles.length - 1; i++) {
      for (int j = 1; j < obstacles[i].length - 1; j++) {
        if (!obstacles[i][j]) {
          int freeNeighbors = 0;
          final neighbors = [
            [i-1, j], [i+1, j], [i, j-1], [i, j+1]
          ];
          
          for (final neighbor in neighbors) {
            if (!obstacles[neighbor[0]][neighbor[1]]) {
              freeNeighbors++;
            }
          }
          
          // Un punto crítico tiene pocos vecinos libres
          if (freeNeighbors <= 2) {
            chokePoints.add({'x': i, 'y': j});
          }
        }
      }
    }
    
    return chokePoints;
  }

  void _handleIsolateMessage(dynamic message) {
    final Map<String, dynamic> response = Map<String, dynamic>.from(message);
    
    if (response.containsKey('id')) {
      final operationId = response['id'] as String;
      final completer = _pendingOperations.remove(operationId);
      
      if (completer != null) {
        if (response['success'] == true) {
          completer.complete(response['result']);
        } else {
          completer.completeError(response['error'] ?? 'Unknown error');
        }
      }
    } else if (message is SendPort) {
      _sendPort = message;
    }
  }

  Future<T> _sendCommand<T>(String operation, dynamic data) async {
    if (!_isInitialized && operation != 'init') {
      throw StateError('BackgroundProcessor not initialized');
    }

    final operationId = 'op_${_operationCounter++}';
    final completer = Completer<T>();
    _pendingOperations[operationId] = completer;

    _sendPort?.send({
      'operation': operation,
      'id': operationId,
      'data': data,
    });

    return completer.future;
  }

  // API pública
  Future<List<Node>> calculatePath({
    required List<List<Node>> grid,
    required int startX,
    required int startY,
    required int goalX,
    required int goalY,
  }) async {
    PerformanceMonitor.instance.recordEvent('background_path_calculation_start');
    
    try {
      // Serializar grid para el isolate
      final gridData = grid.map((row) =>
        row.map((node) => {
          'row': node.row,
          'col': node.col,
        }).toList()
      ).toList();

      // Crear matriz de obstáculos
      final obstacles = grid.map((row) =>
        row.map((node) => !node.walkable).toList()
      ).toList();

      final result = await _sendCommand<List<dynamic>>('calculatePath', {
        'grid': gridData,
        'obstacles': obstacles,
        'startX': startX,
        'startY': startY,
        'goalX': goalX,
        'goalY': goalY,
      });

      PerformanceMonitor.instance.recordEvent('background_path_calculation_complete');
      
      // Convert result back to Node objects with proper validation
      final convertedPath = <Node>[];
      for (final nodeData in result) {
        try {
          if (nodeData is Map && nodeData.containsKey('row') && nodeData.containsKey('col')) {
            convertedPath.add(Node(
              row: nodeData['row'] as int,
              col: nodeData['col'] as int,
            ));
          } else {
            // Handle case where nodeData is already a Node object
            if (nodeData is Node) {
              convertedPath.add(nodeData);
            } else {
              if (kDebugMode) {
                print('WARNING: Invalid node data format: $nodeData');
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('ERROR: Failed to convert node data: $nodeData, error: $e');
          }
        }
      }
      
      if (kDebugMode) {
        print('Background processor: Successfully converted ${convertedPath.length} nodes');
      }
      
      return convertedPath;
      
    } catch (e) {
      PerformanceMonitor.instance.recordEvent('background_path_calculation_error');
      if (kDebugMode) {
        print('Background path calculation failed: $e');
      }
      return [];
    }
  }

  Future<Map<String, dynamic>> processDataset({
    required List<double> dataset,
    required String operation,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final data = {
        'dataset': dataset,
        'operation': operation,
        ...?parameters,
      };

      return await _sendCommand<Map<String, dynamic>>('processLargeDataset', data);
    } catch (e) {
      if (kDebugMode) {
        print('Dataset processing failed: $e');
      }
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> optimizeGrid(List<List<bool>> obstacles) async {
    try {
      return await _sendCommand<Map<String, dynamic>>('optimizeGrid', {
        'obstacles': obstacles,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Grid optimization failed: $e');
      }
      return {'error': e.toString()};
    }
  }

  void dispose() {
    _pendingOperations.clear();
    _processingIsolate?.kill();
    _receivePort?.close();
    _isInitialized = false;
    
    PerformanceMonitor.instance.recordEvent('background_processor_disposed');
  }
}