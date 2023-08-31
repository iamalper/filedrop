import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:settings_ui/settings_ui.dart';
import '../constants.dart';
import 'package:flutter_store_listing/flutter_store_listing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsPage extends StatelessWidget {
  final bool isDark;
  final PackageInfo packageInfo;
  const SettingsPage(
      {super.key, required this.isDark, required this.packageInfo});

  @override
  Widget build(BuildContext context) {
    Uri sourceLink;
    try {
      sourceLink =
          Uri.parse(FirebaseRemoteConfig.instance.getString("sourceLink"));
    } on FirebaseException catch (_) {
      sourceLink = Uri.parse("https://github.com/iamalper/filedrop");
    }
    return Scaffold(
      appBar: Appbars.globalAppBar(isDark: isDark),
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
                      launchUrl(sourceLink);
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
                          List<String>.from(sourceLink.pathSegments);
                      uriSegments.add("issues");
                      final issuesLink =
                          sourceLink.replace(pathSegments: uriSegments);
                      launchUrl(issuesLink);
                    }
                  }),
              SettingsTile.navigation(
                title: Text(AppLocalizations.of(context)!.publicGithubRepo),
                value: Text(sourceLink.toString()),
                onPressed: ((context) => launchUrl(sourceLink)),
              )
            ]),
        SettingsSection(
            title: Text(AppLocalizations.of(context)!.advancedSettings),
            tiles: [
              SettingsTile(
                title: Text(AppLocalizations.of(context)!.version),
                trailing: Text(packageInfo.version),
              ),
              SettingsTile(
                title: Text(AppLocalizations.of(context)!.buildNumber),
                trailing: Text(packageInfo.buildNumber),
              ),
            ])
      ]),
    );
  }
}
