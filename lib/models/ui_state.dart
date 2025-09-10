class UIState {
  final bool showGraph;
  final int? selectedWindowIndex;
  final List<int> availableWindows;
  final int selectedTabIndex;

  const UIState({
    this.showGraph = false,
    this.selectedWindowIndex,
    this.availableWindows = const [],
    this.selectedTabIndex = 0,
  });

  UIState copyWith({
    bool? showGraph,
    int? selectedWindowIndex,
    List<int>? availableWindows,
    int? selectedTabIndex,
  }) {
    return UIState(
      showGraph: showGraph ?? this.showGraph,
      selectedWindowIndex: selectedWindowIndex ?? this.selectedWindowIndex,
      availableWindows: availableWindows ?? this.availableWindows,
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
    );
  }
}
