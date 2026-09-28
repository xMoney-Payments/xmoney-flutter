import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xmoney/xmoney.dart';

import '../sample_helpers.dart';

class DemoSecrets {
  DemoSecrets({
    required this.publicKey,
    required this.apiKey,
    required this.apiBase,
    required this.currency,
    required this.description,
  });

  static String _apiBase(Map<String, dynamic> json) {
    final base = json['API_BASE'] as String?;
    if (base != null && base.isNotEmpty) return base;
    final host = (json['API_HOST'] as String? ?? '').trim();
    if (host.isEmpty) return '';
    if (host.startsWith('http://') || host.startsWith('https://')) return host;
    return 'https://$host';
  }

  factory DemoSecrets.fromJson(Map<String, dynamic> json) {
    return DemoSecrets(
      publicKey: json['PUBLIC_KEY'] as String? ?? '',
      apiKey: json['API_KEY'] as String? ?? '',
      apiBase: _apiBase(json),
      currency: json['CURRENCY'] as String? ?? 'EUR',
      description: json['DESCRIPTION'] as String? ?? 'Demo',
    );
  }

  final String publicKey;
  final String apiKey;
  final String apiBase;
  final String currency;
  final String description;
}

class DemoCheckoutBackend {
  DemoCheckoutBackend(this.secrets);

  final DemoSecrets secrets;

  String? secretsError() {
    if (secrets.publicKey.isEmpty ||
        secrets.publicKey.contains('replace') ||
        secrets.publicKey.contains('xxxxx')) {
      return 'Set PUBLIC_KEY in example/secrets.json';
    }
    if (secrets.apiKey.isEmpty || secrets.apiKey.contains('your_api_key')) {
      return 'Set API_KEY in example/secrets.json';
    }
    return null;
  }

  Future<PaymentIntent> createPaymentIntent({
    int amountMinor = sampleAmountMinor,
    String? description,
    String? currency,
  }) async {
    final blocked = secretsError();
    if (blocked != null) {
      throw StateError(blocked);
    }
    final amount = amountMinor / 100;
    final cur = currency ?? secrets.currency;
    final desc = description ?? secrets.description;
    final base = secrets.apiBase.replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse('$base/api/orders');
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'amount': amount,
        'currency': cur,
        'description': desc,
        'publicKey': secrets.publicKey,
        'apiKey': secrets.apiKey,
      }),
    );
    Map<String, dynamic> json = {};
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      json = {};
    }
    if (response.statusCode >= 400) {
      final message =
          json['error'] as String? ??
          json['message'] as String? ??
          'HTTP ${response.statusCode}';
      throw StateError(message);
    }
    final payload = json['payload'] as String? ?? '';
    final checksum = json['checksum'] as String? ?? '';
    if (payload.isEmpty || checksum.isEmpty) {
      throw StateError('Missing payload or checksum in API response');
    }
    return PaymentIntent(orderPayload: payload, orderChecksum: checksum);
  }
}
