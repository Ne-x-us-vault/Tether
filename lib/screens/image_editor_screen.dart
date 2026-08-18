import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

enum EditorMode { draw, cropRotate }

class DrawingPath {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  DrawingPath({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });
}

class DrawPainter extends CustomPainter {
  final List<DrawingPath> paths;

  DrawPainter({required this.paths});

  @override
  void paint(Canvas canvas, Size size) {
    for (final path in paths) {
      final paint = Paint()
        ..color = path.color
        ..strokeWidth = path.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (path.points.isEmpty) continue;
      if (path.points.length == 1) {
        canvas.drawCircle(
          path.points.first,
          path.strokeWidth / 2,
          paint..style = PaintingStyle.fill,
        );
      } else {
        final p = Path();
        p.moveTo(path.points.first.dx, path.points.first.dy);
        for (int i = 1; i < path.points.length; i++) {
          p.lineTo(path.points[i].dx, path.points[i].dy);
        }
        canvas.drawPath(p, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DrawPainter oldDelegate) =>
      oldDelegate.paths.length != paths.length ||
      oldDelegate.paths != paths;
}

// Sleek Crop overlay custom painter that draws a dark semi-transparent mask and corner anchors
class CropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  CropOverlayPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final maskPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    // Dark transparent mask outside crop rectangle
    canvas.drawRect(Rect.fromLTRB(0, 0, cropRect.left, size.height), maskPaint);
    canvas.drawRect(Rect.fromLTRB(cropRect.right, 0, size.width, size.height), maskPaint);
    canvas.drawRect(Rect.fromLTRB(cropRect.left, 0, cropRect.right, cropRect.top), maskPaint);
    canvas.drawRect(Rect.fromLTRB(cropRect.left, cropRect.bottom, cropRect.right, size.height), maskPaint);

    // Glowing border around selection area
    final borderPaint = Paint()
      ..color = const Color(0xFF3797F0)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(cropRect, borderPaint);

    // Thick custom corner brackets
    final handlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    const len = 18.0;
    // Top-Left corner
    canvas.drawLine(Offset(cropRect.left, cropRect.top), Offset(cropRect.left + len, cropRect.top), handlePaint);
    canvas.drawLine(Offset(cropRect.left, cropRect.top), Offset(cropRect.left, cropRect.top + len), handlePaint);

    // Top-Right corner
    canvas.drawLine(Offset(cropRect.right, cropRect.top), Offset(cropRect.right - len, cropRect.top), handlePaint);
    canvas.drawLine(Offset(cropRect.right, cropRect.top), Offset(cropRect.right, cropRect.top + len), handlePaint);

    // Bottom-Left corner
    canvas.drawLine(Offset(cropRect.left, cropRect.bottom), Offset(cropRect.left + len, cropRect.bottom), handlePaint);
    canvas.drawLine(Offset(cropRect.left, cropRect.bottom), Offset(cropRect.left, cropRect.bottom - len), handlePaint);

    // Bottom-Right corner
    canvas.drawLine(Offset(cropRect.right, cropRect.bottom), Offset(cropRect.right - len, cropRect.bottom), handlePaint);
    canvas.drawLine(Offset(cropRect.right, cropRect.bottom), Offset(cropRect.right, cropRect.bottom - len), handlePaint);
  }

  @override
  bool shouldRepaint(covariant CropOverlayPainter oldDelegate) => oldDelegate.cropRect != cropRect;
}

class IGImageEditorScreen extends StatefulWidget {
  final String imagePath;

  const IGImageEditorScreen({super.key, required this.imagePath});

  @override
  IGImageEditorScreenState createState() => IGImageEditorScreenState();
}

class IGImageEditorScreenState extends State<IGImageEditorScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  final List<DrawingPath> _paths = [];

  // Editor mode toggle
  EditorMode _mode = EditorMode.draw;

  // Rotation parameters
  int _quarterTurns = 0;

  // Symmetrical Cropping variables (fraction values)
  double _cropSidesFraction = 0.0;     // 0.0 to 0.45 (Cuts left & right sides)
  double _cropTopBottomFraction = 0.0; // 0.0 to 0.45 (Cuts top & bottom)
  double _shiftFraction = 0.0;         // -1.0 to 1.0 (Shifts crop frame left/right or up/down)
  


  // Image dimension resolver parameters
  bool _isLoadingImage = true;
  double _imageWidth = 0.0;
  double _imageHeight = 0.0;
  double _imageAspectRatio = 1.0;

  Color _selectedColor = const Color(0xFF3797F0); // light blue accent
  double _strokeWidth = 6.0;

