import 'dart:developer';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'package:flutter_store_listing/flutter_store_listing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  final bool isDark;
  final PackageInfo packageInfo;
  final SharedPreferences sharedPreferences;
  const SettingsPage(
      {super.key,
      required this.isDark,
      required this.packageInfo,
      required this.sharedPreferences});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Uri _sourceLink;
  late bool _crashReportingSettingValue;
  final _isCrashReportingAvailable = (Platform.isAndroid || Platform.isIOS);
  @override
  void initState() {
    _crashReportingSettingValue =
        widget.sharedPreferences.getBool("crashRepostsEnable") ?? true;
    try {
      _sourceLink =
          Uri.parse(FirebaseRemoteConfig.instance.getString("sourceLink"));
    } on FirebaseException catch (_) {
      log("Error at getting github repo link. Fallback to default",
          name: "Settings Page");
      _sourceLink = Uri.parse("https://github.com/iamalper/filedrop");
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbars.globalAppBar(isDark: widget.isDark),
      body: SettingsList(sections: [
        SettingsSection(
            title: Text(AppLocalizations.of(context)!.aboutFiledrop),
            tiles: [
              SettingsTile.navigation(
                  title: Text(AppLocalizations.of(context)!.appPage),
                  onPressed: (context) async {
                    final storeListing = FlutterStoreListing();
                    if (await storeListing.isSupported()) {
                      FlutterStoreListing().launchStoreListing();
                    } else {
                      launchUrl(_sourceLink);
                    }
                  }),
              SettingsTile.navigation(
                  title: Text(AppLocalizations.of(context)!.leaveReview),
                  onPressed: (context) async {
                    final storeListing = FlutterStoreListing();
                    if (await storeListing.isSupported()) {
                      FlutterStoreListing().launchRequestReview();
                    } else {
                      final uriSegments =
                          List<String>.from(_sourceLink.pathSegments);
                      uriSegments.add("issues");
                      final issuesLink =
                          _sourceLink.replace(pathSegments: uriSegments);
                      launchUrl(issuesLink);
                    }
                  }),
              SettingsTile.navigation(
                title: Text(AppLocalizations.of(context)!.publicGithubRepo),
                value: Text(_sourceLink.toString()),
                onPressed: ((context) => launchUrl(_sourceLink)),
              )
            ]),
        SettingsSection(
            title: Text(AppLocalizations.of(context)!.advancedSettings),
            tiles: [
              SettingsTile.switchTile(
                title: Text(AppLocalizations.of(context)!.crashReporting),
                description: Text(_isCrashReportingAvailable
                    ? AppLocalizations.of(context)!.crashRepostingDescription
                    : AppLocalizations.of(context)!.crashReportingNotAvailable),
                initialValue: _isCrashReportingAvailable == false
                    ? false
                    : _crashReportingSettingValue,
                enabled: _isCrashReportingAvailable,
                onToggle: (bool value) async {
                  await widget.sharedPreferences
                      .setBool("crashRepostsEnable", value);
                  log("Crash Reporting set to $value", name: "Settings Page");
                  setState(() {
                    _crashReportingSettingValue = value;
                  });
                },
              ),
              SettingsTile(
                title: Text(AppLocalizations.of(context)!.version),
                trailing: Text(widget.packageInfo.version),
              ),
              SettingsTile(
                title: Text(AppLocalizations.of(context)!.buildNumber),
                trailing: Text(widget.packageInfo.buildNumber),
              ),
            ])
      ]),
    );
  }
}
