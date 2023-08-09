import 'package:flutter/material.dart';
import '../classes/discover.dart' as discover_class; //çakışmayı önlemek için
import '../classes/send.dart';
import '../constants.dart';
import '../models.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

late AnimationController uploadAnimC;

class SendPage extends StatelessWidget {
  final bool isDark;
  const SendPage({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: Appbars.globalAppBar(isDark: isDark),
        body: const Center(child: SendPageInner()));
  }
}

class SendPageInner extends StatefulWidget {
  const SendPageInner({super.key});
  @override
  State<SendPageInner> createState() => _SendPageInnerState();
}

class _SendPageInnerState extends State<SendPageInner>
    with TickerProviderStateMixin {
  int _uiState = 1;
  late Future<void> discover;
  late List<Device> ipList;

  set uiState(int uiState) => setState(() => _uiState = uiState);

  @override
  void initState() {
    uploadAnimC = AnimationController(vsync: this)
      ..addListener(() {
        setState(() {});
      });
    discover = discover_class.Discover.discover().then((ips) {
      ipList = ips;
      uiState = 6;
    }).catchError((_) {
      uiState = 5; //Herhangi bir hatada bir ağa bağlı olmadığı varsayılıyor
    });
    super.initState();
  }

  @override
  void dispose() {
    discover.ignore();
    uploadAnimC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_uiState) {
      case 2:
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(AppLocalizations.of(context)!.fileUploading),
            LinearProgressIndicator(
              value: uploadAnimC.value,
              minHeight: 10,
            ),
          ]),
        );
      case 3:
        return Text(
          AppLocalizations.of(context)!.filesSent,
          textAlign: TextAlign.center,
        );
      case 7:
        return Text(
          AppLocalizations.of(context)!.unknownError,
          textAlign: TextAlign.center,
        );
      case 1:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(AppLocalizations.of(context)!.scanningNetwork),
            Assets.wifi,
          ],
        );
      case 5:
        return Text(
          AppLocalizations.of(context)!.notConnectedToNetwork,
          textAlign: TextAlign.center,
        );
      case 6: //ip listesi tarandı
        if (ipList.isEmpty) {
          return Text(
            AppLocalizations.of(context)!.noReceiverDeviceFound,
            textAlign: TextAlign.center,
          );
        } else {
          return ListView.builder(
              itemCount: ipList.length,
              itemBuilder: (context, index) {
                final device = ipList[index];
                return ListTile(
                  title: Text(device.code.toString()),
                  leading: const Icon(Icons.phone_android),
                  onTap: () {
                    _send(device);
                  },
                );
              });
        }
      default:
        throw Error();
    }
  }

  Future<void> _send(Device device) async {
    final file = await Send.filePick();
    if (file != null) {
      uiState = 2;
      Send.send(device, file).catchError((err) {
        switch (err) {
          case "ip error":
            uiState = 5;
            break;
          default:
            uiState = 7;
        }
      }).then((_) => uiState = 3);
    }
  }
}