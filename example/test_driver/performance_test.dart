import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  await integrationDriver(
    responseDataCallback: (Map<String, dynamic>? data) async {
      await writeResponseData(
        data,
        testOutputFilename: 'page_curl_performance',
      );
    },
    writeResponseOnFailure: true,
  );
}
