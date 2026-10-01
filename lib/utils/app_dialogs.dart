import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as Img;

class AppDialogs {
  static Future<void> showImageMatchDialog(
    BuildContext context, {
    required Img.Image imageA,
    required Img.Image imageB,
    required double confidence,
    String labelA = '',
    String labelB = '',
  }) async {
    print("im here");
    return await showDialog(
      context: context,
      builder: (_) => ImageMatchDialog(
        imageA: imageA,
        imageB: imageB,
        confidence: confidence.clamp(0, 100).toDouble(),
        labelA: labelA,
        labelB: labelB,
      ),
    );
  }

  static ImageProvider imgToProvider(Img.Image image, {int maxSize = 300}) {
    Img.Image img = image;
    return MemoryImage(image.getBytes()); // Uint8List
  }
}

class ImageMatchDialog extends StatelessWidget {
  const ImageMatchDialog({
    super.key,
    required this.imageA,
    required this.imageB,
    required this.confidence,
    this.labelA = 'Image 1',
    this.labelB = 'Image 2',
  });

  final Img.Image imageA;
  final Img.Image imageB;
  final double confidence; // 0 - 100
  final String labelA;
  final String labelB;

  Color get _color {
    if (confidence >= 0.80) return Colors.green;
    if (confidence >= 0.50) return Colors.orange;
    return Colors.red;
  }

  String get _verdict {
    if (confidence >= 0.80) return 'Strong match';
    if (confidence >= 0.50) return 'Possible match';
    return 'No match';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Comparison Result', style: theme.textTheme.titleLarge),
            const SizedBox(height: 24),

// Two circular images with a link icon between them
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CircleImage(image: imageA, label: labelA, borderColor: _color),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 32),
                  child: Icon(
                    confidence >= 50 ? Icons.compare_arrows : Icons.close,
                    color: _color,
                  ),
                ),
                _CircleImage(image: imageB, label: labelB, borderColor: _color),
              ],
            ),

            const SizedBox(height: 28),

// Confidence indicator (animated)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: confidence),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return SizedBox(
                  width: 110,
                  height: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: value,
                          strokeWidth: 9,
                          strokeCap: StrokeCap.round,
                          backgroundColor: _color.withOpacity(0.15),
                          valueColor: AlwaysStoppedAnimation(_color),
                        ),
                      ),
                      Text(
                        '${(value * 100).toStringAsFixed(1)}%',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _color,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 12),
            Text(
              _verdict,
              style: theme.textTheme.titleMedium?.copyWith(
                color: _color,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text('Matching confidence', style: theme.textTheme.bodySmall),

            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).popUntil((route)=>route.isFirst),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleImage extends StatelessWidget {
  const _CircleImage({
    required this.image,
    required this.label,
    required this.borderColor,
  });

  final Img.Image image;
  final String label;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 3),
          ),
          child: CircleAvatar(
            radius: 46,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: MemoryImage(Uint8List.fromList(Img.encodePng(image))),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
