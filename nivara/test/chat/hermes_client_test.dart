import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/chat/data/hermes_client.dart';

void main() {
  test('HermesClient can be instantiated with base URL', () {
    final client = HermesClient(baseUrl: 'http://localhost:8000');
    expect(client, isNotNull);
  });
}
