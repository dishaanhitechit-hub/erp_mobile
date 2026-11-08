import 'package:flutter/material.dart';
import '../services/offline_store.dart';
import '../theme/app_theme.dart';

/// Thin strip at the very top of every screen while offline (or while
/// queued messages are being sent). Takes the status-bar space itself.
class OfflineBanner extends StatelessWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([NetworkStatus.instance, Outbox.instance]),
      builder: (context, _) {
        final online = NetworkStatus.instance.online;
        final pending = Outbox.instance.items.length;
        final show = !online || Outbox.instance.flushing;
        final top = MediaQuery.of(context).padding.top;
        if (!show) return child;
        final text = online
            ? 'Back online • sending $pending queued item${pending == 1 ? '' : 's'}…'
            : 'Offline • showing saved data${pending > 0 ? ' • $pending waiting to send' : ''}';
        return Column(children: [
          Material(
            color: online ? AppColors.accent2 : const Color(0xFF3A3A3A),
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, top + 4, 12, 5),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(online ? Icons.cloud_upload_rounded : Icons.cloud_off_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(text,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ),
          Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: child)),
        ]);
      },
    );
  }
}
