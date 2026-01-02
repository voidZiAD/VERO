import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

class GamificationService {
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  Future<Map<String, dynamic>> calculateRewards(int minutes) async {
    if (minutes <= 0) return {};
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    final userData = await AuthService().getDecryptedUserData();
    if (userData == null) return {};

    int currentXp = userData['xp'] ?? 0;
    List<String> currentBadges = List<String>.from(userData['badges'] ?? []);

    int xpEarned = minutes * 10;
    int newXp = currentXp + xpEarned;

    List<String> newBadges = _checkNewBadges(newXp, currentBadges);

    return {
      'xp': newXp,
      'badges': newBadges,
      'xpEarned': xpEarned
    };
  }

  Future<void> awardPoints(int minutes) async {
    final result = await calculateRewards(minutes);
    if (result.isNotEmpty) {
      await AuthService().updateUserSessionStats(
        xp: result['xp'],
        badges: result['badges']
      );
    }
  }

  List<String> _checkNewBadges(int xp, List<String> currentBadges) {
    List<String> updated = List.from(currentBadges);
    
    if (xp >= 1000 && !updated.contains('novice')) updated.add('novice');
    if (xp >= 5000 && !updated.contains('apprentice')) updated.add('apprentice');
    if (xp >= 10000 && !updated.contains('master')) updated.add('master');
    if (xp >= 50000 && !updated.contains('grandmaster')) updated.add('grandmaster');

    return updated;
  }

  int getLevel(int xp) {
    return (xp / 1000).floor() + 1;
  }

  double getLevelProgress(int xp) {
    int currentLevelXp = (getLevel(xp) - 1) * 1000;
    int nextLevelXp = getLevel(xp) * 1000;
    return (xp - currentLevelXp) / (nextLevelXp - currentLevelXp);
  }

  String getBadgeName(String id) {
    switch (id) {
      case 'novice': return 'Novice Focus';
      case 'apprentice': return 'Apprentice';
      case 'master': return 'Focus Master';
      case 'grandmaster': return 'Grandmaster';
      default: return 'Unknown';
    }
  }
}
