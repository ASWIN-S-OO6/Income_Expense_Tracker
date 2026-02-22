import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/entry.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/formatters.dart';

class BalanceLineChart extends StatelessWidget {
  final List<Entry> entries;
  final String currencySymbol;
  final double initialAmount;

  const BalanceLineChart({
    super.key,
    required this.entries,
    required this.initialAmount,
    this.currencySymbol = '\$',
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty && initialAmount == 0) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text("Add entries to see your balance trend."),
      );
    }

    // Process data to get cumulative balance over the last 30 days
    final now = DateTime.now();
    final last30Days = List.generate(30, (index) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 29 - index)));
    
    // Sort entries chronologically
    final sortedEntries = List<Entry>.from(entries)..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    List<FlSpot> spots = [];
    double currentBalance = initialAmount;
    double minBalance = currentBalance;
    double maxBalance = currentBalance;

    // Calculate balance prior to 30 days window
    final cutoffDate = last30Days.first;
    for (var e in sortedEntries.where((e) => e.timestamp.isBefore(cutoffDate))) {
      currentBalance += (e.type == EntryType.income ? e.amount : -e.amount);
    }

    // Map the 30-day window
    for (int i = 0; i < 30; i++) {
      final date = last30Days[i];
      final dayEntries = sortedEntries.where((e) => 
        e.timestamp.year == date.year &&
        e.timestamp.month == date.month &&
        e.timestamp.day == date.day
      );

      for (var e in dayEntries) {
        currentBalance += (e.type == EntryType.income ? e.amount : -e.amount);
      }

      if (currentBalance < minBalance) minBalance = currentBalance;
      if (currentBalance > maxBalance) maxBalance = currentBalance;

      spots.add(FlSpot(i.toDouble(), currentBalance));
    }

    // Calculate chart boundaries with enough padding for tooltips
    double yPad = (maxBalance - minBalance).abs() * 0.3; // 30% padding
    if (yPad == 0 && maxBalance != 0) yPad = maxBalance.abs() * 0.3;
    if (yPad == 0) yPad = 100; // If everything is perfectly 0

    // For 0 balance, we want the line to sit at the bottom, not in the middle or top
    double minY = (minBalance - (yPad * 0.5)).floorToDouble(); // Less padding on bottom
    double maxY = (maxBalance + (yPad * 1.5)).ceilToDouble(); // More padding on top for tooltips

    if (minBalance == 0 && maxBalance == 0) {
      minY = 0;
      maxY = 100;
    }

    // Chart width logic to allow horizontal scrolling
    const double pointsPerDay = 30.0;
    final chartWidth = 30 * pointsPerDay; // 30 days * 30px width per day

    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                "30-Day Balance Trend",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true, // Auto-scrolls to the newest (right) edge
              child: Padding(
                padding: const EdgeInsets.only(right: 24.0, left: 16.0),
                child: SizedBox(
                  height: 220,
                  width: chartWidth < MediaQuery.of(context).size.width ? MediaQuery.of(context).size.width : chartWidth,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: 29,
                      minY: minY,
                      maxY: maxY == minY ? maxY + 1 : maxY,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.35,
                          color: AppColors.primaryLight,
                          barWidth: 4,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 3,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: AppColors.primaryLight,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryLight.withValues(alpha: 0.3),
                                AppColors.primaryLight.withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: ((maxY - minY) / 4) == 0 ? 1 : ((maxY - minY) / 4),
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.withValues(alpha: 0.2),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 1,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              if (value.toInt() % 3 != 0 && value.toInt() != 29) return const SizedBox.shrink(); // Show every 3rd day
                              final date = last30Days[value.toInt()];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  DateFormat('MMM d').format(date),
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                          return spotIndexes.map((index) {
                            return TouchedSpotIndicatorData(
                              FlLine(color: AppColors.primaryLight, strokeWidth: 2, dashArray: [4, 4]),
                              FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                  radius: 6,
                                  color: AppColors.primaryLight,
                                  strokeColor: Colors.white,
                                  strokeWidth: 3,
                                ),
                              ),
                            );
                          }).toList();
                        },
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((LineBarSpot touchedSpot) {
                              return LineTooltipItem(
                                Formatters.formatCurrency(touchedSpot.y, symbol: currencySymbol),
                                TextStyle(
                                  color: AppColors.primaryLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
