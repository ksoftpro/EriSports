import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native memory db smoke', () async {
    final db = NativeDatabase.memory();
    await db.close();
    expect(true, isTrue);
  });
}
