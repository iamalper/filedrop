import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weepy/screens/settings.dart';

import 'main.dart';

class Constants {
  ///Folder name for incoming files
  static const String saveFolder = "FileDrop";

  ///Http port for discovery, sending and recieving files
  @Deprecated(
      "No longer use a constant port for discovery instead use minPort and maxPort because it throws socketException when port is busy.")
  static const port = 3242;

  ///Min port for discovery
  ///
  ///Should be lower than [maxPort]
  static const minPort = 3000;

  ///Max port for discovery
  ///
  ///Should be higher than [minPort]
  static const maxPort = 3005;

  ///Response message for discovery
  static const meeting = "WEEPY";
}

class WidgetKeys {
  static const sendButton = Key("send button");
  static const receiveButton = Key("recieve button");
}

class Appbars {
  static AppBar globalAppBar({required bool isDark}) => AppBar(actions: [
        _themeSwitch(isDark),
      ]);

  static AppBar appBarWithSettings(
          {required bool isDark,
          required BuildContext context,
          required PackageInfo packageInfo,
          required SharedPreferences sharedPreferences}) =>
      AppBar(actions: [
        _themeSwitch(isDark),
        IconButton(
            onPressed: () async {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => SettingsPage(
                          isDark: isDark,
                          packageInfo: packageInfo,
                          sharedPreferences: sharedPreferences)));
            },
            icon: const Icon(Icons.settings)),
      ]);
  static IconButton _themeSwitch(bool isDark) => IconButton(
      icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
      onPressed: () async {
        MaterialAppWidget.valueNotifier.value == ThemeMode.light
            ? MaterialAppWidget.valueNotifier.value = ThemeMode.dark
            : MaterialAppWidget.valueNotifier.value = ThemeMode.light;
        final sharedPrefences = await SharedPreferences.getInstance();
        await sharedPrefences.setBool(
            "isDark", MaterialAppWidget.valueNotifier.value == ThemeMode.dark);
      });
}

class Assets {
  static final hotspot = Lottie.asset("assets/lottie/blue-hotspot.json");
  static final wifi = Lottie.asset("assets/lottie/scanning-for-wifi.json");
}
