// ignore_for_file: public_member_api_docs

import 'package:xmoney_platform_interface/xmoney_platform_interface.dart';

class PresentSession {
  bool inFlight = false;
  bool isProcessing = false;
  int generation = 0;

  String begin({bool assumeProcessing = false}) {
    if (inFlight && (isProcessing || assumeProcessing)) {
      return 'canceled';
    }
    generation += 1;
    inFlight = true;
    if (assumeProcessing) {
      isProcessing = true;
    }
    return 'go';
  }

  void Function(PaymentSheetEvent) track(
    int generation,
    void Function(PaymentSheetEvent event)? onEvent,
  ) {
    return (PaymentSheetEvent event) {
      if (generation == this.generation &&
          event is PaymentSheetProcessingEvent) {
        isProcessing = event.isProcessing;
      }
      onEvent?.call(event);
    };
  }

  void finish(int generation) {
    if (generation == this.generation) {
      inFlight = false;
      isProcessing = false;
    }
  }

  void reset() {
    inFlight = false;
    isProcessing = false;
    generation = 0;
  }
}
