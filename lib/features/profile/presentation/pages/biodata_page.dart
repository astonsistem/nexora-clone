import 'package:flutter/material.dart';

import '../../../home/data/models/user_profile.dart';
import '../widgets/profile_shared.dart';

class BiodataPage extends StatelessWidget {
  const BiodataPage({super.key, required this.profile});

  final UserProfile profile;

  String get _birthPlaceDate {
    final place = profileDisplay(profile.birthPlace);
    final date = profileFormatDate(profile.birthDate);
    if (place == '-' && date == '-') return '-';
    if (place == '-') return date;
    if (date == '-') return place;
    return '$place, $date';
  }

  @override
  Widget build(BuildContext context) {
    return ProfileDetailScaffold(
      title: 'Biodata Pegawai',
      subtitle: 'Data diri dan identitas',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
        children: [
          const ProfileFlatSectionLabel('Identitas'),
          const SizedBox(height: 10),
          ProfileFlatField(label: 'Nama', value: profileDisplay(profile.name)),
          ProfileFlatField(
            label: 'NIK / KTP',
            value: profileDisplay(profile.nik),
            copyable: true,
          ),
          ProfileFlatField(
            label: 'Jenis kelamin',
            value: profileGenderLabel(profile.gender),
          ),
          ProfileFlatField(
            label: 'Tempat & tanggal lahir',
            value: _birthPlaceDate,
          ),
          ProfileFlatField(
            label: 'Agama',
            value: profileReligionLabel(profile.religion),
          ),
          ProfileFlatField(
            label: 'Status kawin',
            value: profileMaritalLabel(profile.maritalStatus),
            showDivider: false,
          ),
          const SizedBox(height: 28),
          const ProfileFlatSectionLabel('Kontak & alamat'),
          const SizedBox(height: 10),
          ProfileFlatField(
            label: 'Email',
            value: profileDisplay(profile.email),
            copyable: true,
          ),
          ProfileFlatField(
            label: 'No. telepon',
            value: profileDisplay(profile.phone),
            copyable: true,
          ),
          ProfileFlatField(
            label: 'Alamat',
            value: profileDisplay(profile.address),
            showDivider: false,
          ),
        ],
      ),
    );
  }
}
