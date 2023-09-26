import 'dart:convert';
import 'dart:developer';
import 'package:network_discovery/network_discovery.dart';
import 'package:weepy/classes/exceptions.dart';
import '../constants.dart';
import 'package:http/http.dart' as http;
import '../models.dart';

class Discover {
  ///Search local network for devices which is listening for match.
  ///
  ///Throws [IpException] if can't get own ip adress or didn't connected to a local network.
  ///Can't discover the devices currently downloading files from another device.
  ///
  ///Returns the list of available devices.
  static Future<List<Device>> discover() async {
    final ip = await getMyIp();
    final String subnet = ip.substring(0, ip.lastIndexOf('.'));
    final client = http.Client();
    final List<Device> ips = [];
    final discoverMultiplePorts = NetworkDiscovery.discoverMultiplePorts(subnet,
            [for (var i = Constants.minPort; i <= Constants.maxPort; i++) i])
        .handleError((_) {});
    await for (var activeHost in discoverMultiplePorts) {
      log("Host found ${activeHost.ip}", name: "Discovery");
      for (var openPort in activeHost.openPorts) {
        final port = openPort;
        final url = Uri.http("${activeHost.ip}:$port");
        log("Sending request to port $port", name: "Discovery");
        try {
          final response = await client.get(url);
          assert(response.statusCode == 200);
          final json = jsonDecode(response.body);
          assert(json["message"] == Constants.meeting);
          ips.add(Device(
              adress: activeHost.ip, code: json["code"] as int, port: port));
          log("Found FileDrop instance", name: "Discovery");
        } catch (_) {
          log("Port $port is not valid FileDrop instance", name: "Discovery");
          continue;
        }
      }
    }
    log("Discovery end", name: "Discovery");
    return ips;
  }

  ///Gets local network ip adress
  ///
  ///Throws [IpException] if can't get own ip adress or didn't connected to a local network.
  static Future<String> getMyIp() async {
    final ip = await NetworkDiscovery.discoverDeviceIpAddress();
    if (ip == "") {
      throw IpException();
    }
    return ip;
  }
}
