import 'package:dio/dio.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/sky_theme.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../home/theme/home_tokens.dart';
import '../data/models/pengaduan_models.dart';
import '../data/pengaduan_service.dart';
import 'widgets/pengaduan_shared.dart';

class PengaduanDetailPage extends StatefulWidget {
  const PengaduanDetailPage({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<PengaduanDetailPage> createState() => _PengaduanDetailPageState();
}

class _PengaduanDetailPageState extends State<PengaduanDetailPage> {
  final _service = PengaduanService();
  Ticket? _ticket;
  bool _loading = true;
  bool _downloadingAttachment = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_ticket == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final ticket = await _service.getTicket(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _loading = false;
        _error = null;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _service.extractErrorMessage(error);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Detail pengaduan gagal dimuat.';
        _loading = false;
      });
    }
  }

  Future<void> _openAttachment() async {
    if (_downloadingAttachment) return;
    setState(() => _downloadingAttachment = true);
    try {
      final attachment = await _service.downloadAttachment(widget.ticketId);
      final dot = attachment.filename.lastIndexOf('.');
      final stem = dot > 0
          ? attachment.filename.substring(0, dot)
          : attachment.filename;
      final extension = dot > 0
          ? attachment.filename.substring(dot + 1).toLowerCase()
          : '';
      final mimeType = switch (extension) {
        'pdf' => MimeType.pdf,
        'png' => MimeType.png,
        'jpg' || 'jpeg' => MimeType.jpeg,
        _ => MimeType.other,
      };
      final savedPath = await FileSaver.instance.saveFile(
        name: stem,
        bytes: attachment.bytes,
        fileExtension: extension,
        mimeType: mimeType,
      );
      if (!mounted) return;
      _showSnack(
        savedPath.trim().isEmpty
            ? 'Lampiran berhasil diunduh.'
            : 'Lampiran tersimpan: ${attachment.filename}',
      );
    } on DioException catch (error) {
      if (mounted) _showSnack(_service.extractErrorMessage(error));
    } catch (_) {
      if (mounted) _showSnack('Lampiran tidak dapat diunduh.');
    } finally {
      if (mounted) setState(() => _downloadingAttachment = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PengaduanScaffold(
      title: 'Detail Pengaduan',
      subtitle: 'Status dan riwayat penanganan',
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Muat ulang',
        ),
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _ticket == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          AppSkeleton(height: 120, borderRadius: 18),
          SizedBox(height: 12),
          AppSkeleton(height: 210, borderRadius: 18),
          SizedBox(height: 12),
          AppSkeleton(height: 160, borderRadius: 18),
        ],
      );
    }
    if (_error != null && _ticket == null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }
    final ticket = _ticket!;
    return RefreshIndicator(
      onRefresh: _load,
      color: SkyTheme.instance.accent,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
        children: [
          _headerCard(ticket),
          const SizedBox(height: 12),
          _detailCard(ticket),
          if (ticket.attachmentUrl != null) ...[
            const SizedBox(height: 12),
            SkyAccentBuilder(
              builder: (context, accent, _) {
                return OutlinedButton.icon(
                  onPressed: _downloadingAttachment ? null : _openAttachment,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: accent,
                    side: BorderSide(color: accent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _downloadingAttachment
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accent,
                          ),
                        )
                      : const Icon(Icons.attachment_rounded),
                  label: Text(
                    _downloadingAttachment
                        ? 'Mengunduh Lampiran...'
                        : 'Unduh Lampiran',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 22),
          const Text(
            'Riwayat Pengaduan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: HomeTokens.ink,
            ),
          ),
          const SizedBox(height: 12),
          if (ticket.histories.isEmpty)
            const _EmptyHistory()
          else
            ...List.generate(
              ticket.histories.length,
              (index) => _HistoryItem(
                history: ticket.histories[index],
                isLast: index == ticket.histories.length - 1,
              ),
            ),
        ],
      ),
    );
  }

  Widget _headerCard(Ticket ticket) {
    return SkyAccentBuilder(
      builder: (context, accent, accentSoft) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent, Color.lerp(accent, HomeTokens.headerDeep, 0.45)!],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.ticketNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TicketStatusBadge(status: ticket.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ticket.subject,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Dibuat ${ticketDate(ticket.createdAt, withTime: true)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.76),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailCard(Ticket ticket) {
    final assigned = ticket.assignedEmployee;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomeTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            icon: Icons.category_outlined,
            label: 'Jenis',
            value: ticket.ticketType?.name ?? '-',
          ),
          const Divider(height: 24),
          _InfoRow(
            icon: Icons.support_agent_rounded,
            label: 'HR Penanggung Jawab',
            value: assigned == null
                ? 'Belum ditugaskan'
                : [
                    assigned.name,
                    if (assigned.code != null) '(${assigned.code})',
                  ].join(' '),
          ),
          const Divider(height: 24),
          const Text(
            'Deskripsi',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: HomeTokens.muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ticket.description.isEmpty ? '-' : ticket.description,
            style: const TextStyle(
              color: HomeTokens.ink,
              height: 1.55,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: SkyTheme.instance.accent, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: HomeTokens.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: HomeTokens.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.history, required this.isLast});

  final TicketHistory history;
  final bool isLast;

  String get _title {
    switch (history.action.toUpperCase()) {
      case 'CREATED':
      case 'CREATE':
        return 'Pengaduan dibuat';
      case 'ASSIGNED':
      case 'ASSIGN':
        return 'Penanggung jawab diubah';
      case 'RESOLVED':
      case 'RESOLVE':
        return 'Pengaduan diselesaikan';
      case 'REJECTED':
      case 'REJECT':
        return 'Pengaduan ditolak';
      case 'IN_PROGRESS':
        return 'Mulai diproses';
      case 'REVIEWED':
      case 'REVIEW':
        return 'Review dimulai';
      case 'STATUS_CHANGED':
        return 'Status diperbarui';
      default:
        return history.action.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = history.actor?.name;
    final target = history.targetEmployee?.name;
    final color = SkyTheme.instance.accent;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: HomeTokens.line)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: HomeTokens.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: HomeTokens.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ticketDate(history.createdAt, withTime: true),
                      style: const TextStyle(
                        color: HomeTokens.muted,
                        fontSize: 11,
                      ),
                    ),
                    if (actor != null || target != null) ...[
                      const SizedBox(height: 7),
                      Text(
                        [
                          if (actor != null) 'Oleh $actor',
                          if (target != null) 'Ke $target',
                        ].join(' · '),
                        style: const TextStyle(
                          color: HomeTokens.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (history.description != null) ...[
                      const SizedBox(height: 7),
                      Text(
                        history.description!,
                        style: const TextStyle(height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomeTokens.line),
      ),
      child: const Center(
        child: Text(
          'Belum ada riwayat perubahan.',
          style: TextStyle(color: HomeTokens.muted),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}
