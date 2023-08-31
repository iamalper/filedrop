import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/receive_page.dart';
import 'screens/send_page.dart';
import 'classes/database.dart';
import 'models.dart';
import 'screens/files_page.dart';
import 'constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kReleaseMode && (Platform.isAndroid || Platform.isIOS)) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }
  final packageInfo = await PackageInfo.fromPlatform();
  final sharedPrefences = await SharedPreferences.getInstance();
  final isDark = sharedPrefences.getBool("isDark") == true;
  runApp(MaterialAppWidget(
    title: "Weep Transfer",
    isDarkDefault: isDark,
    packageInfo: packageInfo,
  ));
}

class MaterialAppWidget extends StatelessWidget {
  final String title;
  final bool isDarkDefault;
  final PackageInfo packageInfo;
  static late ValueNotifier<ThemeMode> valueNotifier;
  const MaterialAppWidget(
      {super.key,
      required this.title,
      required this.isDarkDefault,
      required this.packageInfo});
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
          ),
        );
      },
    );
  }
}

List<DbFile> allFiles = [];

class _MainWidget extends StatefulWidget {
  final bool isDark;
  final PackageInfo packageInfo;
  const _MainWidget({required this.isDark, required this.packageInfo});

  @override
  State<_MainWidget> createState() => _MainWidgetState();
}

class _MainWidgetState extends State<_MainWidget> {
  final db = DatabaseManager();

  late Future<void> dbFuture;
  bool loaded = false;
  bool dbError = false;

  @override
  void initState() {
    dbFuture = db.open().then((_) async {
      final allFilesTmp = await db.files;
      setState(() {
        allFiles = allFilesTmp;
        loaded = true;
      });
    }).catchError((_) {
      setState(() {
        dbError = true;
        loaded = true;
      });
    });
    super.initState();
  }

  @override
  void dispose() {
    dbFuture.ignore();
    db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbars.appBarWithSettings(
        isDark: widget.isDark,
        context: context,
        packageInfo: widget.packageInfo,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Dosyalar(
                allFiles: allFiles,
                loaded: loaded,
                dbError: dbError,
              ),
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
                      key: const Key("dosya gönder button"),
                      onPressed: kIsWeb
                          ? null
                          : () {
                              Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              SendPage(isDark: widget.isDark)))
                                  .then((value) => setState(() {}));
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
                      key: const Key("dosya al button"),
                      onPressed: kIsWeb
                          ? null
                          : () {
                              Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => ReceivePage(
                                              isDark: widget.isDark)))
                                  .then((value) => setState(() {}));
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
