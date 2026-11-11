import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// What gets burned into a site photo.
class StampInfo {
  final DateTime takenAt; // India time
  final double? latitude;
  final double? longitude;
  final double? accuracyM;
  final bool? onSite; // null = site location unknown
  final int? distanceM;
  final bool mocked;
  final String project;
  final String? subLocation;
  final String user;

  const StampInfo({
    required this.takenAt,
    this.latitude,
    this.longitude,
    this.accuracyM,
    this.onSite,
    this.distanceM,
    this.mocked = false,
    required this.project,
    this.subLocation,
    required this.user,
  });

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String _pad2(int n) => n.toString().padLeft(2, '0');

  /// The three stamp lines (ASCII only — the bitmap font has no other glyphs).
  List<String> lines() {
    final t = takenAt;
    final when = '${_pad2(t.day)} ${_months[t.month - 1]} ${t.year}  ${_pad2(t.hour)}:${_pad2(t.minute)}:${_pad2(t.second)} IST';
    String where;
    if (latitude == null || longitude == null) {
      where = 'Location not available';
    } else {
      final lat = '${latitude!.abs().toStringAsFixed(5)} ${latitude! >= 0 ? 'N' : 'S'}';
      final lng = '${longitude!.abs().toStringAsFixed(5)} ${longitude! >= 0 ? 'E' : 'W'}';
      where = '$lat, $lng';
      if (accuracyM != null) where += '  +/-${accuracyM!.round()} m';
      if (mocked) {
        where += '  FAKE GPS';
      } else if (onSite == true) {
        where += '  ON SITE';
      } else if (onSite == false) {
        where += '  OFF SITE (${distanceM != null && distanceM! >= 1000 ? '${(distanceM! / 1000).toStringAsFixed(1)} km' : '${distanceM ?? '?'} m'})';
      }
    }
    final who = [project, if (subLocation != null && subLocation!.trim().isNotEmpty) subLocation!.trim(), user].join('  |  ');
    return [when, where, _ascii(who)];
  }

  static String _ascii(String s) => s.replaceAll(RegExp(r'[^\x20-\x7E]'), '?');
}

/// Arguments for [stampPhoto] (sent to a background isolate with `compute`).
class StampJob {
  final Uint8List jpeg;
  final List<String> lines;
  final int maxEdge;
  const StampJob(this.jpeg, this.lines, {this.maxEdge = 1920});
}

/// Upright, resized JPEG with a dark bar of [StampJob.lines] along the bottom.
/// Pure Dart (package:image) so it can run in an isolate.
Uint8List stampPhoto(StampJob job) {
  var photo = img.decodeImage(job.jpeg);
  if (photo == null) throw const FormatException('Could not read the photo');
  photo = img.bakeOrientation(photo);
  final longEdge = math.max(photo.width, photo.height);
  if (longEdge > job.maxEdge) {
    photo = photo.width >= photo.height
        ? img.copyResize(photo, width: job.maxEdge, interpolation: img.Interpolation.average)
        : img.copyResize(photo, height: job.maxEdge, interpolation: img.Interpolation.average);
  }

  // Bigger text on bigger photos; the bitmap fonts come in 14/24/48 px.
  final big = photo.width >= 1200;
  final font = big ? img.arial48 : img.arial24;
  final small = big ? img.arial24 : img.arial14;
  final lineH = font.lineHeight;
  final smallH = small.lineHeight;
  final pad = big ? 18 : 10;
  final barH = pad * 2 + lineH + (smallH + 6) * 2;
  final top = photo.height - barH;

  img.fillRect(photo, x1: 0, y1: top, x2: photo.width - 1, y2: photo.height - 1, color: img.ColorRgba8(0, 0, 0, 165));
  // Accent strip so the stamp is recognisable.
  img.fillRect(photo, x1: 0, y1: top, x2: big ? 7 : 4, y2: photo.height - 1, color: img.ColorRgb8(245, 166, 35));

  final white = img.ColorRgb8(255, 255, 255);
  final soft = img.ColorRgb8(225, 225, 225);
  var y = top + pad;
  img.drawString(photo, job.lines[0], font: font, x: pad + 8, y: y, color: white);
  y += lineH + 6;
  img.drawString(photo, job.lines[1], font: small, x: pad + 8, y: y, color: soft);
  y += smallH + 6;
  img.drawString(photo, job.lines[2], font: small, x: pad + 8, y: y, color: soft);

  return Uint8List.fromList(img.encodeJpg(photo, quality: 85));
}

/// Great-circle distance in metres.
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dp = rad(lat2 - lat1), dl = rad(lng2 - lng1);
  final a = math.pow(math.sin(dp / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dl / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// Current India time (site days follow IST, whatever the phone's time zone).
DateTime nowIst() => DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

String dayOf(DateTime ist) =>
    '${ist.year}-${ist.month.toString().padLeft(2, '0')}-${ist.day.toString().padLeft(2, '0')}';

/// ISO time with the India offset, e.g. 2026-11-08T17:42:10+05:30.
String istIso(DateTime ist) => '${ist.toIso8601String().split('.').first}+05:30';
