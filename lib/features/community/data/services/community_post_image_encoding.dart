import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Encodes picked images as Base64 JPEG strings for Firestore (no Firebase Storage).
/// Images are resized/compressed to reduce document size (Firestore limit 1 MiB).
Future<List<String>> encodeCommunityPostImagesForFirestore(
  List<XFile> files,
) async {
  final out = <String>[];
  for (final f in files) {
    final raw = await f.readAsBytes();
    if (raw.isEmpty) continue;
    final jpeg = _toFirestoreJpegBytes(raw);
    if (jpeg.isEmpty) continue;
    out.add(base64Encode(jpeg));
  }
  return out;
}

Uint8List _toFirestoreJpegBytes(Uint8List input) {
  final decoded = img.decodeImage(input);
  if (decoded == null) {
    return Uint8List(0);
  }
  const maxSide = 960;
  var work = decoded;
  if (work.width > maxSide || work.height > maxSide) {
    if (work.width >= work.height) {
      work = img.copyResize(work, width: maxSide, interpolation: img.Interpolation.linear);
    } else {
      work = img.copyResize(work, height: maxSide, interpolation: img.Interpolation.linear);
    }
  }
  return Uint8List.fromList(img.encodeJpg(work, quality: 78));
}
