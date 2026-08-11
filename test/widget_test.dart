import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder: composed app shell', () {
    // The default flutter-create counter test referenced a MyApp widget the
    // composed shell does not have; real coverage lives in the SDKs.
    expect(true, isTrue);
  });
}
// Build trigger: trivial in-filter change so the Build (Smart) workflow fires on merge.
