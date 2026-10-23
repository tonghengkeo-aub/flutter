import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
  late AnimationController _pulseController;

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
    _pulseController.dispose();
    super.dispose();
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

        // Start polling payment status every 3 seconds
        _startPolling(data.md5);
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
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
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
        if (mounted) {
          setState(() {
            isPaid = true;
            isChecking = false;
          });

          // Wait 1.5 seconds to show celebration then callback
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) {
            Navigator.of(context).pop();
            widget.onPaymentSuccess(res);
          }
        }
        return;
      } else if (isManual && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment not detected yet. Please scan and complete in your banking app.'),
            backgroundColor: Color(0xFFD97706),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
    } finally {
      if (isManual && mounted) {
        setState(() => isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
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
    );
  }

  Widget _buildSuccessView(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 60),
        ),
        const SizedBox(height: 20),
        Text(
          'Payment Successful!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Money received directly into ABA Bank account',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Amount Paid:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  Text('\$${widget.amountUsd.toStringAsFixed(2)} USD',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Booking Ref:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  Text(widget.billNumber,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Payment Method:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  Text('Bakong KHQR',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
        const SizedBox(height: 10),
        const Text(
          'Confirming booking pass...',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
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
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),

        const SizedBox(height: 18),

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
                          size: 220,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF0F172A),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF0F172A),
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
                  isChecking ? 'Verifying payment...' : statusMessage,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 18),

        // Deep Link Button: Open in ABA Mobile / Bakong
        if (khqrData?.deeplink != null) ...[
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () => KhqrService.launchBakongDeeplink(khqrData!.deeplink),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text(
                'Open in ABA Mobile / Bakong App',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F3E6C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Manual Verify Button
        SizedBox(
          width: double.infinity,
          height: 42,
          child: OutlinedButton(
            onPressed: isChecking ? null : () => _checkStatus(isManual: true),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: isChecking
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text(
                    'I Have Completed Payment',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }
}
