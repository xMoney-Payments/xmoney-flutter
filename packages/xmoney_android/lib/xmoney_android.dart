import 'package:xmoney_platform_interface/xmoney_platform_interface.dart';

export 'src/method_channel_xmoney.dart';

import 'src/method_channel_xmoney.dart';

/// Federated Android plugin registration.
class XMoneyAndroidPlugin {
  static void registerWith() {
    XMoneyPlatform.instance = MethodChannelXMoney();
  }
}
