// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing


import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:log_hood/log_hood.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LogHood initialization test', (WidgetTester tester) async {
    // Initialize LogHood
    await LogHood.initialize();
    
    // Test logging functionality
    LogHood.i('Integration test log');
    LogHood.d('Debug message', metadata: {'test': true});
    
    // Verify logger is initialized
    expect(() => LogHood.logger, isNot(throwsStateError));
  });
}
