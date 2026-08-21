import 'package:flutter_test/flutter_test.dart';

import 'package:albaniy_one_audio_app/main.dart';

void main() {
  testWidgets('App boots and shows the scholar header', (tester) async {
    await tester.pumpWidget(const AlbaniyOneAudioApp());

    expect(
      find.text('Shaikh Albaniy Zaria'),
      findsOneWidget,
    );
  });
}
