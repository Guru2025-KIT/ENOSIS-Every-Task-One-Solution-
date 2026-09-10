import 'package:flutter_test/flutter_test.dart';
import 'package:enosis/features/career/data/achievement_repository.dart';

void main() {
  group('AchievementModel & AchievementRepository Persistence Tests', () {
    test('AchievementModel JSON serialization and deserialization with Cloudinary attributes', () {
      final json = {
        'id': 'ach-uuid-1234',
        'faculty_id': 'FAC-2026-042',
        'category': 'certification',
        'title': 'Certified Kubernetes Administrator',
        'organization': 'CNCF',
        'date_achieved': '2026-08-15',
        'description': 'Passed CKA exam with distinction.',
        'document_id': 'doc-uuid-5678',
        'file_name': 'cka_certificate.pdf',
        'document_url': 'https://res.cloudinary.com/demo/image/upload/v1/enosis/cka_certificate.pdf',
        'file_size': '1.5 MB',
        'cloudinary_public_id': 'ENOSIS/Faculty/FAC-2026-042/Career_Advancement/Certificates/cka_certificate',
        'created_at': '2026-08-15T10:00:00.000Z',
      };

      final model = AchievementModel.fromJson(json);

      expect(model.id, 'ach-uuid-1234');
      expect(model.facultyId, 'FAC-2026-042');
      expect(model.achievementType, 'certification');
      expect(model.title, 'Certified Kubernetes Administrator');
      expect(model.documentId, 'doc-uuid-5678');
      expect(model.fileName, 'cka_certificate.pdf');
      expect(model.filePath, 'https://res.cloudinary.com/demo/image/upload/v1/enosis/cka_certificate.pdf');
      expect(model.hasCloudinaryUrl, isTrue);
      expect(model.cloudinaryPublicId, 'ENOSIS/Faculty/FAC-2026-042/Career_Advancement/Certificates/cka_certificate');

      final serialized = model.toJson();
      expect(serialized['id'], 'ach-uuid-1234');
      expect(serialized['document_id'], 'doc-uuid-5678');
      expect(serialized['file_path'], 'https://res.cloudinary.com/demo/image/upload/v1/enosis/cka_certificate.pdf');
    });

    test('AchievementRepository creates and deletes local achievement correctly', () async {
      final repo = AchievementRepository();
      repo.clearForTest();

      final created = await repo.createAchievement(
        title: 'Deep Learning Specialization',
        achievementType: 'course',
        organization: 'DeepLearning.AI',
        fileName: 'dl_cert.pdf',
        fileSize: '950 KB',
      );

      expect(created.title, 'Deep Learning Specialization');
      expect(created.achievementType, 'course');

      var list = await repo.fetchMyAchievements();
      expect(list.length, 1);
      expect(list.first.id, created.id);

      await repo.deleteAchievement(created.id);

      list = await repo.fetchMyAchievements();
      expect(list.isEmpty, isTrue);
    });

    test('All 10 Achievement Category Options mapped correctly to Cloudinary folders', () {
      expect(getCategoryOption('certification').storageFolder, 'Certificates');
      expect(getCategoryOption('fdp').storageFolder, 'FDPs');
      expect(getCategoryOption('webinar').storageFolder, 'Webinars');
      expect(getCategoryOption('workshop').storageFolder, 'Workshops');
      expect(getCategoryOption('conference').storageFolder, 'Conferences');
      expect(getCategoryOption('publication').storageFolder, 'Publications');
      expect(getCategoryOption('award').storageFolder, 'Awards');
      expect(getCategoryOption('research').storageFolder, 'Research_Patents');
      expect(getCategoryOption('course').storageFolder, 'Courses');
      expect(getCategoryOption('other').storageFolder, 'Other');
    });
  });
}
