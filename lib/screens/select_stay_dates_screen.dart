import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SelectStayDatesScreen extends StatefulWidget {
  final DateTime initialCheckIn;
  final DateTime initialCheckOut;
  final String? hotelName;

  const SelectStayDatesScreen({
    super.key,
    required this.initialCheckIn,
    required this.initialCheckOut,
    this.hotelName,
  });

  @override
  State<SelectStayDatesScreen> createState() => _SelectStayDatesScreenState();
}

class _SelectStayDatesScreenState extends State<SelectStayDatesScreen> {
  late DateTime _displayedMonth;
  DateTime? _checkIn;
  DateTime? _checkOut;
  late final DateTime _today;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);

    _checkIn = DateTime(
      widget.initialCheckIn.year,
      widget.initialCheckIn.month,
      widget.initialCheckIn.day,
    );
    _checkOut = DateTime(
      widget.initialCheckOut.year,
      widget.initialCheckOut.month,
      widget.initialCheckOut.day,
    );

    // Default displayed month to check-in month
    _displayedMonth = DateTime(_checkIn!.year, _checkIn!.month, 1);
  }

  void _previousMonth() {
    final firstAllowedMonth = DateTime(_today.year, _today.month, 1);
    final prev = DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
    if (!prev.isBefore(firstAllowedMonth)) {
      setState(() {
        _displayedMonth = prev;
      });
    }
  }

  void _nextMonth() {
    final maxMonth = DateTime(_today.year, _today.month + 12, 1);
    final next = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    if (next.isBefore(maxMonth)) {
      setState(() {
        _displayedMonth = next;
      });
    }
  }

  void _onDayTapped(DateTime day) {
    if (day.isBefore(_today)) return; // Past date not selectable

    setState(() {
      if (_checkIn == null || (_checkIn != null && _checkOut != null)) {
        // Start fresh selection
        _checkIn = day;
        _checkOut = null;
      } else if (_checkIn != null && _checkOut == null) {
        if (day.isAfter(_checkIn!)) {
          _checkOut = day;
        } else if (day.isBefore(_checkIn!)) {
          _checkIn = day;
        } else {
          // Tapped same day -> set check-out to next day
          _checkOut = day.add(const Duration(days: 1));
        }
      }
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int get _nights {
    if (_checkIn != null && _checkOut != null) {
      return _checkOut!.difference(_checkIn!).inDays.clamp(1, 365);
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firstAllowedMonth = DateTime(_today.year, _today.month, 1);
    final canGoBack = _displayedMonth.isAfter(firstAllowedMonth);

    // Dynamic subtitle
    String subtitle = 'Tap a date to set check-in';
    if (_checkIn != null && _checkOut == null) {
      subtitle = 'Tap a date to set check-out';
    } else if (_checkIn != null && _checkOut != null) {
      subtitle = '$_nights Night${_nights > 1 ? 's' : ''} Stay Selected';
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        foregroundColor: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Your Stay',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 19,
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==========================================
                  // 1. CHECK-IN / CHECK-OUT CARDS (BIG & PROMINENT)
                  // ==========================================
                  _buildCheckInOutCards(isDark),
                  const SizedBox(height: 18),

                  // ==========================================
                  // 2. CALENDAR CARD (BIG & EASY TO TAP)
                  // ==========================================
                  _buildCalendarCard(isDark, canGoBack),
                  const SizedBox(height: 20),

                  // ==========================================
                  // 3. HOTEL POLICIES
                  // ==========================================
                  _buildHotelPolicies(isDark),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ==========================================
          // 4. BOTTOM CONFIRMATION BAR
          // ==========================================
          _buildBottomConfirmationBar(isDark),
        ],
      ),
    );
  }

  // ==========================================
  // TOP CHECK-IN / CHECK-OUT TILES (BIG & CLEAR)
  // ==========================================
  Widget _buildCheckInOutCards(bool isDark) {
    final isSelectingCheckIn = _checkIn == null || (_checkIn != null && _checkOut != null);

    return Row(
      children: [
        // Check-in card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131D32) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelectingCheckIn
                    ? const Color(0xFF4F46E5)
                    : (isDark ? const Color(0xFF22314E) : const Color(0xFFE2E8F0)),
                width: isSelectingCheckIn ? 2.0 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF4F46E5)),
                    SizedBox(width: 6),
                    Text(
                      'CHECK-IN',
                      style: TextStyle(
                        color: Color(0xFF4F46E5),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_checkIn != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${_checkIn!.day}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4F46E5),
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          DateFormat('MMM yyyy').format(_checkIn!),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    DateFormat('EEEE').format(_checkIn!),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ] else ...[
                  const Text(
                    '—',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'From 2:00 PM',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF64748B) : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Middle arrow
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ),

        // Check-out card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131D32) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: !isSelectingCheckIn
                    ? const Color(0xFFF59E0B)
                    : (isDark ? const Color(0xFF22314E) : const Color(0xFFE2E8F0)),
                width: !isSelectingCheckIn ? 2.0 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFFD97706)),
                    SizedBox(width: 6),
                    Text(
                      'CHECK-OUT',
                      style: TextStyle(
                        color: Color(0xFFD97706),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_checkOut != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${_checkOut!.day}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFF59E0B),
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          DateFormat('MMM yyyy').format(_checkOut!),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    DateFormat('EEEE').format(_checkOut!),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ] else ...[
                  const Text(
                    '—',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Until 12:00 PM',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF64748B) : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // CALENDAR CARD WITH MONTH GRID (BIGGER & MORE SPACIOUS)
  // ==========================================
  Widget _buildCalendarCard(bool isDark, bool canGoBack) {
    final monthStr = DateFormat('MMMM yyyy').format(_displayedMonth);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D32) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF22314E) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Month navigation header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: canGoBack
                      ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 24),
                  color: canGoBack
                      ? (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))
                      : Colors.grey.shade300,
                  onPressed: canGoBack ? _previousMonth : null,
                  padding: EdgeInsets.zero,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  monthStr,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 24),
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  onPressed: _nextMonth,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Days of week header (Su Mo Tu We Th Fr Sa)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'].map((d) {
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Monthly day grid
          _buildMonthDaysGrid(isDark),
          const SizedBox(height: 20),

          // Legend
          Divider(height: 1, color: isDark ? const Color(0xFF22314E) : const Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(const Color(0xFF4F46E5), 'Selected'),
              const SizedBox(width: 20),
              _buildLegendItem(const Color(0xFFEEF2FF), 'Your stay', isBorder: true),
              const SizedBox(width: 20),
              _buildLegendItem(const Color(0xFFE2E8F0), 'Unavailable'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, {bool isBorder = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: isBorder ? Border.all(color: const Color(0xFF4F46E5), width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ==========================================
  // MONTH GRID CELLS GENERATOR (BIGGER & EASIER TO TAP)
  // ==========================================
  Widget _buildMonthDaysGrid(bool isDark) {
    final year = _displayedMonth.year;
    final month = _displayedMonth.month;

    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final int weekdayOffset = firstDayOfMonth.weekday % 7; // Sunday = 0

    final List<Widget> dayWidgets = [];

    // Empty lead slots before the 1st
    for (int i = 0; i < weekdayOffset; i++) {
      dayWidgets.add(const SizedBox(height: 48));
    }

    // Days 1 through daysInMonth
    for (int dayNum = 1; dayNum <= daysInMonth; dayNum++) {
      final currentDay = DateTime(year, month, dayNum);
      final isPast = currentDay.isBefore(_today);

      final isCheckIn = _checkIn != null && _isSameDay(currentDay, _checkIn!);
      final isCheckOut = _checkOut != null && _isSameDay(currentDay, _checkOut!);
      final isInRange = _checkIn != null &&
          _checkOut != null &&
          currentDay.isAfter(_checkIn!) &&
          currentDay.isBefore(_checkOut!);

      final isTodayDay = _isSameDay(currentDay, _today);

      dayWidgets.add(
        InkWell(
          onTap: isPast ? null : () => _onDayTapped(currentDay),
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Connecting Range Ribbon
                if (isInRange)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
                    ),
                  ),

                // Left Ribbon connector for Check-out
                if (isCheckOut && _checkIn != null)
                  Positioned(
                    left: 0,
                    top: 4,
                    bottom: 4,
                    right: 24,
                    child: Container(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
                    ),
                  ),

                // Right Ribbon connector for Check-in
                if (isCheckIn && _checkOut != null)
                  Positioned(
                    left: 24,
                    top: 4,
                    bottom: 4,
                    right: 0,
                    child: Container(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
                    ),
                  ),

                // Date Circular Target
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isCheckIn || isCheckOut)
                        ? const Color(0xFF4F46E5)
                        : (isInRange
                            ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF))
                            : Colors.transparent),
                    border: (isTodayDay && !isCheckIn && !isCheckOut && !isInRange)
                        ? Border.all(color: const Color(0xFF4F46E5), width: 1.5)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$dayNum',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: (isCheckIn || isCheckOut || isInRange || isTodayDay)
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: (isCheckIn || isCheckOut)
                            ? Colors.white
                            : (isPast
                                ? (isDark ? const Color(0xFF334155) : Colors.grey.shade300)
                                : (isInRange
                                    ? const Color(0xFF4F46E5)
                                    : (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)))),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 0,
      children: dayWidgets,
    );
  }

  // ==========================================
  // HOTEL POLICIES
  // ==========================================
  Widget _buildHotelPolicies(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D32) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF22314E) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HOTEL POLICIES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),

          // Check-in Time
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF64748B)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check-in Time',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'From 2:00 PM onwards • Early check-in on request',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Check-out Time
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFF64748B)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check-out Time',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Until 12:00 PM • Late check-out subject to availability',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Free Cancellation
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFF10B981)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Free Cancellation Policy',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Free cancellation up to 48 hours before check-in. 100% full refund.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BOTTOM CONFIRMATION BAR
  // ==========================================
  Widget _buildBottomConfirmationBar(bool isDark) {
    final bool isReady = _checkIn != null && _checkOut != null;
    final df = DateFormat('MMM dd');

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Summary text
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isReady ? '$_nights Night${_nights > 1 ? 's' : ''} Stay' : 'Select dates',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isReady
                        ? '${df.format(_checkIn!)} – ${df.format(_checkOut!)}'
                        : 'Choose check-in & check-out',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Confirm button
            ElevatedButton(
              onPressed: isReady
                  ? () {
                      Navigator.pop(
                        context,
                        DateTimeRange(start: _checkIn!, end: _checkOut!),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                disabledBackgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade300,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              ),
              child: Row(
                children: const [
                  Text(
                    'Confirm Dates',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
