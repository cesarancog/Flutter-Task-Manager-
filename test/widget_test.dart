
import 'package:flutter_test/flutter_test.dart';
import 'package:local_task_manager/main.dart';

void main() {
  testWidgets('Task manager displays its title', (tester) async {
    await tester.pumpWidget(const TaskManagerApp());

    expect(find.text('My Task Manager'), findsOneWidget);
  });
}
