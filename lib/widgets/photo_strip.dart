import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../state.dart';

/// Meter screenshots for one tenant/month: add from gallery or camera,
/// thumbnails, tap to zoom, delete.
class PhotoStrip extends StatelessWidget {
  final AppState state;
  final String month;
  final int tenant;
  const PhotoStrip({super.key, required this.state, required this.month, required this.tenant});

  Future<void> _add(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    try {
      final files = source == ImageSource.gallery
          ? await picker.pickMultiImage(imageQuality: 85)
          : [if (await picker.pickImage(source: ImageSource.camera, imageQuality: 85) case final f?) f];
      for (final f in files) {
        await state.addPhoto(month, tenant, f.path);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('לא ניתן להוסיף תמונה: $e')));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, Photo ph) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('למחוק את התמונה?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ביטול')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('מחק')),
        ],
      ),
    );
    if (ok == true) await state.deletePhoto(ph);
  }

  void _open(BuildContext context, List<Photo> photos, int index) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _PhotoViewer(
        state: state,
        photos: photos,
        initial: index,
        onDelete: (ph) async {
          await _confirmDelete(context, ph);
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final photos = state.photosFor(month, tenant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Text('צילומי שעונים'),
          const Spacer(),
          IconButton(
            tooltip: 'מהגלריה',
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () => _add(context, ImageSource.gallery),
          ),
          IconButton(
            tooltip: 'מהמצלמה',
            icon: const Icon(Icons.photo_camera_outlined),
            onPressed: () => _add(context, ImageSource.camera),
          ),
        ]),
        if (photos.isNotEmpty)
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (c, i) {
                final ph = photos[i];
                return Stack(children: [
                  GestureDetector(
                    onTap: () => _open(context, photos, i),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(state.photoFile(ph),
                          width: 76, height: 76, fit: BoxFit.cover, cacheWidth: 200,
                          errorBuilder: (_, __, ___) => Container(
                              width: 76, height: 76, color: Colors.grey, child: const Icon(Icons.broken_image))),
                    ),
                  ),
                  Positioned(
                    top: 2,
                    left: 2,
                    child: InkWell(
                      onTap: () => _confirmDelete(context, ph),
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        padding: const EdgeInsets.all(2),
                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ]);
              },
            ),
          ),
      ],
    );
  }
}

class _PhotoViewer extends StatefulWidget {
  final AppState state;
  final List<Photo> photos;
  final int initial;
  final Future<void> Function(Photo) onDelete;
  const _PhotoViewer({required this.state, required this.photos, required this.initial, required this.onDelete});

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _pc = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.photos.length}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ph = widget.photos[_index];
              await widget.onDelete(ph);
              if (!widget.state.photos.any((x) => x.id == ph.id) && context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pc,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (c, i) => InteractiveViewer(
          maxScale: 6,
          child: Center(child: Image.file(widget.state.photoFile(widget.photos[i]))),
        ),
      ),
    );
  }
}
