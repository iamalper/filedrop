import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:num_remap/num_remap.dart';
import 'package:weepy/classes/exceptions.dart';
import 'package:weepy/files_riverpod.dart';
import '../classes/discover.dart' as discover_class; //for prevent collusion
import '../classes/sender.dart';
import '../classes/workers/isolated_sender.dart';
import '../constants.dart';
import '../models.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UiState { scanning, select, sending, complete, error }

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

class SendPageInner extends ConsumerStatefulWidget {
  const SendPageInner({super.key});
  @override
  ConsumerState<SendPageInner> createState() => _SendPageInnerState();
}

class _SendPageInnerState extends ConsumerState<SendPageInner>
    with TickerProviderStateMixin {
  late final _sender = switch (defaultTargetPlatform) {
    TargetPlatform.android => IsolatedSender(onUploadProgress: _updateProgress),
    _ => Sender(onUploadProgress: _updateProgress)
  };

  void _updateProgress(double percent) {
    final mappedValue = percent.remapAndClamp(
        0.0, 1.0, Assets.uploadAnimStart, Assets.uploadAnimEnd);
    assert(mappedValue <= Assets.uploadAnimEnd &&
        mappedValue >= Assets.uploadAnimStart);
    _uploadAnimC.animateTo(mappedValue.toDouble());
  }

  List<Device> _devices = [];

  //Don't make final, controller must reinitialized at initState
  late AnimationController _uploadAnimC;

  late String _errorMessage;
  late final animation = Assets.upload(_uploadAnimC, (composition) {
    _uploadAnimC.duration = composition.duration;
  });

  UiState get uiState => _uiState;
  var _uiState = UiState.scanning;

  ///Update current widget state
  set uiState(UiState uiState) {
    if (mounted) {
      setState(() => _uiState = uiState);
    }
  }

  @override
  void initState() {
    _uploadAnimC = AnimationController(
        vsync: this,
        debugLabel: "Upload Animation Controller",
        duration: const Duration(seconds: 1))
      ..addListener(() {
        setState(() {});
      });
    super.initState();
    _discover();
  }

  Future<void> _discover() async {
    try {
      while (_devices.isEmpty) {
        _devices = await discover_class.Discover.discover();
      }
      uiState = UiState.select;
    } on FileDropException catch (e) {
      if (context.mounted) {
        _errorMessage = e.getErrorMessage(AppLocalizations.of(context)!);
        uiState = UiState.error;
      }
    }
  }

  @override
  void dispose() {
    _uploadAnimC.dispose();
    _sender.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (uiState) {
      case UiState.sending:
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(AppLocalizations.of(context)!.fileUploading),
            animation,
          ]),
        );
      case UiState.complete:
        return Text(
          AppLocalizations.of(context)!.filesSent,
          textAlign: TextAlign.center,
        );
      case UiState.error:
        return Text(
          _errorMessage,
          textAlign: TextAlign.center,
        );
      case UiState.scanning:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(AppLocalizations.of(context)!.scanningNetwork),
            Assets.wifi,
          ],
        );

      case UiState.select: //network scanned
        if (_devices.isEmpty) {
          //Obsolete, discovery loops until a device found.
          return Text(
            AppLocalizations.of(context)!.noReceiverDeviceFound,
            textAlign: TextAlign.center,
          );
        } else {
          return ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];
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
    final file = await _sender.filePick();
    if (file != null) {
      uiState = UiState.sending;
      try {
        _uploadAnimC.animateTo(Assets.uploadAnimStart);
        await _sender.send(device, file);
        final filesNotifier = ref.read(filesProvider.notifier);
        await filesNotifier.addFiles(file
            .map((e) => DbFile(
                name: e.name,
                path: e.path!,
                time: DateTime.now(),
                fileStatus: DbFileStatus.upload))
            .toList());
        uiState = UiState.complete;
      } on FileDropException catch (e) {
        if (context.mounted) {
          _errorMessage = e.getErrorMessage(AppLocalizations.of(context)!);
          uiState = UiState.error;
        }
      }
    }
  }
}
