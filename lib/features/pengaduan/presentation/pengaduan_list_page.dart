import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/sky_theme.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../home/theme/home_tokens.dart';
import '../data/models/pengaduan_models.dart';
import '../data/pengaduan_service.dart';
import 'pengaduan_create_page.dart';
import 'pengaduan_detail_page.dart';
import 'widgets/pengaduan_shared.dart';

class PengaduanListPage extends StatefulWidget {
  const PengaduanListPage({super.key});

  @override
  State<PengaduanListPage> createState() => _PengaduanListPageState();
}

class _PengaduanListPageState extends State<PengaduanListPage> {
  static const _pageSize = 15;

  final _service = PengaduanService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<Ticket> _tickets = const [];
  String? _status;
  String? _error;
  int _page = 1;
  int _pages = 1;
  int _total = 0;
  int _requestVersion = 0;
  bool _loading = true;
  bool _loadingMore = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 260) _loadMore();
  }

  void _onSearchChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _loadFirstPage);
  }

  Future<void> _loadFirstPage() async {
    final version = ++_requestVersion;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
    });
    try {
      final result = await _service.getTickets(
        page: 1,
        size: _pageSize,
        status: _status,
        query: _searchController.text,
      );
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _tickets = result.items;
        _page = result.page;
        _pages = result.pages;
        _total = result.total;
        _loading = false;
      });
    } on DioException catch (error) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _error = _service.extractErrorMessage(error);
        _loading = false;
      });
    } catch (_) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _error = 'Daftar pengaduan gagal dimuat.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _page >= _pages) return;
    final version = _requestVersion;
    setState(() => _loadingMore = true);
    try {
      final result = await _service.getTickets(
        page: _page + 1,
        size: _pageSize,
        status: _status,
        query: _searchController.text,
      );
      if (!mounted || version != _requestVersion) return;
      final knownIds = _tickets.map((item) => item.id).toSet();
      setState(() {
        _tickets = [
          ..._tickets,
          ...result.items.where((item) => knownIds.add(item.id)),
        ];
        _page = result.page;
        _pages = result.pages;
        _total = result.total;
        _loadingMore = false;
      });
    } on DioException catch (error) {
      if (!mounted || version != _requestVersion) return;
      setState(() => _loadingMore = false);
      _showSnack(_service.extractErrorMessage(error));
    } catch (_) {
      if (!mounted || version != _requestVersion) return;
      setState(() => _loadingMore = false);
      _showSnack('Halaman berikutnya gagal dimuat.');
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PengaduanCreatePage()),
    );
    if (created == true && mounted) await _loadFirstPage();
  }

  void _openDetail(Ticket ticket) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PengaduanDetailPage(ticketId: ticket.id),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PengaduanScaffold(
      title: 'Pengaduan',
      subtitle: 'Keluhan dan permintaan bantuan ke HR',
      floatingActionButton: SkyAccentBuilder(
        builder: (context, accent, _) {
          return FloatingActionButton.extended(
            onPressed: _openCreate,
            backgroundColor: accent,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Buat Pengaduan',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          );
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: pengaduanInputDecoration(
                    label: 'Cari pengaduan',
                    hint: 'Nomor atau subjek',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                              _loadFirstPage();
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: SkyAccentBuilder(
                    builder: (context, _, _) {
                      return ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _StatusChip(
                            label: 'Semua',
                            selected: _status == null,
                            onSelected: () => _selectStatus(null),
                          ),
                          for (final value in const [
                            'PENDING',
                            'IN_PROGRESS',
                            'RESOLVED',
                            'REJECTED',
                          ])
                            _StatusChip(
                              label: ticketStatusLabel(value),
                              selected: _status == value,
                              color: ticketStatusColor(value),
                              onSelected: () => _selectStatus(value),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  void _selectStatus(String? value) {
    if (_status == value) return;
    setState(() => _status = value);
    _loadFirstPage();
  }

  Widget _buildBody() {
    if (_loading && _tickets.isEmpty) {
      return const SkeletonListBody(
        itemCount: 6,
        padding: EdgeInsets.fromLTRB(16, 14, 16, 100),
      );
    }
    if (_error != null && _tickets.isEmpty) {
      return _MessageState(
        icon: Icons.cloud_off_rounded,
        title: 'Gagal memuat pengaduan',
        subtitle: _error!,
        actionLabel: 'Coba lagi',
        onAction: _loadFirstPage,
      );
    }
    if (_tickets.isEmpty) {
      final filtered =
          _status != null || _searchController.text.trim().isNotEmpty;
      return RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
            _MessageState(
              icon: Icons.forum_outlined,
              title: filtered
                  ? 'Pengaduan tidak ditemukan'
                  : 'Belum ada pengaduan',
              subtitle: filtered
                  ? 'Ubah kata kunci atau filter status.'
                  : 'Buat pengaduan jika Anda membutuhkan bantuan HR.',
              actionLabel: filtered ? null : 'Buat Pengaduan',
              onAction: filtered ? null : _openCreate,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      color: SkyTheme.instance.accent,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _tickets.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '$_total pengaduan',
                style: const TextStyle(
                  color: HomeTokens.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }
          if (index == _tickets.length + 1) {
            return _loadingMore
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox(height: 8);
          }
          final ticket = _tickets[index - 1];
          return _TicketCard(ticket: ticket, onTap: () => _openDetail(ticket));
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? SkyTheme.instance.accent;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        selectedColor: resolved.withValues(alpha: 0.13),
        side: BorderSide(
          color: selected ? resolved.withValues(alpha: 0.4) : HomeTokens.line,
        ),
        labelStyle: TextStyle(
          color: selected ? resolved : HomeTokens.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final Ticket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: HomeTokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SkyAccentBuilder(
                        builder: (context, accent, _) {
                          return Text(
                            ticket.ticketNumber,
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    TicketStatusBadge(status: ticket.status),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  ticket.subject,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HomeTokens.ink,
                    fontSize: 15,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    const Icon(
                      Icons.category_outlined,
                      size: 15,
                      color: HomeTokens.muted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        ticket.ticketType?.name ?? '-',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: HomeTokens.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: HomeTokens.muted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      ticketDate(ticket.createdAt),
                      style: const TextStyle(
                        color: HomeTokens.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: HomeTokens.muted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: HomeTokens.muted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: HomeTokens.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: HomeTokens.muted, height: 1.4),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
