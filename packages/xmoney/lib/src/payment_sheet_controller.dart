import 'package:flutter/foundation.dart';
import 'package:xmoney_platform_interface/xmoney_platform_interface.dart';

import 'payment_sheet.dart';

/// Controller for [PaymentSheet].
///
/// [loading] is true while [init] is in flight. [present] and [dismiss]
/// forward to [PaymentSheet].
class PaymentSheetController extends ChangeNotifier {
  bool _loading = false;

  /// True while [init] is in flight.
  bool get loading => _loading;

  /// Stores [configuration] and updates [loading] around [PaymentSheet.init].
  Future<void> init(PaymentConfig configuration) async {
    _loading = true;
    notifyListeners();
    try {
      await PaymentSheet.init(configuration);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Presents the sheet for [intent]. See [PaymentSheet.present].
  Future<PaymentResult> present(
    PaymentIntent intent, {
    void Function(PaymentSheetEvent event)? onEvent,
  }) {
    return PaymentSheet.present(intent, onEvent: onEvent);
  }

  /// Closes the sheet. See [PaymentSheet.dismiss].
  void dismiss() => PaymentSheet.dismiss();
}