  final List<Color> _colors = [
    const Color(0xFF3797F0), // blue
    const Color(0xFF7C5FCC), // purple
    const Color(0xFFFF2D55), // pink
    const Color(0xFFFF9500), // orange
    const Color(0xFFFFCC00), // yellow
    const Color(0xFF4CD964), // green
    const Color(0xFFFFFFFF), // white
    const Color(0xFF000000), // black
  ];

  final List<double> _sizes = [3.0, 6.0, 12.0, 20.0];

  @override
  void initState() {
    super.initState();
    _loadImageMetadata();
  }

  // Natively resolves the image metadata to size the cropping bounds exactly to the image aspect ratio
  void _loadImageMetadata() {
    final imageProvider = FileImage(File(widget.imagePath));
    final stream = imageProvider.resolve(const ImageConfiguration());
    
    stream.addListener(ImageStreamListener((ImageInfo info, bool _) {
      if (mounted) {
        setState(() {
          _imageWidth = info.image.width.toDouble();
          _imageHeight = info.image.height.toDouble();
          _imageAspectRatio = _imageWidth / _imageHeight;
          _isLoadingImage = false;
        });
      }
    }, onError: (dynamic error, StackTrace? stackTrace) {
      if (mounted) {
        setState(() => _isLoadingImage = false);
      }
    }));
  }

