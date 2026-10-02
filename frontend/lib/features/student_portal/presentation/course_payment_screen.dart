import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/student_portal_repository.dart';

class CoursePaymentScreen extends ConsumerStatefulWidget {
  const CoursePaymentScreen({
    super.key,
    required this.courseUuid,
    required this.courseName,
    required this.amount,
  });

  final String courseUuid;
  final String courseName;
  final String amount;

  @override
  ConsumerState<CoursePaymentScreen> createState() =>
      _CoursePaymentScreenState();
}

class _CoursePaymentScreenState extends ConsumerState<CoursePaymentScreen> {
  final utrController = TextEditingController();

  final noteController = TextEditingController();

  String paymentMethod = 'UPI';

  Uint8List? proofBytes;
  String? proofName;

  bool saving = false;

  String? error;

  bool get requiresProof =>
      paymentMethod == 'UPI' || paymentMethod == 'BANK_TRANSFER';

  @override
  void dispose() {
    utrController.dispose();
    noteController.dispose();

    super.dispose();
  }

  Future<void> selectProof() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'pdf',
      ],
      withData: true,
    );

    if (result == null) {
      return;
    }

    final file = result.files.single;

    if (file.bytes == null) {
      setState(() {
        error = 'Could not read selected file.';
      });

      return;
    }

    if (file.size > 10 * 1024 * 1024) {
      setState(() {
        error = 'Payment proof must be 10 MB or smaller.';
      });

      return;
    }

    setState(() {
      proofBytes = file.bytes;

      proofName = file.name;

      error = null;
    });
  }

  Future<void> submit() async {
    if (requiresProof && utrController.text.trim().isEmpty) {
      setState(() {
        error = 'UTR or transaction reference number is required.';
      });

      return;
    }

    if (requiresProof && proofBytes == null) {
      setState(() {
        error = 'Payment proof is required.';
      });

      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await ref
          .read(
            studentPortalRepositoryProvider,
          )
          .submitCoursePayment(
            courseUuid: widget.courseUuid,
            paymentMethod: paymentMethod,
            utrNumber: utrController.text,
            studentNote: noteController.text,
            paymentProofBytes: proofBytes,
            paymentProofName: proofName,
          );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            icon: const Icon(
              Icons.check_circle_outline,
              size: 48,
            ),
            title: const Text(
              'Payment Submitted',
            ),
            content: const Text(
              'Your payment request has been submitted for academy verification.',
              textAlign: TextAlign.center,
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                ),
                child: const Text(
                  'OK',
                ),
              ),
            ],
          );
        },
      );

      if (mounted) {
        context.pop(
          true,
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Course Payment',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(
          20,
        ),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(
                18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.courseName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    'Course Fee: ₹${widget.amount}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          DropdownButtonFormField<String>(
            value: paymentMethod,
            decoration: const InputDecoration(
              labelText: 'Payment Method',
            ),
            items: const [
              DropdownMenuItem(
                value: 'UPI',
                child: Text('UPI'),
              ),
              DropdownMenuItem(
                value: 'BANK_TRANSFER',
                child: Text(
                  'Bank Transfer',
                ),
              ),
              DropdownMenuItem(
                value: 'CASH',
                child: Text('Cash'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                paymentMethod = value ?? 'UPI';

                if (!requiresProof) {
                  proofBytes = null;

                  proofName = null;

                  utrController.clear();
                }

                error = null;
              });
            },
          ),
          if (requiresProof) ...[
            const SizedBox(
              height: 16,
            ),
            TextField(
              controller: utrController,
              decoration: const InputDecoration(
                labelText: 'UTR / Transaction Reference *',
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            OutlinedButton.icon(
              onPressed: selectProof,
              icon: const Icon(
                Icons.upload_file_outlined,
              ),
              label: Text(
                proofName ?? 'Upload Payment Proof',
              ),
            ),
            const SizedBox(
              height: 6,
            ),
            const Text(
              'Allowed: PDF, JPG, JPEG, PNG • Maximum 10 MB',
            ),
          ],
          const SizedBox(
            height: 16,
          ),
          TextField(
            controller: noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Note (Optional)',
              hintText: 'Any payment information for the academy',
            ),
          ),
          if (error != null) ...[
            const SizedBox(
              height: 16,
            ),
            Text(
              error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(
            height: 24,
          ),
          FilledButton.icon(
            onPressed: saving ? null : submit,
            icon: const Icon(
              Icons.payments_outlined,
            ),
            label: Text(
              saving ? 'Submitting...' : 'Submit Payment',
            ),
          ),
        ],
      ),
    );
  }
}
