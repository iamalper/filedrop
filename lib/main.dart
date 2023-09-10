import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'screens/receive_page.dart';
import 'screens/send_page.dart';
import 'screens/files_page.dart';
import 'constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPrefences = await SharedPreferences.getInstance();
  if (kReleaseMode && (Platform.isAndroid || Platform.isIOS)) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final useCrashReporting =
        sharedPrefences.getBool("crashRepostsEnable") ?? true;
    FlutterError.onError = useCrashReporting
        ? FirebaseCrashlytics.instance.recordFlutterFatalError
        : null;
    PlatformDispatcher.instance.onError = useCrashReporting
        ? (error, stack) {
            FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
            return true;
          }
        : null;
  }
  final packageInfo = await PackageInfo.fromPlatform();

  final isDark = sharedPrefences.getBool("isDark") ?? false;
  runApp(ProviderScope(
      child: MaterialAppWidget(
    title: "FileDrop",
    isDarkDefault: isDark,
    packageInfo: packageInfo,
    sharedPreferences: sharedPrefences,
  )));
}

class MaterialAppWidget extends StatelessWidget {
  final String title;
  final bool isDarkDefault;
  final PackageInfo packageInfo;
  final SharedPreferences sharedPreferences;
  static late ValueNotifier<ThemeMode> valueNotifier;
  const MaterialAppWidget(
      {super.key,
      required this.title,
      required this.isDarkDefault,
      required this.packageInfo,
      required this.sharedPreferences});
  @override
  Widget build(BuildContext context) {
    valueNotifier =
        ValueNotifier(isDarkDefault ? ThemeMode.dark : ThemeMode.light);
    return ValueListenableBuilder(
      valueListenable: valueNotifier,
      builder: (BuildContext context, value, Widget? child) {
        return MaterialApp(
          localeListResolutionCallback: (locales, supportedLocales) {
            if (locales == null) return const Locale('en');
            for (var locale in locales) {
              if (supportedLocales.contains(Locale(locale.languageCode))) {
                return locale;
              }
            }
            return const Locale('en');
          },
          title: title,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('tr'),
            Locale('en'),
          ],
          themeMode: value,
          theme: ThemeData(
              brightness: Brightness.light,
              textTheme: Theme.of(context)
                  .textTheme
                  .merge(Typography().black)
                  .apply(fontSizeDelta: 1, fontSizeFactor: 1.1)),
          darkTheme: ThemeData(
              brightness: Brightness.dark,
              textTheme: Theme.of(context)
                  .textTheme
                  .merge(Typography().white)
                  .apply(fontSizeDelta: 1, fontSizeFactor: 1.1)),
          home: _MainWidget(
              isDark: (valueNotifier.value == ThemeMode.dark),
              packageInfo: packageInfo,
              sharedPreferences: sharedPreferences),
        );
      },
    );
  }
}

class _MainWidget extends StatefulWidget {
  final bool isDark;
  final PackageInfo packageInfo;
  final SharedPreferences sharedPreferences;
  const _MainWidget(
      {required this.isDark,
      required this.packageInfo,
      required this.sharedPreferences});

  @override
  State<_MainWidget> createState() => _MainWidgetState();
}

class _MainWidgetState extends State<_MainWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbars.appBarWithSettings(
          isDark: widget.isDark,
          context: context,
          packageInfo: widget.packageInfo,
          sharedPreferences: widget.sharedPreferences),
      body: Column(
        children: [
          const Expanded(
            flex: 3,
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Dosyalar(),
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 10,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextButton(
                      key: WidgetKeys.sendButton,
                      onPressed: kIsWeb
                          ? null
                          : () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          SendPage(isDark: widget.isDark)));
                              setState(() {});
                            },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.upload),
                          Text(AppLocalizations.of(context)!.sendFileButton),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 10,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextButton(
                      key: WidgetKeys.receiveButton,
                      onPressed: kIsWeb
                          ? null
                          : () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          ReceivePage(isDark: widget.isDark)));
                              setState(() {});
                            },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.download),
                          Text(AppLocalizations.of(context)!.getFileButton),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
