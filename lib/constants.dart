import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';

class Constants {
  //Gelen dosyaların kaydedildiği klasörün adı
  static const String saveFolder = "File Sharer";

  //Http portu
  static const port = 3242;

  //Http isteklerine tanıtma gövdesi
  static const tanitim = "FILE_SHARER";
}

class Appbars {
  static AppBar globalAppBar({required bool isDark}) => AppBar(
        title: Align(
          alignment: Alignment.centerRight,
          child: IconButton(
              icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
              onPressed: () {
                MaterialAppWidget.valueNotifier.value == ThemeMode.light
                    ? MaterialAppWidget.valueNotifier.value = ThemeMode.dark
                    : MaterialAppWidget.valueNotifier.value = ThemeMode.light;
                SharedPreferences.getInstance().then((sharedPrefences) {
                  sharedPrefences.setBool("isDark",
                      MaterialAppWidget.valueNotifier.value == ThemeMode.dark);
                });
              }),
        ),
      );
}

class Assets {
  static final hotspot = Lottie.asset("assets/lottie/blue-hotspot.json");
  static final wifi = Lottie.asset("assets/lottie/scanning-for-wifi.json");
}
