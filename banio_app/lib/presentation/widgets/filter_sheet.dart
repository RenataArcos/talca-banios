// lib/presentation/widgets/filter_sheet.dart
import 'package:flutter/material.dart';

class FilterOptions {
  bool free;
  bool accessible;

  FilterOptions({required this.free, required this.accessible});

  FilterOptions copy() => FilterOptions(free: free, accessible: accessible);
}

Future<FilterOptions?> openFilterSheet(
  BuildContext context, {
  required FilterOptions initial,
}) {
  return showModalBottomSheet<FilterOptions>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SafeArea(child: _FilterContent(initial: initial)),
  );
}

class _FilterContent extends StatefulWidget {
  const _FilterContent({required this.initial});
  final FilterOptions initial;

  @override
  State<_FilterContent> createState() => _FilterContentState();
}

class _FilterContentState extends State<_FilterContent> {
  late FilterOptions _opts;

  @override
  void initState() {
    super.initState();
    _opts = widget.initial.copy();
  }

  void _selectAll() {
    setState(() {
      _opts.free = true;
      _opts.accessible = true;
    });
  }

  void _clearAll() {
    setState(() {
      _opts.free = false;
      _opts.accessible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header con acciones rápidas
          Row(
            children: [
              Text('Filtros', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: _selectAll,
                child: const Text('Seleccionar todo'),
              ),
              TextButton(
                onPressed: _clearAll,
                child: const Text('Deseleccionar'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          SwitchListTile(
            value: _opts.free,
            onChanged: (v) => setState(() => _opts.free = v),
            title: const Text('Gratis'),
            subtitle: const Text('Mostrar solo baños sin cobro'),
          ),
          SwitchListTile(
            value: _opts.accessible,
            onChanged: (v) => setState(() => _opts.accessible = v),
            title: const Text('Accesibles'),
            subtitle: const Text('Con accesibilidad para silla de ruedas'),
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, _opts),
                  icon: const Icon(Icons.check),
                  label: const Text('Aplicar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
