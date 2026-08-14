import 'package:flutter_test/flutter_test.dart';

import 'package:albaniy_one_audio_app/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const AlbaniyOneAudioApp());
    expect(find.byType(AlbaniyOneAudioApp), findsOneWidget);
  });
}
