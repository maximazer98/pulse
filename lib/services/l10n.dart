import 'package:flutter/foundation.dart';

import 'storage.dart';

class L10n {
  static final ValueNotifier<bool> isEn = ValueNotifier(true);

  static Future<void> init() async {
    isEn.value = await Storage.loadBool('lang_en', def: true);
  }

  static Future<void> toggle() async {
    isEn.value = !isEn.value;
    await Storage.saveBool('lang_en', value: isEn.value);
  }

  static String t(String de, String en) => isEn.value ? en : de;
}
