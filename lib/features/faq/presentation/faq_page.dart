import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/navigation/shell_insets.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/shell_page_title.dart';
import '../../../shared/widgets/sky_header_background.dart';
import '../../home/theme/home_tokens.dart';
import '../../kepuasan_karyawan/data/kepuasan_fab_refresh.dart';
import '../../recap/presentation/widgets/recap_common.dart';
import '../data/faq_provider.dart';
import '../data/models/faq_item.dart';

class FaqPage extends ConsumerStatefulWidget {
  const FaqPage({super.key});

  @override
  ConsumerState<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends ConsumerState<FaqPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  String _searchQuery = '';
  String? _expandedId;
  Timer? _debounce;

  static const double _sheetOverlap = 22;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _searchQuery = value.trim());
    });
  }

  Future<void> _openLink(String url) async {
    var value = url.trim();
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tautan tidak valid.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak bisa membuka tautan.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showDetailBottomSheet(FaqItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
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
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(
                      24,
                      0,
                      24,
                      24 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: HomeTokens.accent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.quiz_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              item.question,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: HomeTokens.ink,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        item.answer,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: HomeTokens.ink.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (item.linkUrl != null) ...[
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => _openLink(item.linkUrl!),
                          style: FilledButton.styleFrom(
                            backgroundColor: HomeTokens.accentSoft,
                            foregroundColor: HomeTokens.accent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 20),
                          label: const Text(
                            'Buka Tautan Lampiran',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          SkyHeaderBand(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShellPageTitle(title: 'FAQ'),
                    const SizedBox(height: 4),
                    Text(
                      'Pertanyaan seputar absensi & HR',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                    // Space for white sheet overlap
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildSearchField(),
                      ),
                      const SizedBox(height: 8),
                      Expanded(child: _buildBody()),
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

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        onChanged: (value) {
          setState(() {});
          _onSearchChanged(value);
        },
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: HomeTokens.ink,
        ),
        decoration: InputDecoration(
          hintText: 'Cari pertanyaan...',
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: HomeTokens.accent,
            size: 22,
          ),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: HomeTokens.muted,
                  ),
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade100, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: HomeTokens.accentSoft,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final asyncData = ref.watch(faqProvider(_searchQuery));

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
                onPressed: () => ref.read(faqProvider(_searchQuery).notifier).refresh(),
                child: const Text('Muat ulang'),
              ),
            ],
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          final hasQuery = _searchQuery.isNotEmpty;
          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(faqProvider(_searchQuery).notifier).refresh();
              KepuasanFabRefresh.instance.ping();
            },
            color: HomeTokens.accent,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: shellBottomContentPadding(context)),
              children: [
                const SizedBox(height: 48),
                RecapEmptyState(
                  icon: Icons.help_outline_rounded,
                  title: hasQuery ? 'Tidak ditemukan' : 'Belum ada FAQ',
                  subtitle: hasQuery
                      ? 'Coba kata kunci lain.'
                      : 'Belum ada pertanyaan yang dipublikasikan.',
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(faqProvider(_searchQuery).notifier).refresh();
            KepuasanFabRefresh.instance.ping();
          },
          color: HomeTokens.accent,
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              shellBottomContentPadding(context) + 16,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => _FaqCard(
              item: items[index],
              expanded: _expandedId == items[index].id,
              onToggle: () {
                setState(() {
                  final id = items[index].id;
                  _expandedId = _expandedId == id ? null : id;
                });
              },
              onReadMore: () => _showDetailBottomSheet(items[index]),
            ),
          ),
        );
      },
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({
    required this.item,
    required this.expanded,
    required this.onToggle,
    required this.onReadMore,
  });

  final FaqItem item;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onReadMore;

  @override
  Widget build(BuildContext context) {
    final isLongText = item.answer.length > 120;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: expanded ? Colors.white : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: expanded ? HomeTokens.accentSoft : HomeTokens.line,
            width: expanded ? 1.5 : 1,
          ),
          boxShadow: expanded
              ? [
                  BoxShadow(
                    color: HomeTokens.accent.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: expanded
                              ? HomeTokens.accent
                              : HomeTokens.accentSoft,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: expanded
                              ? [
                                  BoxShadow(
                                    color: HomeTokens.accent.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : [],
                        ),
                        child: Icon(
                          expanded ? Icons.quiz_rounded : Icons.quiz_outlined,
                          color: expanded ? Colors.white : HomeTokens.accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          item.question,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: expanded ? FontWeight.w800 : FontWeight.w700,
                            color: HomeTokens.ink,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOutBack,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: expanded ? HomeTokens.accent : Colors.grey.shade400,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 16, left: 56),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.answer,
                            maxLines: isLongText ? 3 : null,
                            overflow: isLongText ? TextOverflow.ellipsis : null,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: HomeTokens.ink.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isLongText) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: onReadMore,
                              borderRadius: BorderRadius.circular(6),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                child: Text(
                                  'Baca Selengkapnya',
                                  style: TextStyle(
                                    color: HomeTokens.accent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ] else if (item.linkUrl != null) ...[
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: onReadMore,
                              style: FilledButton.styleFrom(
                                backgroundColor: HomeTokens.accentSoft,
                                foregroundColor: HomeTokens.accent,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.open_in_new_rounded, size: 16),
                              label: const Text(
                                'Buka tautan',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    crossFadeState: expanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 250),
                    sizeCurve: Curves.easeInOut,
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
