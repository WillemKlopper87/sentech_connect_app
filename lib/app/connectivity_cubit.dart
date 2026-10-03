import 'package:sentech_connect_app/l10n/l10n.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/network/connectivity_service.dart';

/// `true` = online. Starts optimistic so the banner never flashes at launch.
class ConnectivityCubit extends Cubit<bool> {
  ConnectivityCubit(this._service) : super(true) {
    _service.isOnline().then(_set);
    _subscription = _service.onlineChanges.listen(_set);
  }

  final ConnectivityService _service;
  late final StreamSubscription<bool> _subscription;

  void _set(bool online) {
    if (!isClosed) emit(online);
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}

/// Wraps the whole app (via `MaterialApp.router(builder:)`) and shows a slim
/// banner at the top while the device is offline. The child's position in the
/// tree is the same whether or not the banner is showing, so the Navigator
/// (and every screen's state) is never rebuilt by a connectivity change.
class OfflineBannerHost extends StatelessWidget {
  const OfflineBannerHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityCubit>().state;
    final theme = Theme.of(context);
    return Column(
      children: [
        if (!online)
          Material(
            color: theme.colorScheme.errorContainer,
            child: Semantics(
              liveRegion: true,
              child: Padding(
                // The banner sits where the status bar inset would be consumed
                // by the screen below, so it takes that inset itself.
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.paddingOf(context).top + 6,
                  16,
                  6,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi_off,
                      size: 16,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.l10n.offlineBanner,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          const SizedBox.shrink(),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: !online,
            child: child,
          ),
        ),
      ],
    );
  }
}
