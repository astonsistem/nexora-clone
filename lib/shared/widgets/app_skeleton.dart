import 'package:flutter/material.dart';

import '../../features/home/theme/home_tokens.dart';

class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 8,
    this.margin,
  });

  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = 0.45 + (_controller.value * 0.35);
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: HomeTokens.line.withValues(alpha: t),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

class SkeletonListBody extends StatelessWidget {
  const SkeletonListBody({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => const SkeletonListTile(),
    );
  }
}

class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomeTokens.line),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(width: 40, height: 40, borderRadius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(width: 160, height: 14),
                SizedBox(height: 8),
                AppSkeleton(height: 12),
                SizedBox(height: 6),
                AppSkeleton(width: 100, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonHomeBody extends StatelessWidget {
  const SkeletonHomeBody({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: HomeTokens.line),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton(width: 120, height: 12),
              SizedBox(height: 10),
              AppSkeleton(width: 200, height: 22),
              SizedBox(height: 8),
              AppSkeleton(width: 140, height: 12),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: HomeTokens.line),
          ),
          padding: const EdgeInsets.all(16),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton(width: 100, height: 12),
              Spacer(),
              AppSkeleton(height: 40, borderRadius: 12),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: List.generate(
            3,
            (_) => const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: AppSkeleton(height: 72, borderRadius: 14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const SkeletonListTile(),
        const SizedBox(height: 10),
        const SkeletonListTile(),
      ],
    );
  }
}

class SkeletonProfileBody extends StatelessWidget {
  const SkeletonProfileBody({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const Center(
          child: AppSkeleton(width: 88, height: 88, borderRadius: 44),
        ),
        const SizedBox(height: 14),
        const Center(child: AppSkeleton(width: 160, height: 18)),
        const SizedBox(height: 8),
        const Center(child: AppSkeleton(width: 120, height: 12)),
        const SizedBox(height: 24),
        ...List.generate(
          5,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: AppSkeleton(height: 52, borderRadius: 14),
          ),
        ),
      ],
    );
  }
}

class SkeletonRecapBody extends StatelessWidget {
  const SkeletonRecapBody({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HomeTokens.line),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: AppSkeleton(height: 14)),
                SizedBox(width: 24),
                AppSkeleton(width: 64, height: 22, borderRadius: 11),
              ],
            ),
            SizedBox(height: 10),
            AppSkeleton(width: 140, height: 12),
            SizedBox(height: 6),
            AppSkeleton(width: 100, height: 12),
          ],
        ),
      ),
    );
  }
}

class SkeletonAttendanceBody extends StatelessWidget {
  const SkeletonAttendanceBody({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const AppSkeleton(height: 160, borderRadius: 18),
        const SizedBox(height: 14),
        const AppSkeleton(height: 72, borderRadius: 14),
        const SizedBox(height: 14),
        const AppSkeleton(height: 56, borderRadius: 28),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: HomeTokens.line),
                ),
                padding: const EdgeInsets.all(12),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeleton(width: 72, height: 12),
                    Spacer(),
                    AppSkeleton(width: 90, height: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: HomeTokens.line),
                ),
                padding: const EdgeInsets.all(12),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeleton(width: 72, height: 12),
                    Spacer(),
                    AppSkeleton(width: 90, height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SkeletonPermissionBody extends StatelessWidget {
  const SkeletonPermissionBody({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const AppSkeleton(height: 48, borderRadius: 12),
        const SizedBox(height: 12),
        const AppSkeleton(height: 48, borderRadius: 12),
        const SizedBox(height: 12),
        const AppSkeleton(height: 100, borderRadius: 12),
        const SizedBox(height: 16),
        const AppSkeleton(height: 48, borderRadius: 14),
        const SizedBox(height: 20),
        const AppSkeleton(width: 120, height: 14),
        const SizedBox(height: 10),
        const SkeletonListTile(),
        const SizedBox(height: 10),
        const SkeletonListTile(),
      ],
    );
  }
}