  @override
  Widget build(BuildContext context) {
    // Aspect ratio flips when rotated 90 or 270 degrees (odd quarter turns)
    final currentAspectRatio = (_quarterTurns % 2 == 0) ? _imageAspectRatio : (1.0 / _imageAspectRatio);

    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      body: _isLoadingImage
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3797F0)),
              ),
            )
          : Stack(
              children: [
                // Editor Main Canvas Workspace
                Positioned.fill(
                  child: SafeArea(
                    child: Column(
                      children: [
                        // Dynamic crop/draw area fitting image aspect ratio perfectly
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                              child: AspectRatio(
                                aspectRatio: currentAspectRatio,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {


                                    // Calculate Crop coordinates using sliders fractions
                                    final double cropWidthFraction = 1.0 - (_cropSidesFraction * 2);
                                    final double cropHeightFraction = 1.0 - (_cropTopBottomFraction * 2);

                                    final double maxShiftX = _cropSidesFraction;
                                    final double maxShiftY = _cropTopBottomFraction;

                                    double shiftX = 0.0;
                                    double shiftY = 0.0;

                                    // Shift in the direction of the dominant crop to make framing intuitive
                                    if (_cropSidesFraction >= _cropTopBottomFraction) {
                                      shiftX = _shiftFraction * maxShiftX;
                                    } else {
                                      shiftY = _shiftFraction * maxShiftY;
                                    }

                                    final double centerX = 0.5 + shiftX;
                                    final double centerY = 0.5 + shiftY;

                                    final double cropLeft = (centerX - cropWidthFraction / 2) * constraints.maxWidth;
                                    final double cropRight = (centerX + cropWidthFraction / 2) * constraints.maxWidth;
                                    final double cropTop = (centerY - cropHeightFraction / 2) * constraints.maxHeight;
                                    final double cropBottom = (centerY + cropHeightFraction / 2) * constraints.maxHeight;

                                    return Stack(
                                      children: [
                                        // Rotatable capture area containing image and drawings
                                        // RepaintBoundary placed OUTSIDE RotatedBox so rotation is rendered perfectly inside saved pixel bytes
                                        Positioned.fill(
                                          child: RepaintBoundary(
                                            key: _repaintKey,
                                            child: RotatedBox(
                                              quarterTurns: _quarterTurns,
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(4),
                                                child: Stack(
                                                  children: [
                                                    // Background photo (non-positioned to size the Stack perfectly)
                                                    Image.file(
                                                      File(widget.imagePath),
                                                      fit: BoxFit.cover,
                                                    ),
                                                    // Drawing Canvas
                                                    Positioned.fill(
                                                      child: GestureDetector(
                                                        onPanStart: _mode == EditorMode.draw
                                                            ? (details) {
                                                                setState(() {
                                                                  _paths.add(DrawingPath(
                                                                    points: [details.localPosition],
                                                                    color: _selectedColor,
                                                                    strokeWidth: _strokeWidth,
                                                                  ));
                                                                });
                                                              }
                                                            : null,
                                                        onPanUpdate: _mode == EditorMode.draw
                                                            ? (details) {
                                                                if (_paths.isNotEmpty) {
                                                                  setState(() {
                                                                    _paths.last.points.add(details.localPosition);
                                                                  });
                                                                }
                                                              }
                                                            : null,
                                                        child: CustomPaint(
                                                          painter: DrawPainter(paths: _paths),
                                                          size: Size.infinite,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Crop frame overlay mask (only visible in cropRotate mode)
                                        if (_mode == EditorMode.cropRotate)
                                          Positioned.fill(
                                            child: IgnorePointer(
                                              child: CustomPaint(
                                                painter: CropOverlayPainter(
                                                  cropRect: Rect.fromLTRB(cropLeft, cropTop, cropRight, cropBottom),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Mode Selector Ribbon (Draw vs Crop & Rotate)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              // Draw Mode Button
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _mode = EditorMode.draw),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _mode == EditorMode.draw
                                          ? const Color(0xFF2E2E2E)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.brush_rounded,
                                          color: _mode == EditorMode.draw ? const Color(0xFF3797F0) : Colors.white54,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Draw',
                                          style: TextStyle(
                                            color: _mode == EditorMode.draw ? Colors.white : Colors.white54,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Crop & Rotate Mode Button
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _mode = EditorMode.cropRotate),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _mode == EditorMode.cropRotate
                                          ? const Color(0xFF2E2E2E)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.crop_rotate_rounded,
                                          color: _mode == EditorMode.cropRotate ? const Color(0xFF3797F0) : Colors.white54,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Crop & Rotate',
                                          style: TextStyle(
                                            color: _mode == EditorMode.cropRotate ? Colors.white : Colors.white54,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Contextual Bottom Controls Panel
                        Container(
                          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141414).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _mode == EditorMode.draw
                                ? _buildDrawControls()
                                : _buildCropRotateControls(currentAspectRatio),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Absolute Header Control Panel
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back/Cancel Button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                              width: 0.8,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back_ios, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Cancel',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Right side Actions (Send original vs annotated)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Send Original Clean Photo
                          GestureDetector(
                            onTap: () => Navigator.pop(context, widget.imagePath),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  width: 0.8,
                                ),
                              ),
                              child: const Text(
                                'Send Original',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),

                          // Send Edited/Cropped/Rotated version
                          GestureDetector(
                            onTap: _saveAndSend,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF3797F0), Color(0xFF7C5FCC)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7C5FCC).withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Send',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.send_rounded, color: Colors.white, size: 14),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // Drawing tools subpanel
  Widget _buildDrawControls() {
    return Column(
      key: const ValueKey('drawControls'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Color row picker
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _colors.length,
            itemBuilder: (context, index) {
              final color = _colors[index];
              final isSelected = color == _selectedColor;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.2),
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Brush size selector and undo utilities
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: _sizes.map((size) {
                final isSelected = size == _strokeWidth;
                return GestureDetector(
                  onTap: () => setState(() => _strokeWidth = size),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: size + 4,
                        height: size + 4,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.undo, color: Colors.white70),
                  tooltip: 'Undo stroke',
                  onPressed: () {
                    if (_paths.isNotEmpty) {
                      setState(() => _paths.removeLast());
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: 'Clear drawings',
                  onPressed: () {
                    if (_paths.isNotEmpty) {
                      setState(() => _paths.clear());
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // Handy Crop & rotate tools subpanel using symmetrical sliders and quick aspect ratios
  Widget _buildCropRotateControls(double currentAspectRatio) {
    final bool isCropped = _cropSidesFraction > 0.0 || _cropTopBottomFraction > 0.0;

    return Column(
      key: const ValueKey('cropControls'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Quick Presets Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildPresetButton('Full', () {
              setState(() {
                _cropSidesFraction = 0.0;
                _cropTopBottomFraction = 0.0;
                _shiftFraction = 0.0;
              });
            }),
            _buildPresetButton('1:1', () {
              setState(() {
                _shiftFraction = 0.0;
                if (currentAspectRatio > 1.0) {
                  _cropSidesFraction = ((1.0 - (1.0 / currentAspectRatio)) / 2).clamp(0.0, 0.45);
                  _cropTopBottomFraction = 0.0;
                } else {
                  _cropTopBottomFraction = ((1.0 - currentAspectRatio) / 2).clamp(0.0, 0.45);
                  _cropSidesFraction = 0.0;
                }
              });
            }),
            _buildPresetButton('4:3', () {
              setState(() {
                _shiftFraction = 0.0;
                const ratio = 4.0 / 3.0;
                if (currentAspectRatio > ratio) {
                  _cropSidesFraction = ((1.0 - (ratio / currentAspectRatio)) / 2).clamp(0.0, 0.45);
                  _cropTopBottomFraction = 0.0;
                } else {
                  _cropTopBottomFraction = ((1.0 - (currentAspectRatio / ratio)) / 2).clamp(0.0, 0.45);
                  _cropSidesFraction = 0.0;
                }
              });
            }),
            _buildPresetButton('16:9', () {
              setState(() {
                _shiftFraction = 0.0;
                const ratio = 16.0 / 9.0;
                if (currentAspectRatio > ratio) {
                  _cropSidesFraction = ((1.0 - (ratio / currentAspectRatio)) / 2).clamp(0.0, 0.45);
                  _cropTopBottomFraction = 0.0;
                } else {
                  _cropTopBottomFraction = ((1.0 - (currentAspectRatio / ratio)) / 2).clamp(0.0, 0.45);
                  _cropSidesFraction = 0.0;
                }
              });
            }),
            // Rotate Button
            IconButton(
              icon: const Icon(Icons.rotate_right_rounded, color: Colors.white, size: 22),
              tooltip: 'Rotate 90°',
              onPressed: () {
                setState(() {
                  _quarterTurns = (_quarterTurns + 1) % 4;
                  _cropSidesFraction = 0.0;
                  _cropTopBottomFraction = 0.0;
                  _shiftFraction = 0.0;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 1. Crop Width Slider
        _buildSliderRow(
          icon: Icons.swap_horiz_rounded,
          label: 'Crop Width',
          value: _cropSidesFraction,
          onChanged: (val) => setState(() => _cropSidesFraction = val),
        ),

        // 2. Crop Height Slider
        _buildSliderRow(
          icon: Icons.swap_vert_rounded,
          label: 'Crop Height',
          value: _cropTopBottomFraction,
          onChanged: (val) => setState(() => _cropTopBottomFraction = val),
        ),

        // 3. Shift Slider (only active if cropped)
        AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: isCropped ? 1.0 : 0.4,
          child: _buildSliderRow(
            icon: Icons.pan_tool_rounded,
            label: 'Shift Frame',
            value: _shiftFraction,
            min: -1.0,
            max: 1.0,
            onChanged: isCropped ? (val) => setState(() => _shiftFraction = val) : (_) {},
          ),
        ),
      ],
    );
  }

  Widget _buildPresetButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04), width: 0.8),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required IconData icon,
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    double min = 0.0,
    double max = 0.45,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 16),
          const SizedBox(width: 10),
          SizedBox(
            width: 75,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF3797F0),
                inactiveTrackColor: Colors.white10,
                thumbColor: Colors.white,
                trackHeight: 3.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Native custom painting engine crops, flattens drawings, and rotates the result seamlessly
  Future<void> _saveAndSend() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) {
          Navigator.pop(context, widget.imagePath);
        }
        return;
      }

      // Convert full boundary drawings + background into high-definition picture
      final sourceImage = await boundary.toImage(pixelRatio: 2.0);

      // Recompute Crop fractions to match canvas bounds
      final double cropWidthFraction = 1.0 - (_cropSidesFraction * 2);
      final double cropHeightFraction = 1.0 - (_cropTopBottomFraction * 2);

      final double maxShiftX = _cropSidesFraction;
      final double maxShiftY = _cropTopBottomFraction;

      double shiftX = 0.0;
      double shiftY = 0.0;

      if (_cropSidesFraction >= _cropTopBottomFraction) {
        shiftX = _shiftFraction * maxShiftX;
      } else {
        shiftY = _shiftFraction * maxShiftY;
      }

      final double centerX = 0.5 + shiftX;
      final double centerY = 0.5 + shiftY;

      final double finalLeftFraction = centerX - cropWidthFraction / 2;
      final double finalTopFraction = centerY - cropHeightFraction / 2;

      // Map visible crop bounds to physical captured pixel coordinates
      final int cropX = (finalLeftFraction * sourceImage.width).round().clamp(0, sourceImage.width - 1);
      final int cropY = (finalTopFraction * sourceImage.height).round().clamp(0, sourceImage.height - 1);
      final int cropW = (cropWidthFraction * sourceImage.width).round().clamp(1, sourceImage.width - cropX);
      final int cropH = (cropHeightFraction * sourceImage.height).round().clamp(1, sourceImage.height - cropY);

      // Perform fast native crop using canvas slice
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final srcRect = Rect.fromLTWH(cropX.toDouble(), cropY.toDouble(), cropW.toDouble(), cropH.toDouble());
      final dstRect = Rect.fromLTWH(0, 0, cropW.toDouble(), cropH.toDouble());

      canvas.drawImageRect(sourceImage, srcRect, dstRect, Paint());

      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(cropW, cropH);

      // Extract raw compressed PNG bytes
      final byteData =
          await finalImage.toByteData(format: ui.ImageByteFormat.png);
      sourceImage.dispose();
      finalImage.dispose();
      if (byteData == null) {
        if (mounted) {
          Navigator.pop(context, widget.imagePath);
        }
        return;
      }
      final bytes = byteData.buffer.asUint8List();

      // Write to custom marked up temporary file
      final tempDir = await getTemporaryDirectory();
      final finalPath = '${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(finalPath);
      await file.writeAsBytes(bytes);

      if (mounted) {
        Navigator.pop(context, finalPath);
      }
    } catch (e) {
      debugPrint('[IGEditor] Processing failed, falling back to original: $e');
      if (mounted) {
        Navigator.pop(context, widget.imagePath);
      }
    }
  }
}
