import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatmate/theme/theme-controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first launch defaults to light mode', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = ThemeController();

    expect(controller.mode, ThemeMode.light);

    await controller.load();

    expect(controller.mode, ThemeMode.light);
  });

  test('the chosen mode is remembered on the next launch', () async {
    SharedPreferences.setMockInitialValues({});
    final firstLaunch = ThemeController();
    await firstLaunch.load();

    await firstLaunch.toggle();

    expect(firstLaunch.mode, ThemeMode.dark);

    final nextLaunch = ThemeController();
    await nextLaunch.load();

    expect(nextLaunch.mode, ThemeMode.dark);
  });

  test('an explicit light choice is remembered', () async {
    SharedPreferences.setMockInitialValues({'chatmate.theme_mode': 'dark'});
    final controller = ThemeController();
    await controller.load();

    await controller.set(ThemeMode.light);

    expect(controller.mode, ThemeMode.light);

    final nextLaunch = ThemeController();
    await nextLaunch.load();

    expect(nextLaunch.mode, ThemeMode.light);
  });
}
