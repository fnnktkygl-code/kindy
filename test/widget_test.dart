import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pigio_app/core/state/app_state.dart';

void main() {
  test('PigioAppState persists wishes family and sizes', () async {
    SharedPreferences.setMockInitialValues({});

    final state = PigioAppState();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(state.wishes, isEmpty);
    expect(state.contacts, isEmpty);

    state.addWish(title: 'Lego Star Wars');
    state.addContact(name: 'Tom', role: 'Brother');
    state.saveSizeProfile('shoes', {'eu': '43', 'us': '10'}, fitKey: 'regular');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final restored = PigioAppState();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(restored.wishes.length, 1);
    expect(restored.wishes.first.title, 'Lego Star Wars');
    expect(restored.contacts.length, 1);
    expect(restored.contacts.first.name, 'Tom');
    expect(restored.sizes.length, 1);
    expect(restored.sizes.first.categoryKey, 'shoes');
    expect(restored.sizes.first.values['eu'], '43');
  });
}
