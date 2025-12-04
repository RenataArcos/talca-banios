// lib/presentation/widgets/propose_bathroom_sheet.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  // Gate de auth
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

  String _fee = 'unknown';
  String _wheelchair = 'unknown';

  double? _lat, _lon;
  bool _saving = false;

  final List<XFile> _images = [];
  final _picker = ImagePicker();

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

  Future<void> _pickImages() async {
    try {
      final files = await _picker.pickMultiImage(
        imageQuality: 75, // comprime un poco
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (files != null && files.isNotEmpty) {
        setState(() => _images.addAll(files));
      }
    } catch (_) {
      // silencio
    }
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

    // Cierra ya el sheet (UI optimista) y muestra progreso
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    if (widget.hostContext.mounted) {
      ScaffoldMessenger.of(
        widget.hostContext,
      ).showSnackBar(const SnackBar(content: Text('Enviando propuesta…')));
    }

    // Trabajo en background
    Future.microtask(() async {
      try {
        final uid = widget.auth.currentUser!.uid;
        final col = FirebaseFirestore.instance.collection('bathroom_proposals');

        // 1) Crea doc sin fotos
        final doc = await col.add({
          'name': name,
          'lat': _lat,
          'lon': _lon,
          'fee': _fee, // yes/no/unknown
          'wheelchair': _wheelchair, // yes/no/limited/unknown
          'description': _desc.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': uid,
          'status': 'pending',
          'photos': <String>[],
        });

        // 2) Sube fotos (si hay) a: user_uploads/{uid}/proposals/{docId}/...
        if (_images.isNotEmpty) {
          final storage = FirebaseStorage.instance;
          final urls = <String>[];
          for (int i = 0; i < _images.length; i++) {
            final f = _images[i];
            final bytes = await f.readAsBytes();
            final ref = storage.ref().child(
              'user_uploads/$uid/proposals/${doc.id}/${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
            );
            await ref.putData(
              bytes,
              SettableMetadata(contentType: 'image/jpeg'),
            );
            final url = await ref.getDownloadURL();
            urls.add(url);
          }
          await doc.update({'photos': urls});
        }

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
    });
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
                OutlinedButton.icon(
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
                  label: const Text('Ubicar en mapa'),
                ),
                const SizedBox(width: 8),
              ],
            ),

            const SizedBox(height: 10),

            // Fotos
            Row(
              children: [
                Expanded(child: Text('Fotos: ${_images.length} seleccionadas')),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickImages,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Añadir fotos'),
                ),
              ],
            ),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 6),
              SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_images[i].path),
                      fit: BoxFit.cover,
                      width: 70,
                      height: 70,
                    ),
                  ),
                ),
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
