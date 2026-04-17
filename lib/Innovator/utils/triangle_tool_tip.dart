import 'package:flutter/material.dart';

class ArrowPopupMenu extends StatefulWidget {
  final List<PopupMenuEntry<String>> items;
  final Function(String) onSelected;

  const ArrowPopupMenu({
    super.key,
    required this.items,
    required this.onSelected,
  });

  @override
  State<ArrowPopupMenu> createState() => _ArrowPopupMenuState();
}

class _ArrowPopupMenuState extends State<ArrowPopupMenu> {
  OverlayEntry? _overlayEntry;
  final GlobalKey _key = GlobalKey();

  void _showMenu() {
    final RenderBox renderBox =
        _key.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder:
          (context) => GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _hideMenu,
            child: Stack(
              children: [
                Positioned(
                  left: offset.dx - 60, // adjust horizontal position
                  top: offset.dy + size.height + 5,
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ▲ Triangle arrow indicator
                        Padding(
                          padding: const EdgeInsets.only(left: 70),
                          child: CustomPaint(
                            size: const Size(16, 8),
                            painter: _TrianglePainter(),
                          ),
                        ),
                        // Popup box
                        Container(
                          width: 130,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _menuItem("Edit", Icons.edit_outlined),
                              const Divider(height: 1),
                              _menuItem("Delete", Icons.delete_outlined,
                                  isDestructive: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _menuItem(String label, IconData icon,
      {bool isDestructive = false}) {
    return InkWell(
      onTap: () {
        _hideMenu();
        widget.onSelected(label.toLowerCase());
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: isDestructive ? Colors.red : Colors.grey[700]),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isDestructive ? Colors.red : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _hideMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _key,
      onTap: _showMenu,
      child: const Icon(Icons.more_horiz, color: Colors.grey),
    );
  }
}

// Triangle painter for the arrow indicator
class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final path =
        Path()
          ..moveTo(0, size.height)
          ..lineTo(size.width / 2, 0)
          ..lineTo(size.width, size.height)
          ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}