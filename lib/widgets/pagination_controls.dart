import 'package:flutter/material.dart';

class PaginationControls extends StatelessWidget {
  const PaginationControls({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.pageSizeOptions,
    required this.onPageChange,
    required this.onPageSizeChange,
    required this.primaryColor,
    this.compact = false,
    this.showPageSizeSelector = true,
  });

  final int currentPage;
  final int totalPages;
  final int pageSize;
  final List<int> pageSizeOptions;
  final ValueChanged<int> onPageChange;
  final ValueChanged<int> onPageSizeChange;
  final Color primaryColor;
  final bool compact;
  final bool showPageSizeSelector;

  List<int> _visiblePageNumbers() {
    if (totalPages <= 0) return [0];
    if (totalPages <= 3) return List.generate(totalPages, (index) => index);

    int start = currentPage - 1;
    if (start < 0) start = 0;
    if (start > totalPages - 3) start = totalPages - 3;
    return [start, start + 1, start + 2];
  }

  @override
  Widget build(BuildContext context) {
    final visiblePages = _visiblePageNumbers();

    final double circleSize = compact ? 40 : 46;
    final double iconSize = compact ? 18 : 22;
    final EdgeInsetsGeometry containerPadding =
        compact ? const EdgeInsets.symmetric(vertical: 6, horizontal: 10) : const EdgeInsets.symmetric(vertical: 12, horizontal: 16);
    final EdgeInsetsGeometry badgeSpacing = compact ? const EdgeInsets.symmetric(horizontal: 4) : const EdgeInsets.symmetric(horizontal: 6);
    final double infoSpacing = compact ? 6 : 10;
    final double fontSize = compact ? 13 : 14;

    return Column(
      children: [
        Container(
          padding: containerPadding,
          decoration: compact
              ? null
              : BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _paginationArrow(
                      icon: Icons.chevron_left,
                      enabled: currentPage > 0,
                      onTap: () => onPageChange(currentPage - 1),
                      size: circleSize,
                      iconSize: iconSize),
                  SizedBox(width: compact ? 8 : 12),
                  ...visiblePages.map(
                    (pageIndex) => Padding(
                      padding: badgeSpacing,
                      child: _pageBadge(
                        pageIndex,
                        isActive: pageIndex == currentPage,
                        size: circleSize,
                        fontSize: fontSize,
                        primaryColor: primaryColor,
                        onTap: () => onPageChange(pageIndex),
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 12),
                  _paginationArrow(
                      icon: Icons.chevron_right,
                      enabled: currentPage < totalPages - 1,
                      onTap: () => onPageChange(currentPage + 1),
                      size: circleSize,
                      iconSize: iconSize),
                ],
              ),
              SizedBox(height: infoSpacing),
              Text(
                'Página ${totalPages == 0 ? 0 : currentPage + 1} de $totalPages',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                  fontSize: compact ? 12 : null,
                ),
              ),
            ],
          ),
        ),
        if (showPageSizeSelector) ...[
          SizedBox(height: compact ? 6 : 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Itens por página',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                  fontSize: compact ? 12 : null,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: compact
                    ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
                    : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: compact ? Colors.transparent : Colors.white,
                  borderRadius: BorderRadius.circular(compact ? 10 : 12),
                  border: Border.all(color: primaryColor, width: compact ? 1 : 1.2),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: pageSize,
                    icon: Icon(Icons.arrow_drop_down, color: primaryColor, size: compact ? 22 : null),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    items: pageSizeOptions
                        .map(
                          (size) => DropdownMenuItem<int>(
                            value: size,
                            child: Text(
                              '$size',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w700,
                                fontSize: compact ? 13 : null,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) onPageSizeChange(value);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _paginationArrow(
      {required IconData icon, required bool enabled, required VoidCallback onTap, double size = 46, double iconSize = 22}) {
    final Color color = enabled ? primaryColor : Colors.grey[400]!;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? primaryColor.withValues(alpha: 0.08) : Colors.grey[200],
          border: Border.all(color: color, width: 1.4),
        ),
        child: Icon(icon, color: color, size: iconSize),
      ),
    );
  }

  Widget _pageBadge(int pageIndex,
      {required bool isActive, required double size, required double fontSize, required Color primaryColor, required VoidCallback onTap}) {
    final Color borderColor = isActive ? primaryColor : Colors.grey[400]!;
    final Color textColor = isActive ? primaryColor : Colors.grey[700]!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? primaryColor.withValues(alpha: 0.14) : Colors.white,
          border: Border.all(color: borderColor, width: 1.4),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '${pageIndex + 1}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: textColor,
            fontSize: fontSize,
          ),
        ),
      ),
    );
  }
}
