// lib/presentation/widgets/propose_bathroom_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../../core/utils/auth_service.dart';
import '../../core/utils/locations_utils.dart';
import 'auth_sheet.dart';
import 'location_picker_sheet.dart';

Future<void> openProposeBathroomSheet(
  BuildContext hostContext, {
  required AuthService auth,
  LatLng? me,
  VoidCallback? onSubmitted,
}) async {
  // Gate de autenticación
  if (auth.currentUser == null) {
    await openAuthSheet(hostContext, auth);
    if (auth.currentUser == null) return;
  }

  await showModalBottomSheet(
    context: hostContext,
    isScrollControlled: true,
    builder: (modalCtx) => SafeArea(
      child: _ProposeBathroomForm(
        hostContext: hostContext,
        auth: auth,
        me: me,
        onSubmitted: onSubmitted,
      ),
    ),
  );
}

class _ProposeBathroomForm extends StatefulWidget {
  final BuildContext hostContext;
  final AuthService auth;
  final LatLng? me;
  final VoidCallback? onSubmitted;

  const _ProposeBathroomForm({
    required this.hostContext,
    required this.auth,
    this.me,
    this.onSubmitted,
  });

  @override
  State<_ProposeBathroomForm> createState() => _ProposeBathroomFormState();
}

class _ProposeBathroomFormState extends State<_ProposeBathroomForm> {
  final _name = TextEditingController();
  final _desc = TextEditingController();

  // Dropdowns (se derivan a booleans al enviar)
  String _fee = 'unknown'; // 'unknown' | 'no' | 'yes'  (UI: 'yes' = gratis)
  String _wheelchair = 'unknown'; // 'unknown' | 'no' | 'limited' | 'yes'

  double? _lat, _lon;
  bool _saving = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    if (widget.me != null) {
      _lat = widget.me!.latitude;
      _lon = widget.me!.longitude;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    final ok = await ensureLocationPermissionSmart(
      widget.hostContext,
      interactive: true,
    );
    if (!ok) return;
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: kLocSettings,
    );
    setState(() {
      _lat = pos.latitude;
      _lon = pos.longitude;
    });
  }

  Future<void> _submit() async {
    if (_saving) return;

    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _err = 'El nombre es obligatorio.');
      return;
    }
    if (_lat == null || _lon == null) {
      setState(() => _err = 'Debes establecer una ubicación.');
      return;
    }

    setState(() {
      _saving = true;
      _err = null;
    });

    // UI optimista
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    if (widget.hostContext.mounted) {
      ScaffoldMessenger.of(
        widget.hostContext,
      ).showSnackBar(const SnackBar(content: Text('Enviando propuesta…')));
    }

    // Derivar booleans desde dropdowns:
    final bool isFree = (_fee == 'yes'); // 'yes' en UI = gratis
    final bool wheelchairAccessible =
        (_wheelchair == 'yes' || _wheelchair == 'limited');

    try {
      final uid = widget.auth.currentUser!.uid;
      await FirebaseFirestore.instance.collection('bathroom_proposals').add({
        'name': name,
        'lat': _lat,
        'lon': _lon,
        // SOLO booleans en la propuesta:
        'isFree': isFree,
        'wheelchairAccessible': wheelchairAccessible,
        'description': _desc.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': uid,
        'status': 'pending',
      });

      if (widget.hostContext.mounted) {
        ScaffoldMessenger.of(widget.hostContext).showSnackBar(
          const SnackBar(content: Text('¡Propuesta enviada para revisión!')),
        );
      }
      widget.onSubmitted?.call();
    } catch (e) {
      if (widget.hostContext.mounted) {
        ScaffoldMessenger.of(widget.hostContext).showSnackBar(
          SnackBar(content: Text('No se pudo enviar la propuesta: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Proponer baño',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nombre del lugar (obligatorio)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _desc,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _fee,
                    decoration: const InputDecoration(
                      labelText: '¿Es gratis?',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'unknown',
                        child: Text('Desconocido'),
                      ),
                      DropdownMenuItem(
                        value: 'no',
                        child: Text('No (de pago)'),
                      ),
                      DropdownMenuItem(
                        value: 'yes',
                        child: Text('Sí (gratis)'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _fee = v ?? 'unknown'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _wheelchair,
                    decoration: const InputDecoration(
                      labelText: 'Accesible',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'unknown',
                        child: Text('Desconocido'),
                      ),
                      DropdownMenuItem(value: 'no', child: Text('No')),
                      DropdownMenuItem(
                        value: 'limited',
                        child: Text('Limitado'),
                      ),
                      DropdownMenuItem(value: 'yes', child: Text('Sí')),
                    ],
                    onChanged: (v) =>
                        setState(() => _wheelchair = v ?? 'unknown'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: _saving
                        ? null
                        : () async {
                            final picked = await openLocationPicker(
                              widget.hostContext,
                              init: (_lat != null && _lon != null)
                                  ? LatLng(_lat!, _lon!)
                                  : (widget.me ?? kTalcaCenter),
                              myPos: widget.me,
                            );
                            if (picked != null && mounted) {
                              setState(() {
                                _lat = picked.latitude;
                                _lon = picked.longitude;
                              });
                            }
                          },
                    icon: const Icon(Icons.location_pin),
                    label: const Text(
                      'Ubicar en mapa',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: _saving ? null : _useMyLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text(
                      'Usar mi ubicación',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),

            if (_lat != null && _lon != null) ...[
              const SizedBox(height: 8),
              Text(
                'Ubicación: ${_lat!.toStringAsFixed(6)}, ${_lon!.toStringAsFixed(6)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

            if (_err != null) ...[
              const SizedBox(height: 8),
              Text(_err!, style: const TextStyle(color: Colors.red)),
            ],

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_saving ? 'Enviando…' : 'Enviar propuesta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
