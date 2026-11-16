import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'app_translation.dart';

typedef Text = LocalizedText;

/// A small OpenStreetMap tile preview with proper attribution. Tapping it is
/// handled by the caller so the same box can open the full location in Maps.
class MerchantMapPreview extends StatelessWidget {
  const MerchantMapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.location,
    required this.onTap,
    this.height = 160,
  });

  final double latitude;
  final double longitude;
  final String location;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const zoom = 15;
      const tileSize = 256.0;
      final scale = math.pow(2.0, zoom).toDouble();
      final radians =
          latitude.clamp(-85.0511, 85.0511).toDouble() * math.pi / 180;
      final worldX = ((longitude + 180) / 360) * scale;
      final worldY =
          (1 - math.log(math.tan(radians) + 1 / math.cos(radians)) / math.pi) /
          2 *
          scale;
      final centerTileX = worldX.floor();
      final centerTileY = worldY.floor();
      final tileCount = scale.toInt();
      final tiles = <Widget>[];

      for (var y = centerTileY - 1; y <= centerTileY + 1; y++) {
        if (y < 0 || y >= tileCount) continue;
        for (var x = centerTileX - 2; x <= centerTileX + 2; x++) {
          final wrappedX = ((x % tileCount) + tileCount) % tileCount;
          tiles.add(
            Positioned(
              left: (x - worldX) * tileSize + constraints.maxWidth / 2,
              top: (y - worldY) * tileSize + height / 2,
              width: tileSize,
              height: tileSize,
              child: Image.network(
                'https://tile.openstreetmap.org/$zoom/$wrappedX/$y.png',
                fit: BoxFit.cover,
                headers: const {'User-Agent': 'MekenetEkub/1.0'},
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0xFFDCECE5),
                  child: Center(child: Icon(Icons.map_outlined)),
                ),
              ),
            ),
          );
        }
      }

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: height,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Stack(clipBehavior: Clip.hardEdge, children: tiles),
                ),
                const Center(
                  child: Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFF168A67),
                    size: 42,
                    shadows: [Shadow(color: Colors.white, blurRadius: 8)],
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(220),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Text(
                        '© OpenStreetMap contributors',
                        style: TextStyle(fontSize: 9, color: Colors.black87),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 9,
                  right: 9,
                  bottom: 9,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(238),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          color: Color(0xFF277E68),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const Icon(Icons.open_in_new, size: 17),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
