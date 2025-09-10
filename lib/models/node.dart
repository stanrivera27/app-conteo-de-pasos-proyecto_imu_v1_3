import 'dart:math';

enum NodeType { empty, obstacle, start, goal, path }

class Node {
  final int row;
  final int col;
  NodeType type;

  double g;
  double rhs;
  Node? parent;

  Node({
    required this.row,
    required this.col,
    this.type = NodeType.empty,
  })  : g = double.infinity,
        rhs = double.infinity;

  bool get walkable => type != NodeType.obstacle;

  set walkable(bool value) {
    type = value ? NodeType.empty : NodeType.obstacle;
  }

  Point<int> get position => Point(row, col);
}
