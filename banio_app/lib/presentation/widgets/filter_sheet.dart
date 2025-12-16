// lib/presentation/widgets/filter_sheet.dart
import 'package:flutter/material.dart';
import 'dart:async';

class FilterOptions {
  bool free;
  bool accessible;

  FilterOptions({required this.free, required this.accessible});

  FilterOptions copy() => FilterOptions(free: free, accessible: accessible);
}

Future<FilterOptions?> openFilterSheet(
  BuildContext context, {
  required FilterOptions initial,
}) async {
  final opts = initial.copy();
  return showModalBottomSheet<FilterOptions>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: StatefulBuilder(
          builder: (ctx, setModal) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Filtros', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Gratis'),
                  value: opts.free,
                  onChanged: (v) => setModal(() => opts.free = v),
                ),
                SwitchListTile(
                  title: const Text('Accesible'),
                  value: opts.accessible,
                  onChanged: (v) => setModal(() => opts.accessible = v),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Aplicar'),
                    onPressed: () => Navigator.pop(context, opts),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
