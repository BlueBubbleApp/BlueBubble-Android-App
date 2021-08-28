import 'dart:io';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_launcher/map_launcher.dart' as ML;

class LocationWidget extends StatelessWidget {
  LocationWidget({
    Key? key,
    required this.file,
    required this.attachment,
  }) : super(key: key);
  final File file;
  final Attachment attachment;

  AppleLocation? loadLocation() {
    String _location = file.readAsStringSync();
    return AttachmentHelper.parseAppleLocation(_location);
  }

  void openMaps(AppleLocation? location) async {
    if (location == null) return;
    final availableMaps = await ML.MapLauncher.installedMaps;

    await availableMaps.first.showMarker(
      coords: ML.Coords(location.longitude!, location.latitude!),
      title: "Shared Location",
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = loadLocation();
    if (location != null &&
        location.longitude != null &&
        location.longitude!.abs() < 90 &&
        location.latitude != null) {
      return GestureDetector(
          onTap: () => openMaps(location),
          child: Container(
              height: 240,
              color: Theme.of(context).accentColor,
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                        height: 200,
                        child: FlutterMap(
                          options: MapOptions(
                            center: LatLng(location.longitude!, location.latitude!),
                            zoom: 14.0,
                          ),
                          layers: [
                            new TileLayerOptions(
                              urlTemplate: "http://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}",
                              subdomains: ['0', '1', '2', '3'],
                              tileSize: 256,
                            ),
                            new MarkerLayerOptions(
                              markers: [
                                new Marker(
                                  width: 40.0,
                                  height: 40.0,
                                  point: new LatLng(location.longitude!, location.latitude!),
                                  builder: (ctx) => new Container(
                                    child: Icon(Icons.pin_drop, color: Colors.red, size: 45),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )),
                    InkWell(
                        onTap: () => openMaps(location),
                        child: Padding(
                            padding: EdgeInsets.only(top: 11, bottom: 10),
                            child: Text("Open in Maps", style: Theme.of(context).textTheme.bodyText1)))
                  ])));
    } else {
      return Container(
        padding: EdgeInsets.all(10),
        child: Text(
          "Could not load location",
          style: Theme.of(context).textTheme.bodyText1,
        ),
      );
    }
  }
}
