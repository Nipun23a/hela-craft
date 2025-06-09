import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  // Sample sales trend data for the last 7 days
  static final List<FlSpot> _salesSpots = [
    const FlSpot(0, 10000),
    const FlSpot(1, 18000),
    const FlSpot(2, 15000),
    const FlSpot(3, 22000),
    const FlSpot(4, 28000),
    const FlSpot(5, 25000),
    const FlSpot(6, 32000),
  ];

  // Sample category distribution data
  static final List<PieChartSectionData> _categorySections = [
    PieChartSectionData(
      value: 30,
      title: 'Baskets',
      radius: 50,
      titleStyle: GoogleFonts.nunito(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    PieChartSectionData(
      value: 20,
      title: 'Vases',
      radius: 50,
      titleStyle: GoogleFonts.nunito(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    PieChartSectionData(
      value: 25,
      title: 'Masks',
      radius: 50,
      titleStyle: GoogleFonts.nunito(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    PieChartSectionData(
      value: 25,
      title: 'Necklaces',
      radius: 50,
      titleStyle: GoogleFonts.nunito(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Calculate summary metrics
    final totalSales = _salesSpots.fold<double>(0, (sum, spot) => sum + spot.y);
    final totalOrders = 45; // Replace with dynamic data if available
    final avgOrderValue = totalOrders > 0 ? totalSales / totalOrders : 0;

    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: 'Rs. ',
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analytics',
              style: GoogleFonts.raleway(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 24),

            // Summary Cards
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _SummaryCard(
                  title: 'Total Sales',
                  value: currencyFormat.format(totalSales),
                  icon: Icons.monetization_on_rounded,
                  color: const Color(0xFF6A11CB),
                ),
                _SummaryCard(
                  title: 'Total Orders',
                  value: totalOrders.toString(),
                  icon: Icons.shopping_bag_rounded,
                  color: const Color(0xFFFF7B00),
                ),
                _SummaryCard(
                  title: 'Avg. Order Value',
                  value: currencyFormat.format(avgOrderValue),
                  icon: Icons.show_chart_rounded,
                  color: Colors.teal,
                ),
                _SummaryCard(
                  title: 'Data Points',
                  value: _salesSpots.length.toString(),
                  icon: Icons.data_usage_rounded,
                  color: Colors.indigo,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Sales Trend Line Chart
            _Section(
              title: 'Sales Trend (Last 7 Days)',
              child: SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawHorizontalLine: true,
                      drawVerticalLine: true,
                      horizontalInterval: 10000,
                      getDrawingHorizontalLine:
                          (value) => FlLine(
                            color: Colors.grey.withOpacity(0.2),
                            strokeWidth: 1,
                          ),
                      getDrawingVerticalLine:
                          (value) => FlLine(
                            color: Colors.grey.withOpacity(0.2),
                            strokeWidth: 1,
                          ),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                            final idx = value.toInt();
                            if (idx < 0 || idx >= days.length)
                              return const Text('');
                            return Text(
                              days[idx],
                              style: GoogleFonts.nunito(
                                fontSize: 10,
                                color: Colors.black54,
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 10000,
                          getTitlesWidget:
                              (value, meta) => Text(
                                '${(value / 1000).toInt()}K',
                                style: GoogleFonts.nunito(
                                  fontSize: 10,
                                  color: Colors.black54,
                                ),
                              ),
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _salesSpots,
                        isCurved: true,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF6A11CB).withOpacity(0.3),
                              const Color(0xFFFF7B00).withOpacity(0.1),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Category Distribution Pie Chart
            _Section(
              title: 'Category Distribution',
              child: SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: _categorySections,
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
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

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.nunito(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.raleway(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.raleway(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}
