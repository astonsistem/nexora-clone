import 'package:flutter/material.dart';

import '../../../home/data/models/user_profile.dart';
import '../widgets/profile_shared.dart';

class DataPegawaiPage extends StatelessWidget {
  const DataPegawaiPage({super.key, required this.profile});

  final UserProfile profile;

  String get _scheduleValue {
    final name = profileDisplay(profile.scheduleName);
    final source = profileScheduleSourceLabel(profile.scheduleSource);
    if (name == '-') return source == '-' ? '-' : source;
    if (source == '-' || source == 'Tidak ada') return name;
    return '$name ($source)';
  }

  @override
  Widget build(BuildContext context) {
    return ProfileDetailScaffold(
      title: 'Data Pegawai',
      subtitle: 'Kepegawaian, organisasi, dan BPJS',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
        children: [
          const ProfileFlatSectionLabel('Kepegawaian'),
          const SizedBox(height: 10),
          ProfileFlatField(
            label: 'Kode / NIP',
            value: profileDisplay(profile.code),
            copyable: true,
          ),
          ProfileFlatField(
            label: 'Username',
            value: profileDisplay(profile.username),
          ),
          ProfileFlatField(
            label: 'Status',
            value: profileEmploymentStatusLabel(profile.employmentStatus),
          ),
          ProfileFlatField(
            label: 'Tipe PKWT',
            value: profilePkwtLabel(profile.pkwtType),
          ),
          ProfileFlatField(
            label: 'Status review PKWT',
            value: profilePkwtReviewLabel(profile.pkwtReviewStatus),
          ),
          ProfileFlatField(
            label: 'Tanggal mulai',
            value: profileFormatDate(profile.startedAt),
          ),
          ProfileFlatField(
            label: 'Tanggal berakhir',
            value: profile.endedAt == null || profile.endedAt!.isEmpty
                ? 'Aktif / belum ditentukan'
                : profileFormatDate(profile.endedAt),
          ),
          ProfileFlatField(
            label: 'Peserta Belajar Mandiri',
            value: profileYesNo(profile.isBm),
            showDivider: false,
          ),
          const SizedBox(height: 28),
          const ProfileFlatSectionLabel('Organisasi'),
          const SizedBox(height: 10),
          ProfileFlatField(
            label: 'Perusahaan',
            value: profileDisplay(profile.companyName),
          ),
          ProfileFlatField(
            label: 'Cabang',
            value: profileDisplay(profile.branchName),
          ),
          ProfileFlatField(
            label: 'Lokasi penempatan',
            value: profileDisplay(profile.workLocationName),
          ),
          ProfileFlatField(
            label: 'Alamat cabang',
            value: profileDisplay(profile.branchAddress),
          ),
          ProfileFlatField(
            label: 'Grup struktur',
            value: profileDisplay(profile.groupStructureName),
          ),
          ProfileFlatField(
            label: 'Cost center',
            value: profileDisplay(profile.costCenterName),
          ),
          ProfileFlatField(
            label: 'Jabatan',
            value: profileDisplay(profile.positionName),
          ),
          ProfileFlatField(
            label: 'Divisi',
            value: profileDisplay(profile.divisionName),
          ),
          ProfileFlatField(
            label: 'Grade',
            value: profileDisplay(profile.gradeName),
          ),
          ProfileFlatField(
            label: 'Atasan',
            value: profileDisplay(profile.managerName),
          ),
          ProfileFlatField(
            label: 'Jadwal',
            value: _scheduleValue,
            showDivider: false,
          ),
          const SizedBox(height: 28),
          const ProfileFlatSectionLabel('BPJS'),
          const SizedBox(height: 10),
          ProfileFlatField(
            label: 'No. BPJS TK',
            value: profileDisplay(profile.noBpjstk),
            copyable: true,
          ),
          ProfileFlatField(
            label: 'No. BPJS Kesehatan',
            value: profileDisplay(profile.noBpjskes),
            copyable: true,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}
