// ignore_for_file: public_member_api_docs

import 'package:xmoney_platform_interface/xmoney_platform_interface.dart';

import 'native_events.dart';
import 'present_session.dart';

final _sessions =
    <
      String,
      ({
        int generation,
        PresentSession session,
        void Function(PaymentSheetEvent event)? onEvent,
      })
    >{};

XMoneyNativeEventHandler? _outerNativeHandler;

void ensureNativeEventRouter() {
  if (XMoneyPlatform.instance.onNativeEvent == _dispatchNativeEvent) {
    return;
  }
  _outerNativeHandler = XMoneyPlatform.instance.onNativeEvent;
  XMoneyPlatform.instance.onNativeEvent = _dispatchNativeEvent;
}

void _dispatchNativeEvent(String requestId, Map<String, dynamic> event) {
  final session = _sessions[requestId];
  if (session != null) {
    final mapped = mapNativeBridgeEvent(event);
    if (mapped != null) {
      session.session.track(session.generation, session.onEvent)(mapped);
    }
  }
  _outerNativeHandler?.call(requestId, event);
}

void attachNativeEventHandler(
  String requestId,
  int generation,
  PresentSession session,
  void Function(PaymentSheetEvent event)? onEvent,
) {
  ensureNativeEventRouter();
  _sessions[requestId] = (
    generation: generation,
    session: session,
    onEvent: onEvent,
  );
}

void detachNativeEventHandler(String requestId) {
  _sessions.remove(requestId);
  if (_sessions.isEmpty && _outerNativeHandler != null) {
    XMoneyPlatform.instance.onNativeEvent = _outerNativeHandler;
    _outerNativeHandler = null;
  }
}

void resetNativeEventRouterForTest() {
  _sessions.clear();
  _outerNativeHandler = null;
}
