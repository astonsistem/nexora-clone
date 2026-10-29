import 'package:flutter/material.dart';

import '../../../home/theme/home_tokens.dart';

class LegalSection {
  const LegalSection({
    required this.heading,
    this.body,
    this.bullets,
  });

  final String heading;
  final String? body;
  final List<String>? bullets;
}

/// Halaman legal bergaya dokumen (bukan card).
class LegalPage extends StatelessWidget {
  const LegalPage({
    super.key,
    required this.title,
    required this.sections,
  });

  final String title;
  final List<LegalSection> sections;

  factory LegalPage.privacyPolicy() {
    return const LegalPage(
      title: 'Privacy Policy',
      sections: [
        LegalSection(
          heading: 'Pendahuluan',
          body:
              'Kebijakan Privasi ini menjelaskan bagaimana aplikasi Absensi '
              'mengumpulkan, menggunakan, dan melindungi informasi terkait '
              'kehadiran karyawan. Dengan menggunakan aplikasi, Anda memahami '
              'pemrosesan data sebagaimana diuraikan di bawah dalam kerangka '
              'HRIS perusahaan Anda.',
        ),
        LegalSection(
          heading: 'Informasi yang Kami Kumpulkan',
          body:
              'Sesuai kebijakan perusahaan dan izin perangkat, kami dapat '
              'mengumpulkan:',
          bullets: [
            'Nama',
            'ID karyawan',
            'Identitas akun / login',
            'Lokasi GPS (saat absen masuk atau pulang)',
            'Foto / pengenalan wajah untuk absensi (jika diwajibkan)',
            'ID perangkat dan info dasar perangkat untuk keamanan sesi',
            'Riwayat pengajuan cuti / izin',
          ],
        ),
        LegalSection(
          heading: 'Bagaimana Informasi Digunakan',
          body:
              'Informasi digunakan untuk mencatat kehadiran, memverifikasi '
              'lokasi kerja atau aturan WFH, mengelola persetujuan perangkat, '
              'mendukung pelaporan HR, serta menjaga keamanan akun Anda. '
              'Kami tidak menjual data pribadi Anda kepada pihak ketiga.',
        ),
        LegalSection(
          heading: 'Keamanan Data',
          body:
              'Data disimpan pada sistem HRIS perusahaan dengan kontrol akses '
              'berdasarkan peran. Anda bertanggung jawab menjaga kerahasiaan '
              'kredensial login dan menggunakan aplikasi hanya pada perangkat '
              'yang diizinkan.',
        ),
        LegalSection(
          heading: 'Kontak',
          body:
              'Untuk pertanyaan terkait kebijakan ini atau data pribadi Anda, '
              'hubungi tim HR / administrator perusahaan.',
        ),
      ],
    );
  }

  factory LegalPage.termsOfService() {
    return const LegalPage(
      title: 'Terms of Service',
      sections: [
        LegalSection(
          heading: 'Penerimaan Ketentuan',
          body:
              'Dengan mengakses atau menggunakan aplikasi Absensi, Anda '
              'menyetujui Syarat Layanan ini serta kebijakan kehadiran internal '
              'perusahaan. Jika Anda tidak setuju, jangan gunakan aplikasi.',
        ),
        LegalSection(
          heading: 'Penggunaan yang Diizinkan',
          body: 'Anda boleh menggunakan aplikasi hanya untuk:',
          bullets: [
            'Absen masuk dan pulang',
            'Mengajukan cuti atau izin sesuai ketentuan HR',
            'Melihat informasi kehadiran milik Anda sendiri',
          ],
        ),
        LegalSection(
          heading: 'Larangan',
          body: 'Anda tidak boleh:',
          bullets: [
            'Memanipulasi GPS, foto, atau catatan absensi',
            'Menggunakan akun orang lain atau membagikan kredensial login',
            'Mencoba melewati kontrol lokasi, perangkat, atau keamanan',
          ],
        ),
        LegalSection(
          heading: 'Tanggung Jawab',
          body:
              'Anda bertanggung jawab menyampaikan absensi yang akurat sesuai '
              'jadwal dan aturan perusahaan. Perusahaan berhak meninjau catatan '
              'dan menindak pelanggaran sesuai kebijakan internal.',
        ),
        LegalSection(
          heading: 'Ketersediaan Layanan',
          body:
              'Layanan bergantung pada koneksi internet, izin perangkat '
              '(lokasi/kamera), dan ketersediaan server. Gangguan sementara '
              'dapat terjadi tanpa pemberitahuan sebelumnya.',
        ),
        LegalSection(
          heading: 'Kontak',
          body:
              'Pertanyaan terkait ketentuan ini dapat ditujukan ke tim HR / '
              'administrator perusahaan.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: HomeTokens.ink,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: HomeTokens.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: HomeTokens.line),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                itemCount: sections.length,
                separatorBuilder: (_, _) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: HomeTokens.line,
                  ),
                ),
                itemBuilder: (context, index) {
                  final section = sections[index];
                  final number = index + 1;
                  return _DocumentSection(
                    number: number,
                    section: section,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentSection extends StatelessWidget {
  const _DocumentSection({
    required this.number,
    required this.section,
  });

  final int number;
  final LegalSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number. ${section.heading}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: HomeTokens.ink,
            height: 1.3,
          ),
        ),
        if (section.body != null && section.body!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            section.body!,
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              fontWeight: FontWeight.w500,
              color: HomeTokens.ink,
            ),
          ),
        ],
        if (section.bullets != null && section.bullets!.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...section.bullets!.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '•  ',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      fontWeight: FontWeight.w700,
                      color: HomeTokens.ink,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.55,
                        fontWeight: FontWeight.w500,
                        color: HomeTokens.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
