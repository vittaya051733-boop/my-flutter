import 'package:flutter/material.dart';

/// A widget that lazily builds and displays a stack of widgets.
///
/// This is similar to `IndexedStack`, but it only builds the child widget
/// when it's first displayed. Subsequent visits to the same index will show
/// the already-built widget without rebuilding it, preserving its state.
class LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  // A map to store the built children. The key is the index.
  final Map<int, Widget> _builtChildren = {};

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.index;

    // If the child for the current index hasn't been built yet, build and cache it.
    if (!_builtChildren.containsKey(currentIndex)) {
      _builtChildren[currentIndex] = widget.children[currentIndex];
    }

    // Use a standard IndexedStack to display the children.
    // It will only contain the widgets that have been built so far.
    return IndexedStack(
      index: currentIndex,
      children: widget.children.asMap().entries.map((entry) {
        return _builtChildren[entry.key] ?? Container(); // Return an empty container for non-built children
      }).toList(),
    );
  }
}