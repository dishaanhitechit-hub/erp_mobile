import 'package:erp_mobile/services/mesh_call.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MeshCall make() => MeshCall(callId: 1, isVideo: false, myId: 5, names: {7: 'Asha'});

  test('ringing participants show as ringing peers, self is ignored', () async {
    final c = make();
    await c.sync({
      'status': 'ringing',
      'participants': [
        {'userId': 5, 'userName': 'Me', 'state': 'in_call'},
        {'userId': 7, 'userName': 'Asha', 'state': 'ringing'},
      ],
    });
    expect(c.peers.keys, [7]);
    expect(c.peers[7]!.state, 'ringing');
    expect(c.peers[7]!.name, 'Asha');
    expect(c.endedReason, isNull);
  });

  test('declined participant is dropped; missed call ends', () async {
    final c = make();
    await c.sync({'status': 'ringing', 'participants': [{'userId': 7, 'state': 'ringing'}]});
    await c.sync({'status': 'ringing', 'participants': [{'userId': 7, 'state': 'declined'}]});
    expect(c.peers, isEmpty);
    await c.sync({'status': 'missed', 'participants': []});
    expect(c.endedReason, 'No answer');
  });

  test('media signal updates peer flags; ended signal ends the call', () async {
    final c = make();
    await c.sync({'status': 'ringing', 'participants': [{'userId': 7, 'state': 'ringing'}]});
    await c.handleSignal({'senderId': 7, 'signalType': 'media', 'payload': {'cam': true, 'mic': false}});
    expect(c.peers[7]!.cam, isTrue);
    expect(c.peers[7]!.mic, isFalse);
    await c.handleSignal({'senderId': 7, 'signalType': 'ended', 'payload': {}});
    expect(c.endedReason, 'Call ended');
  });
}
