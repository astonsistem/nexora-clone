import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env_config.dart';
import '../../../core/theme/sky_theme.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/sky_header_background.dart';
import '../../home/theme/home_tokens.dart';
import '../../recap/presentation/widgets/recap_common.dart';
import '../data/models/notification_item.dart';
import '../data/notification_provider.dart';

class NotificationPage extends ConsumerStatefulWidget {
  const NotificationPage({super.key});

  @override
  ConsumerState<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends ConsumerState<NotificationPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _markingAll = false;

  static const double _sheetOverlap = 22;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _getUnreadCount(AsyncValue<List<NotificationItem>> allAsync) {
    return allAsync.valueOrNull?.where((e) => !e.isRead).length ?? 0;
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    final unreadOnly = _tabController.index == 1;
    try {
      await ref.read(notificationProvider(unreadOnly).notifier).markReadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _onTapItem(NotificationItem item, bool unreadOnly) async {
    await _showNotificationDetail(item, unreadOnly);
  }

  Future<void> _showNotificationDetail(
    NotificationItem item,
    bool unreadOnly,
  ) async {
    if (!item.isRead) {
      try {
        await ref
            .read(notificationProvider(unreadOnly).notifier)
            .markRead(item.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.viewPaddingOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: HomeTokens.ink,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatTime(item.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              if (item.message.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.45,
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      item.message.trim(),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: HomeTokens.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (item.link != null)
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _openLink(item.link!);
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Buka tautan'),
                ),
              if (item.link != null) const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Tutup'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openLink(String url) async {
    final value = url.trim();
    if (value.isEmpty) return;

    final href = EnvConfig.resolveNotificationHref(value);
    if (href == null || href == '/' || href == '/home') return;

    if (href.startsWith('http://') || href.startsWith('https://')) {
      final uri = Uri.tryParse(href);
      if (uri == null) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (href.startsWith('/')) {
      if (!mounted) return;
      final rootNav = Navigator.of(context, rootNavigator: true);
      if (rootNav.canPop()) {
        rootNav.pop();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(href);
      });
    }
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return DateFormat('d MMM yyyy, HH:mm', 'id').format(local);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SkyHeaderBand(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Notifikasi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        if (_getUnreadCount(ref.watch(notificationProvider(false))) > 0)
                          TextButton(
                            onPressed: _markingAll ? null : _markAllRead,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              _markingAll ? '...' : 'Tandai semua',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                      child: Text(
                        'Pesan dan update dari HR',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -_sheetOverlap),
              child: Padding(
                padding: const EdgeInsets.only(bottom: _sheetOverlap),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TabBar(
                        controller: _tabController,
                        labelColor: HomeTokens.accent,
                        unselectedLabelColor: HomeTokens.muted,
                        indicatorColor: HomeTokens.accent,
                        tabs: const [
                          Tab(text: 'Semua'),
                          Tab(text: 'Belum dibaca'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildTabContent(false),
                            _buildTabContent(true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(bool unreadOnly) {
    final asyncData = ref.watch(notificationProvider(unreadOnly));
    
    return asyncData.when(
      loading: () => const SkeletonListBody(),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(err.toString().replaceFirst('Exception: ', ''), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.read(notificationProvider(unreadOnly).notifier).refresh(),
                child: const Text('Muat ulang'),
              ),
            ],
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => ref.read(notificationProvider(unreadOnly).notifier).refresh(),
            color: SkyTheme.instance.accent,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 48),
                RecapEmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: unreadOnly
                      ? 'Tidak ada yang belum dibaca'
                      : 'Belum ada notifikasi',
                  subtitle: unreadOnly
                      ? 'Semua pesan sudah dibaca.'
                      : 'Notifikasi baru akan muncul di sini.',
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(notificationProvider(unreadOnly).notifier).refresh(),
          color: SkyTheme.instance.accent,
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              8 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _NotificationCard(
                item: item,
                timeLabel: _formatTime(item.createdAt),
                onTap: () => _onTapItem(item, unreadOnly),
              );
            },
          ),
        );
      },
    );
  }
}


class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.timeLabel,
    required this.onTap,
  });

  final NotificationItem item;
  final String timeLabel;
  final VoidCallback onTap;

  static bool _messageNeedsDetail(String message) {
    final text = message.trim();
    if (text.isEmpty) return false;
    if (text.length > 120) return true;
    if (text.split('\n').length > 3) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;
    final showDetailHint =
        _messageNeedsDetail(item.message) || item.message.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: unread ? HomeTokens.accentSoft : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: unread
                    ? HomeTokens.accent.withValues(alpha: 0.25)
                    : HomeTokens.line,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: unread
                          ? HomeTokens.accent.withValues(alpha: 0.15)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      unread
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      color: unread ? HomeTokens.accent : HomeTokens.muted,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: unread
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: HomeTokens.ink,
                                ),
                              ),
                            ),
                            if (unread)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: HomeTokens.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        if (item.message.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.message,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: HomeTokens.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              timeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            if (item.link != null) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.link_rounded,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                            ],
                            if (showDetailHint) ...[
                              const Spacer(),
                              Text(
                                'Lihat detail',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: HomeTokens.accent,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: HomeTokens.accent,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
