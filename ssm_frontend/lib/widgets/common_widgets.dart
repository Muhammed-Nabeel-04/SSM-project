import 'package:flutter/material.dart';
import '../config/constants.dart';

// ─── STATUS BADGE ─────────────────────────────────────────────────────────────

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (color, label) = _statusInfo(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  (Color, String) _statusInfo(String s) => switch (s) {
        'draft' => (AppColors.draft, 'Draft'),
        'submitted' => (AppColors.submitted, 'Submitted'),
        'mentor_review' => (AppColors.mentorReview, 'Mentor Review'),
        'hod_review' => (AppColors.hodReview, 'HOD Review'),
        'approved' => (AppColors.approved, '✓ Approved'),
        'rejected' => (AppColors.rejected, '✗ Rejected'),
        _ => (AppColors.textSecondary, s),
      };
}

// ─── STAR RATING WIDGET ───────────────────────────────────────────────────────

class StarRating extends StatelessWidget {
  final int stars;
  final double size;
  const StarRating({required this.stars, this.size = 20, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
          color: i < stars ? AppColors.starGold : AppColors.textLight,
          size: size,
        );
      }),
    );
  }
}

// ─── SCORE RING CARD ──────────────────────────────────────────────────────────

class ScoreRingCard extends StatelessWidget {
  final double score;
  final double maxScore;
  final String label;
  final Color color;
  final IconData icon;

  const ScoreRingCard({
    required this.score,
    required this.maxScore,
    required this.label,
    required this.color,
    required this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final pct = score / maxScore;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: pct,
                  backgroundColor: color.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation(color),
                  strokeWidth: 7,
                ),
              ),
              Icon(icon, color: color, size: 26),
            ]),
            const SizedBox(height: 10),
            Text(
              score.toStringAsFixed(0),
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color),
            ),
            Text(
              '/ ${maxScore.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SECTION HEADER ───────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int? maxPoints;

  const SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
    this.maxPoints,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
                fontWeight: FontWeight.w700, color: color, fontSize: 15),
          ),
        ),
        if (maxPoints != null)
          Text(
            'Max $maxPoints pts',
            style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
      ]),
    );
  }
}

// ─── DROPDOWN FORM FIELD ──────────────────────────────────────────────────────

class AppDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool enabled;

  const AppDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
      const SizedBox(height: 6),
      DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: enabled ? onChanged : null,
        decoration: const InputDecoration(),
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 14),
      ),
      const SizedBox(height: 14),
    ]);
  }
}

// ─── NUMBER INPUT FIELD ───────────────────────────────────────────────────────

class AppNumberField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool enabled;
  final String? suffix;

  const AppNumberField({
    required this.label,
    required this.hint,
    required this.controller,
    this.enabled = true,
    this.suffix,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          hintText: hint,
          suffixText: suffix,
        ),
      ),
      const SizedBox(height: 14),
    ]);
  }
}

// ─── LOADING OVERLAY ──────────────────────────────────────────────────────────

class LoadingOverlay extends StatelessWidget {
  final bool loading;
  final Widget child;

  const LoadingOverlay(
      {required this.loading, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      child,
      if (loading)
        Container(
          color: Colors.black26,
          child: const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ),
    ]);
  }
}

// ─── ERROR BANNER ─────────────────────────────────────────────────────────────

class ErrorBanner extends StatelessWidget {
  final String message;
  const ErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  color: AppColors.error, fontSize: 13)),
        ),
      ]),
    );
  }
}

// ─── GRAND TOTAL BANNER ───────────────────────────────────────────────────────

class GrandTotalCard extends StatelessWidget {
  final double total;
  final int stars;

  const GrandTotalCard(
      {required this.total, required this.stars, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: [
        const Text('Total SSM Score',
            style: TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 6),
        Text(
          '${total.toStringAsFixed(0)} / 500',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        StarRating(stars: stars, size: 28),
        const SizedBox(height: 4),
        Text(
          _ratingLabel(stars),
          style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500),
        ),
      ]),
    );
  }

  String _ratingLabel(int s) => switch (s) {
        5 => '⭐ Outstanding',
        4 => 'Excellent',
        3 => 'Good',
        2 => 'Average',
        1 => 'Needs Improvement',
        _ => 'Not Rated',
      };
}
