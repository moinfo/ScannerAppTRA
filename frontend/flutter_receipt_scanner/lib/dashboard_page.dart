import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_receipt_scanner/l10n.dart';
import 'package:flutter_receipt_scanner/main.dart';
import 'package:flutter_receipt_scanner/utils/api_request_status.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const Color _primaryColor = Color(0xFF1565C0);

  /// Compact format: 1,234 → 1.2K, 1,234,567 → 1.2M, 1,234,567,890 → 1.2B
  static String _compact(double value) {
    if (value >= 1e9) {
      final v = value / 1e9;
      return v == v.roundToDouble()
          ? '${v.toInt()}B'
          : '${v.toStringAsFixed(1)}B';
    } else if (value >= 1e6) {
      final v = value / 1e6;
      return v == v.roundToDouble()
          ? '${v.toInt()}M'
          : '${v.toStringAsFixed(1)}M';
    } else if (value >= 1e3) {
      final v = value / 1e3;
      return v == v.roundToDouble()
          ? '${v.toInt()}K'
          : '${v.toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReceiptProvider>(
      builder: (context, provider, _) {
        final dash = provider.dashboardData;
        final isLoading = provider.dashboardStatus == APIRequestStatus.loading;

        // Outer cards data from API
        final outerCards = [
          _StatData(Icons.receipt_long, L.tr(context, 'stat_total_receipts'),
              '${dash.totalReceipts}', _primaryColor),
          _StatData(
              Icons.account_balance_wallet,
              L.tr(context, 'stat_total_amount'),
              _compact(dash.totalAmount),
              const Color(0xFF2E7D32)),
          _StatData(Icons.today, L.tr(context, 'stat_today_scans'),
              '${dash.todayScans}', const Color(0xFFE65100)),
          _StatData(
              Icons.analytics_outlined,
              L.tr(context, 'stat_avg_value'),
              _compact(dash.avgValue),
              const Color(0xFF6A1B9A)),
        ];

        // Center card data
        final centerCard = _StatData(
            Icons.price_change_outlined,
            L.tr(context, 'stat_total_tax'),
            _compact(dash.totalTax),
            const Color(0xFF00838F));

        final recentReceipts = dash.recentReceipts;

        return RefreshIndicator(
          onRefresh: () => provider.fetchDashboard(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
            children: [
              // Orbital stats layout
              if (isLoading)
                const SizedBox(
                  height: 340,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                _OrbitalStats(
                  outerCards: outerCards,
                  centerCard: centerCard,
                ),

              const SizedBox(height: 24),

              // Recent activity header
              Text(
                L.tr(context, 'dashboard_recent'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),

              if (recentReceipts.isEmpty && !isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text(
                          L.tr(context, 'stat_no_data'),
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...recentReceipts.asMap().entries.map(
                      (e) => ReceiptCard(receipt: e.value, index: e.key),
                    ),
            ],
          ),
        );
      },
    );
  }
}

// ── Data holder for stat cards ───────────────────────────────────────────────

class _StatData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatData(this.icon, this.label, this.value, this.color);
}

// ── Orbital layout: 4 cards around a circle, 1 in center ────────────────────

class _OrbitalStats extends StatelessWidget {
  const _OrbitalStats({
    required this.outerCards,
    required this.centerCard,
  });

  final List<_StatData> outerCards;
  final _StatData centerCard;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final containerWidth = constraints.maxWidth;
        // Total height for the orbital area
        const containerHeight = 340.0;
        // Size of outer cards
        const outerW = 130.0;
        const outerH = 84.0;
        // Size of center card
        const centerSize = 120.0;
        // Radius of the orbit
        final radius = (containerWidth - outerW) / 2 - 4;

        final centerX = containerWidth / 2;
        const centerY = containerHeight / 2;

        // Angles: top, right, bottom, left (starting at -90° so first is top)
        const angles = [-90.0, 0.0, 90.0, 180.0];

        return SizedBox(
          height: containerHeight,
          width: containerWidth,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Gradient background for glassmorphism blur effect
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.9,
                      colors: isDark
                          ? [
                              const Color(0xFF1565C0).withValues(alpha: 0.15),
                              const Color(0xFF6A1B9A).withValues(alpha: 0.08),
                              Colors.transparent,
                            ]
                          : [
                              const Color(0xFF1565C0).withValues(alpha: 0.08),
                              const Color(0xFF6A1B9A).withValues(alpha: 0.04),
                              Colors.transparent,
                            ],
                    ),
                  ),
                ),
              ),

              // Decorative orbit ring
              Positioned(
                left: centerX - radius,
                top: centerY - radius,
                child: Container(
                  width: radius * 2,
                  height: radius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white12
                          : Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              // 4 outer cards
              for (int i = 0; i < 4; i++)
                Positioned(
                  left: centerX +
                      radius * math.cos(angles[i] * math.pi / 180) -
                      outerW / 2,
                  top: centerY +
                      radius * math.sin(angles[i] * math.pi / 180) -
                      outerH / 2,
                  child: _SmallStatCard(
                    data: outerCards[i],
                    width: outerW,
                    height: outerH,
                  ),
                ),

              // Center card
              Positioned(
                left: centerX - centerSize / 2,
                top: centerY - centerSize / 2,
                child: _CenterStatCard(
                  data: centerCard,
                  size: centerSize,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Small outer stat card ────────────────────────────────────────────────────

class _SmallStatCard extends StatelessWidget {
  const _SmallStatCard({
    required this.data,
    required this.width,
    required this.height,
  });

  final _StatData data;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.55),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.8),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: data.color.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: data.color
                            .withValues(alpha: isDark ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(data.icon, size: 16, color: data.color),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        data.value,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: data.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  data.label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Center stat card (circular, prominent) ───────────────────────────────────

class _CenterStatCard extends StatelessWidget {
  const _CenterStatCard({
    required this.data,
    required this.size,
  });

  final _StatData data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(60),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(60),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.6),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.9),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: data.color.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: data.color
                        .withValues(alpha: isDark ? 0.25 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(data.icon, size: 20, color: data.color),
                ),
                const SizedBox(height: 6),
                Text(
                  data.value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: data.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  data.label,
                  style: TextStyle(
                    fontSize: 9,
                    color: isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
