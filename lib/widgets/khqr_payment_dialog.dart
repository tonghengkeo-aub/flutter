import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import '../screens/main_nav_screen.dart';
import '../services/api_client.dart';
import '../services/khqr_service.dart';

class KhqrPaymentDialog extends StatefulWidget {
  final double amountUsd;
  final double amountKhr;
  final String billNumber;
  final int? bookingId;
  final Function(Map<String, dynamic> successData) onPaymentSuccess;

  const KhqrPaymentDialog({
    super.key,
    required this.amountUsd,
    required this.amountKhr,
    required this.billNumber,
    this.bookingId,
    required this.onPaymentSuccess,
  });

  @override
  State<KhqrPaymentDialog> createState() => _KhqrPaymentDialogState();
}

class _KhqrPaymentDialogState extends State<KhqrPaymentDialog> with SingleTickerProviderStateMixin {
  KhqrPaymentData? khqrData;
  bool isLoading = true;
  bool isPaid = false;
  bool isChecking = false;
  String statusMessage = 'Generating KHQR payment code...';
  Timer? _pollTimer;
  Timer? _countdownTimer;
  int _remainingSeconds = 600; // 10 minutes countdown
  late AnimationController _pulseController;

  String get _formattedTime {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initKhqr();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _remainingSeconds = 600;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (isPaid) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _handlePaymentTimeout();
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  void _handlePaymentTimeout() async {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();

    if (widget.bookingId != null) {
      try {
        await http.delete(
          Uri.parse('${ApiClient.baseUrl}/bookings/${widget.bookingId}'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // close payment dialog

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const MainNavScreen(
          timeoutAlertMessage: 'The payment time limit has expired. Your pending reservation has been removed. Please book again when ready.\n\nរយៈពេលនៃការស្កេនទូទាត់ប្រាក់បានផុតកំណត់។ ការកក់ដែលមិនទាន់ទូទាត់ត្រូវបានលុបចោល។',
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _initKhqr() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Connecting to NBC Bakong...';
    });

    try {
      final data = await KhqrService.generateKhqr(
        amount: widget.amountUsd,
        currency: 'USD',
        billNumber: widget.billNumber,
      );

      if (mounted) {
        setState(() {
          khqrData = data;
          isLoading = false;
          statusMessage = 'Scan QR code with ABA Mobile or any Bakong banking app';
        });

        // Start polling payment status every 3 seconds & 5-minute countdown
        _startPolling(data.md5);
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          statusMessage = 'Failed to generate QR. Please try again.';
        });
      }
    }
  }

  void _startPolling(String md5) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) async {
      if (isPaid || !mounted) {
        timer.cancel();
        return;
      }
      await _checkStatus(isManual: false);
    });
  }

  Future<void> _checkStatus({bool isManual = false}) async {
    if (khqrData == null || isPaid) return;
    if (isManual) {
      setState(() => isChecking = true);
    }

    try {
      final res = await KhqrService.checkTransaction(
        md5: khqrData!.md5,
        bookingId: widget.bookingId,
        amount: widget.amountUsd,
      );

      if (res['paid'] == true && !isPaid) {
        _pollTimer?.cancel();
        _countdownTimer?.cancel();
        if (mounted) {
          setState(() {
            isPaid = true;
            isChecking = false;
          });
          widget.onPaymentSuccess(res);

          // Automatically reload and navigate to Home after showing success celebration!
          Future.delayed(const Duration(milliseconds: 3500), () {
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainNavScreen()),
                (route) => false,
              );
            }
          });
        }
        return;
      }
    } catch (_) {
    } finally {
      if (isManual && mounted) {
        setState(() => isChecking = false);
      }
    }
  }

  void _cancelAndGoHome() async {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();

    if (widget.bookingId != null && !isPaid) {
      try {
        await http.delete(
          Uri.parse('${ApiClient.baseUrl}/bookings/${widget.bookingId}'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const MainNavScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (isPaid) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainNavScreen()),
              (route) => false,
            );
          } else {
            _cancelAndGoHome();
          }
        }
      },
      child: Dialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: isPaid ? _buildSuccessView(isDark) : _buildPaymentView(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Confetti & Green Checkmark Stack matching Picture 2
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Decorative Confetti dots matching Picture 2
                Positioned(top: 10, left: 24, child: _confettiDot(const Color(0xFF10B981), 8, 4, 25)),
                Positioned(top: 18, right: 30, child: _confettiDot(const Color(0xFF38BDF8), 7, 7, 0)),
                Positioned(top: 2, right: 60, child: _confettiDot(const Color(0xFF10B981), 6, 3, -15)),
                Positioned(top: 14, left: 60, child: _confettiDot(const Color(0xFF0F172A), 4, 4, 45)),
                Positioned(bottom: 25, left: 15, child: _confettiDot(const Color(0xFF38BDF8), 5, 8, 0)),
                Positioned(bottom: 15, left: 45, child: _confettiDot(const Color(0xFF0F172A), 4, 4, 30)),
                Positioned(bottom: 30, right: 18, child: _confettiDot(const Color(0xFF38BDF8), 6, 6, 45)),
                Positioned(bottom: 15, right: 55, child: _confettiDot(const Color(0xFFFBBF24), 5, 5, 0)),
                Positioned(top: 55, left: 10, child: _confettiDot(const Color(0xFFE11D48), 6, 3, -30)),

                // Soft Mint Outer Circle
                Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD1FAE5),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: Color(0xFF34D399),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Big Bold Heading from Picture 2
          Text(
            'Payment Successful',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),

          // Subtitle from Picture 2
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Your payment has been confirmed. Your statement will show a payment to Boss Heng Luxury Hotel. Please check your booking details.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),

          // Receipt details card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Amount Paid', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      '\$${widget.amountUsd.toStringAsFixed(2)} USD',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Booking Ref', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      widget.billNumber,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Clean action button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onPaymentSuccess({'paid': true, 'billNumber': widget.billNumber});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('View Booking Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _confettiDot(Color color, double width, double height, double rotateDeg) {
    return Transform.rotate(
      angle: rotateDeg * 3.14159 / 180,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildPaymentView(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Top Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'KHQR',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bakong Unified QR Code',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Scan to pay with any banking app',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            IconButton(
              onPressed: _cancelAndGoHome,
              icon: const Icon(Icons.close, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 5-Minute Countdown Timer Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _remainingSeconds <= 60
                ? const Color(0xFFFEE2E2)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF3C7)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _remainingSeconds <= 60
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFF59E0B),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: _remainingSeconds <= 60 ? const Color(0xFFDC2626) : const Color(0xFFB45309),
              ),
              const SizedBox(width: 6),
              Text(
                'QR expires in $_formattedTime',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _remainingSeconds <= 60 ? const Color(0xFFDC2626) : const Color(0xFFB45309),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Scannable QR Code Frame
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 220,
                  height: 220,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFDC2626)),
                  ),
                )
              : khqrData != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QrImageView(
                          data: khqrData!.khqr,
                          version: QrVersions.auto,
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                          size: 230,
                          padding: const EdgeInsets.all(4),
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(4)),
                              child: const Text('KHQR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'National Bank of Cambodia',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F3E6C)),
                            ),
                          ],
                        ),
                      ],
                    )
                  : const SizedBox(
                      width: 220,
                      height: 220,
                      child: Center(child: Text('Error loading QR')),
                    ),
        ),

        const SizedBox(height: 14),

        // Price Display
        Text(
          '\$${widget.amountUsd.toStringAsFixed(2)} USD',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
          ),
        ),
        Text(
          '≈ ${widget.amountKhr.toStringAsFixed(0)} KHR',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
          ),
        ),

        const SizedBox(height: 14),

        // Live Radar Polling Animation
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      const Color(0xFF10B981),
                      const Color(0xFF38BDF8),
                      _pulseController.value,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusMessage,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
      ],
    );                                                                                                                                                            
  }
}
