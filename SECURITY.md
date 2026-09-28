# Security Policy

## Supported versions

| Version | Supported |
| ------- | --------- |
| 0.0.x   | Yes       |

## Reporting a vulnerability

Do **not** open a public GitHub issue for security vulnerabilities.

Email **it-team@xmoney.com** with:

- a clear description of the issue
- steps to reproduce
- impact (what an attacker could do)

Expect an initial response within **5 business days**. We will coordinate a fix and disclosure.

## Scope

This policy covers the published Flutter SDK packages in this repo: `xmoney`, `xmoney_ios`, `xmoney_android`, and `xmoney_platform_interface`.

Issues in merchant apps, backends, or non-SDK xMoney products are out of scope here — contact your xMoney account team.

## Hard rules for integrators

- Put only the publishable `publicKey` (`pk_test_…` / `pk_live_…`) in the Flutter app.
- Keep secret / private API keys on your server. Create orders server-side.
- Never commit live keys, order payloads with secrets, or card data to source control.
- Use sandbox keys during development.
- Do not log PAN or CVV. The SDK does not expose them to Dart; report any suspected leakage of card data immediately.

## Card data (reality)

Card entry runs in native SDK views. PAN + CVV stay out of the Dart method channel and are sent over HTTPS to xMoney’s PCI DSS Level 1 backends (`secure*.xmoney.com` for payment; `api-*-next.xmoney.com` for optional account validation).

## TLS / certificate pinning

All SDK network calls use HTTPS to hardcoded xMoney hosts only (no cleartext, no merchant-supplied base URLs).

Certificate pinning is **not** implemented in the SDK. For v0.0.x we **accept** the residual risk that a compromised device trust store could enable MITM. Revisit pinning if the threat model or merchant compliance requirements change.
