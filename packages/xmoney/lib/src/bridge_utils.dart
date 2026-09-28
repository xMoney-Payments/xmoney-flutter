// ignore_for_file: public_member_api_docs

int _requestCounter = 0;

String nextBridgeRequestId() {
  _requestCounter += 1;
  return 'req_$_requestCounter';
}

void resetBridgeRequestIdForTest() {
  _requestCounter = 0;
}
