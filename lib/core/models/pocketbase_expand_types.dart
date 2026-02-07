import 'pocketbase_types.dart';

// Expand definitions for strongly typed relations

class RegistrationExpand {
  final Student? student;
  final HaldorCalendarEvent? haldorCalendarEvent;

  RegistrationExpand({this.student, this.haldorCalendarEvent});

  factory RegistrationExpand.fromJson(Map<String, dynamic> json) {
    return RegistrationExpand(
      student:
          json['student'] != null
              ? Student.fromRecord(json['student'])
              : null,
      haldorCalendarEvent:
          json['haldorCalendarEvent'] != null
              ? HaldorCalendarEvent.fromRecord(json['haldorCalendarEvent'])
              : null,
    );
  }
}

class StudentExpand {
  final ClassGroup? classGroup;

  StudentExpand({this.classGroup});

  factory StudentExpand.fromJson(Map<String, dynamic> json) {
    return StudentExpand(
      classGroup:
          json['class'] != null
              ? ClassGroup.fromRecord(json['class'])
              : null,
    );
  }
}

class FolderAndFileExpand {
  final List<FolderAndFile> subfolders;

  FolderAndFileExpand({this.subfolders = const []});

  factory FolderAndFileExpand.fromJson(Map<String, dynamic> json) {
    final subfoldersRaw =
        json['foldersAndFilesViaParentFolder'] as List<dynamic>?;
    final subfolders =
        subfoldersRaw?.map((e) => FolderAndFile.fromRecord(e)).toList() ?? [];

    return FolderAndFileExpand(subfolders: subfolders);
  }
}
