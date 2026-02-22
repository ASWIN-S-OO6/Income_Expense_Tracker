import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/profile.dart';
import '../data/services/local_storage.dart';

final localStorageProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

class ProfileNotifier extends Notifier<Profile?> {
  @override
  Profile? build() {
    final storage = ref.read(localStorageProvider);
    final profiles = storage.profilesBox.values.toList();
    if (profiles.isNotEmpty) {
      return profiles.first;
    }
    return null;
  }

  void setActiveProfile(Profile profile) {
    state = profile;
  }
  
  Future<void> updateCurrency(String symbol, String code) async {
    final current = state;
    if (current == null) return;

    final updatedProfile = Profile(
      id: current.id,
      name: current.name,
      type: current.type,
      currencySymbol: symbol,
      currencyCode: code,
    );
    
    await ref.read(localStorageProvider).profilesBox.put(updatedProfile.id, updatedProfile);
    state = updatedProfile;
    ref.invalidateSelf();
  }

  List<Profile> getAllProfiles() {
    return ref.read(localStorageProvider).profilesBox.values.toList();
  }

  Future<void> createProfile(String name, ProfileType type) async {
    final newProfile = Profile(
      name: name,
      type: type,
      currencySymbol: '\$',
      currencyCode: 'USD',
    );
    await ref.read(localStorageProvider).profilesBox.put(newProfile.id, newProfile);
    
    // Automatically switch to the newly created profile
    setActiveProfile(newProfile);
    ref.invalidateSelf();
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, Profile?>(() {
  return ProfileNotifier();
});
