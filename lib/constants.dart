import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';

class Constants {
  ///Folder name for incoming files
  static const String saveFolder = "Weepy";

  ///Http port for discovery, sending and recieving files
  static const port = 3242;

  ///Response message for discovery
  static const meeting = "WEEPY";
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
