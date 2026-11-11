import 'dart:typed_data';

import 'package:erp_mobile/config/module_registry.dart';
import 'package:erp_mobile/screens/common/print_view_screen.dart';
import 'package:erp_mobile/services/photo_stamp.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('stamp lines: time, GPS with on/off-site, project / location / user', () {
    final s = StampInfo(
      takenAt: DateTime(2026, 11, 8, 17, 42, 5),
      latitude: 22.5730,
      longitude: 88.3640,
      accuracyM: 7.6,
      onSite: true,
      distanceM: 45,
      project: 'Test Tower (TST)',
      subLocation: 'Block C',
      user: 'Engineer',
    );
    final l = s.lines();
    expect(l[0], '08 Nov 2026  17:42:05 IST');
    expect(l[1], '22.57300 N, 88.36400 E  +/-8 m  ON SITE');
    expect(l[2], 'Test Tower (TST)  |  Block C  |  Engineer');

    final off = StampInfo(takenAt: DateTime(2026, 1, 2, 3, 4, 5), latitude: -1, longitude: -2, onSite: false, distanceM: 2500, project: 'P', user: 'U');
    expect(off.lines()[1], contains('OFF SITE (2.5 km)'));
    final fake = StampInfo(takenAt: DateTime(2026), latitude: 1, longitude: 2, onSite: true, mocked: true, project: 'P', user: 'U');
    expect(fake.lines()[1], contains('FAKE GPS'));
    expect(StampInfo(takenAt: DateTime(2026), project: 'P', user: 'U').lines()[1], 'Location not available');
  });

  test('stampPhoto resizes, keeps it upright and draws a dark bar at the bottom', () {
    final src = img.Image(width: 4000, height: 3000);
    img.fill(src, color: img.ColorRgb8(200, 200, 200));
    final out = stampPhoto(StampJob(Uint8List.fromList(img.encodeJpg(src)), ['08 Nov 2026', 'GPS', 'Project']));
    final o = img.decodeJpg(out)!;
    expect(o.width, 1920);
    expect(o.height, 1440);
    final top = o.getPixel(960, 100);
    final bar = o.getPixel(1500, o.height - 8); // right side of the bar, away from the text
    expect(top.r, greaterThan(180));
    expect(bar.r, lessThan(110));
  });

  test('distance, India time helpers', () {
    expect(distanceMeters(22.5726, 88.3639, 22.5726, 88.3639), 0);
    expect(distanceMeters(22.5726, 88.3639, 22.5816, 88.3639), closeTo(1000, 15));
    final t = DateTime.utc(2026, 11, 8, 17, 42, 5);
    expect(istIso(t), '2026-11-08T17:42:05+05:30');
    expect(dayOf(t), '2026-11-08');
  });

  test('DPR module opens its own screen and has a print page', () {
    final m = allSections.expand((s) => s.modules).firstWhere((m) => m.key == 'daily_progress_report');
    expect(m.kind, ModuleKind.dpr);
    expect(m.available, isTrue);
    expect(webPrintUrl(m, {'uuid': 'abc'}), endsWith('/print/dpr/abc'));
  });

  test('entries open in the print page only for modules that have one', () {
    final all = allSections.expand((s) => s.modules).toList();
    final indent = all.firstWhere((m) => m.key == 'indent');
    final unit = all.firstWhere((m) => m.key == 'unit');
    expect(opensInPrint(indent), isTrue);
    expect(opensInPrint(unit), isFalse);
    expect(all.where(opensInPrint).length, greaterThanOrEqualTo(20));
  });
}
