import 'package:cloudinary/cloudinary.dart';
import 'package:uuid/uuid.dart';

/// One shared Cloudinary config for the whole app. Chat media (images,
/// files) already uploaded through Cloudinary directly inside
/// `chat_screen.dart` — this just centralizes that same unsigned config so
/// every other feature (profile photos, group avatars, etc.) uploads
/// through the same place instead of re-declaring `Cloudinary.unsignedConfig`
/// everywhere, and so Firebase Storage isn't needed for media at all.
class CloudinaryService {
  CloudinaryService._();

  static final CloudinaryService instance = CloudinaryService._();

  static const String _cloudName = 'dddqkqlh8';
  static const String _uploadPreset = 'ml_default';

  final Cloudinary _cloudinary = Cloudinary.unsignedConfig(
    cloudName: _cloudName,
  );

  final _uuid = const Uuid();

  /// Uploads raw image bytes and returns the secure (https) URL, or null if
  /// the upload failed.
  Future<String?> uploadImage(
    List<int> bytes, {
    required String folder,
    String? fileName,
  }) async {
    final response = await _cloudinary.unsignedUpload(
      fileBytes: bytes,
      uploadPreset: _uploadPreset,
      resourceType: CloudinaryResourceType.image,
      folder: folder,
      fileName: fileName ?? _uuid.v4(),
    );
    return response.isSuccessful ? response.secureUrl : null;
  }

  /// Uploads any non-image file (pdf, docx, zip, etc.) and returns the
  /// secure URL, or null if the upload failed.
  Future<String?> uploadRawFile(
    List<int> bytes, {
    required String folder,
    required String fileName,
  }) async {
    final response = await _cloudinary.unsignedUpload(
      fileBytes: bytes,
      uploadPreset: _uploadPreset,
      resourceType: CloudinaryResourceType.raw,
      folder: folder,
      fileName: fileName,
    );
    return response.isSuccessful ? response.secureUrl : null;
  }
}
