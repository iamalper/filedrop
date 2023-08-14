import 'dart:convert';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:network_tools/network_tools.dart';
import '../constants.dart';
import 'package:http/http.dart' as http;
import '../models.dart';

class Discover {
  ///Search local network for devices which is listening for match.
  ///
  ///[port] is the target port. It should not set unless testing.
  ///
  ///Throws `ip error` if can't get own ip adress or didn't connected to a local network.
  ///Can't discover the devices currently downloading files from another device.
  ///
  ///Returns the list of available devices.
  static Future<List<Device>> discover({int port = Constants.port}) async {
    final ip = await getMyIp();
    final String subnet = ip.substring(0, ip.lastIndexOf('.'));
    final client = http.Client();
    final List<Device> ips = [];
    await for (var activeHost in HostScanner.scanDevicesForSinglePort(
      subnet,
      port,
    )) {
      try {
        final response =
            await client.get(Uri.http("${activeHost.address}:$port"));
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json["mesaj"] == Constants.meeting) {
            ips.add(Device(
                adress: activeHost.address,
                code: json["code"] as int,
                port: port));
          }
        }
      } catch (_) {
        continue;
      }
    }
    return ips;
  }

  ///Gets local network ip adress
  ///
  ///Throws `ip error` if can't get own ip adress or didn't connected to a local network.
  static Future<String> getMyIp() async {
    final ip = await NetworkInfo().getWifiIP();
    if (ip == null) {
      throw "ip error";
    }
    return ip;
  }
}
