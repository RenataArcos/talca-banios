import 'package:flutter/material.dart';

class MapFilterChips extends StatelessWidget {
  const MapFilterChips({
    super.key,
    required this.free,
    required this.onFree,
    required this.accessible,
    required this.onAccessible,
  });

  final bool free;
  final ValueChanged<bool> onFree;
  final bool accessible;
  final ValueChanged<bool> onAccessible;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        FilterChip(
          label: const Text('Gratis'),
          selected: free,
          onSelected: onFree,
          backgroundColor: Colors.white.withOpacity(0.9),
          selectedColor: Colors.blue.withOpacity(0.8),
        ),
        FilterChip(
          label: const Text('Accesible'),
          selected: accessible,
          onSelected: onAccessible,
          backgroundColor: Colors.white.withOpacity(0.9),
          selectedColor: Colors.blue.withOpacity(0.8),
        ),
      ],
    );
  }
}
