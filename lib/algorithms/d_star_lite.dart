import 'package:collection/collection.dart';
import 'dart:math';
import '../models/node.dart';


class DStarLite {
  final List<List<Node>> grid;
  final Node start;
  final Node goal;
  final PriorityQueue<QueueNode> openList;

  DStarLite({ 
    required this.grid,
    required this.start,
    required this.goal,
  }) : openList = PriorityQueue<QueueNode>(
          (a, b) => a.key[0] == b.key[0] ? a.key[1].compareTo(b.key[1]) : a.key[0].compareTo(b.key[0]),
        ) {
    _initialize();
  }

  void _initialize() {
    for (var row in grid) {
      for (var node in row) {
        node.g = double.infinity;
        node.rhs = double.infinity;
        node.parent = null;
      }
    }
    goal.rhs = 0;
    openList.add(QueueNode(goal, _calculateKey(goal)));
  }

  List<double> _calculateKey(Node node) {
    final minCost = min(node.g, node.rhs);
    final heuristic = (start.row - node.row).abs() + (start.col - node.col).abs();
    return [minCost + heuristic, minCost];  
  }

  void _updateVertex(Node u) {
    if (u != goal) {
      final neighbors = _getNeighbors(u);
      u.rhs = neighbors.where((n) => n.walkable).map((n) => n.g + 1).fold<double>(double.infinity, min);
    }

    QueueNode? toRemove;
    for (final element in openList.toList()) {  // Aquí convertimos en lista
      if (element.node == u) {
        toRemove = element;
        break;
      }
    }
    if (toRemove != null) {
      openList.remove(toRemove);
    }

    if (u.g != u.rhs) {
      openList.add(QueueNode(u, _calculateKey(u)));
    }
  }

  List<Node> _getNeighbors(Node node) {
    final directions = [
      [0, 1],
      [1, 0],
      [0, -1],
      [-1, 0]
    ];

    final neighbors = <Node>[];

    for (var dir in directions) {
      final r = node.row + dir[0];
      final c = node.col + dir[1];

      if (r >= 0 && r < grid.length && c >= 0 && c < grid[0].length) {
        neighbors.add(grid[r][c]);
      }
    }
    return neighbors;
  }

  List<Node> computeShortestPath() {
    while (openList.isNotEmpty &&
        (openList.first.key[0] < _calculateKey(start)[0] ||
            start.rhs != start.g)) {
      final u = openList.removeFirst().node;
      if (u.g > u.rhs) {
        u.g = u.rhs;
        for (final neighbor in _getNeighbors(u)) {
          if (neighbor.walkable) {
            neighbor.parent = u;
            _updateVertex(neighbor);
          }
        }
      } else {
        u.g = double.infinity;
        _updateVertex(u);
        for (final neighbor in _getNeighbors(u)) {
          if (neighbor.walkable) {
            _updateVertex(neighbor);
          }
        }
      }
    }

    return _reconstructPath();
  }

 List<Node> _reconstructPath() {
    final path = <Node>[];
    Node? current = start;

    while (current != null && current != goal) {
     final neighbors = _getNeighbors(current).where((n) => n.walkable && n.g != double.infinity).toList();
    
      if(neighbors.isEmpty) break;

      Node next = neighbors.reduce((a,b)=>(a.g < b.g) ? a : b);

      path.add(current);
      current=next;

    } 

    if (current == goal) {
      path.add(goal);
    }

    return path;
  }

}

class QueueNode {
  final Node node;
  final List<double> key;
  QueueNode(this.node, this.key);
}

extension PriorityQueueExtensions<T> on PriorityQueue<T> {
  void removeWhere(bool Function(T element) test) {
    final List<T> toRemove = [];

    for (final element in toList()) {  // Aquí usamos .toList()
      if (test(element)) {
        toRemove.add(element);
      }
    }

    for (final element in toRemove) {
      remove(element);
    }
  }
}

