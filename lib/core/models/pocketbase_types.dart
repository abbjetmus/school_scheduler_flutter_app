import 'package:pocketbase/pocketbase.dart';

// --- Collection Names ---

class Collections {
  static const String allowedUsers = 'allowedUsers';
  static const String calendarEvents = 'calendarEvents';
  static const String classes = 'classes';
  static const String foldersAndFiles = 'foldersAndFiles';
  static const String haldorCalendarEvents = 'haldorCalendarEvents';
  static const String registrations = 'registrations';
  static const String schools = 'schools';
  static const String socialMediaLinks = 'socialMediaLinks';
  static const String students = 'students';
  static const String subscriptionCronJobs = 'subscriptionCronJobs';
  static const String subscriptionPages = 'subscriptionPages';
  static const String surveyPages = 'surveyPages';
  static const String users = 'users';
}

// --- Base Types ---

abstract class BaseModel {
  final RecordModel? record;
  final String id;
  final String created;
  final String updated;
  final String collectionId;
  final String collectionName;

  BaseModel({
    this.record,
    required this.id,
    required this.created,
    required this.updated,
    required this.collectionId,
    required this.collectionName,
  });

  BaseModel.fromRecord(RecordModel record)
    : this(
        record: record,
        id: record.id,
        created: record.getStringValue('created'),
        updated: record.getStringValue('updated'),
        collectionId: record.collectionId,
        collectionName: record.collectionName,
      );

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created': created,
      'updated': updated,
      'collectionId': collectionId,
      'collectionName': collectionName,
      ...?record?.data,
    };
  }
}

// --- Collections ---

class School extends BaseModel {
  final String? name;
  final String? address;
  final String? color;
  final String? image;
  final String? allowedEmailDomains;
  final String? haldorSchoolId;

  School({
    required super.id,
    required super.created,
    required super.updated,
    required super.collectionId,
    required super.collectionName,
    this.name,
    this.address,
    this.color,
    this.image,
    this.allowedEmailDomains,
    this.haldorSchoolId,
    super.record,
  });

  factory School.fromRecord(RecordModel record) {
    return School(
      id: record.id,
      created: record.getStringValue('created'),
      updated: record.getStringValue('updated'),
      collectionId: record.collectionId,
      collectionName: record.collectionName,
      name: record.data['name'] as String?,
      address: record.data['address'] as String?,
      color: record.data['color'] as String?,
      image: record.data['image'] as String?,
      allowedEmailDomains: record.data['allowedEmailDomains'] as String?,
      haldorSchoolId: record.data['haldorSchoolId'] as String?,
      record: record,
    );
  }
}

class ClassGroup extends BaseModel {
  final String? name;
  final String? schoolId;
  final List<String> extraInfo;

  ClassGroup({
    required super.id,
    required super.created,
    required super.updated,
    required super.collectionId,
    required super.collectionName,
    this.name,
    this.schoolId,
    this.extraInfo = const [],
    super.record,
  });

  factory ClassGroup.fromRecord(RecordModel record) {
    return ClassGroup(
      id: record.id,
      created: record.getStringValue('created'),
      updated: record.getStringValue('updated'),
      collectionId: record.collectionId,
      collectionName: record.collectionName,
      name: record.data['name'] as String?,
      schoolId: record.data['school'] as String?,
      extraInfo:
          (record.data['extraInfo'] as List<dynamic>?)?.cast<String>() ??
          const [],
      record: record,
    );
  }
}

class Student extends BaseModel {
  final String name;
  final String? email;
  final String? cardId;
  final String classId;
  final String? haldorStudentId;

  Student({
    required super.id,
    required super.created,
    required super.updated,
    required super.collectionId,
    required super.collectionName,
    required this.name,
    required this.classId,
    this.email,
    this.cardId,
    this.haldorStudentId,
    super.record,
  });

  factory Student.fromRecord(RecordModel record) {
    return Student(
      id: record.id,
      created: record.getStringValue('created'),
      updated: record.getStringValue('updated'),
      collectionId: record.collectionId,
      collectionName: record.collectionName,
      name: record.data['name'] as String? ?? '',
      classId: record.data['class'] as String? ?? '',
      email: record.data['email'] as String?,
      cardId: record.data['cardId'] as String?,
      haldorStudentId: record.data['haldorStudentId'] as String?,
      record: record,
    );
  }
}

class Registration extends BaseModel {
  final String studentId;
  final String? haldorCalendarEventId;
  final String? checkedInAt;
  final String? checkedOutAt;

  Registration({
    required super.id,
    required super.created,
    required super.updated,
    required super.collectionId,
    required super.collectionName,
    required this.studentId,
    this.haldorCalendarEventId,
    this.checkedInAt,
    this.checkedOutAt,
    super.record,
  });

  factory Registration.fromRecord(RecordModel record) {
    return Registration(
      id: record.id,
      created: record.getStringValue('created'),
      updated: record.getStringValue('updated'),
      collectionId: record.collectionId,
      collectionName: record.collectionName,
      studentId: record.data['student'] as String? ?? '',
      haldorCalendarEventId: record.data['haldorCalendarEvent'] as String?,
      checkedInAt: record.data['checkedInAt'] as String?,
      checkedOutAt: record.data['checkedOutAt'] as String?,
      record: record,
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'student': studentId,
      if (haldorCalendarEventId != null)
        'haldorCalendarEvent': haldorCalendarEventId,
      if (checkedInAt != null) 'checkedInAt': checkedInAt,
      if (checkedOutAt != null) 'checkedOutAt': checkedOutAt,
    };
  }
}

class HaldorCalendarEvent extends BaseModel {
  final int haldorId;
  final String start;
  final String end;
  final int length;
  final String schoolId;
  final String? subjectCode;
  final String? courseCode;
  final String? extraInfo;
  final List<String> attendance;

  HaldorCalendarEvent({
    required super.id,
    required super.created,
    required super.updated,
    required super.collectionId,
    required super.collectionName,
    required this.haldorId,
    required this.start,
    required this.end,
    required this.length,
    required this.schoolId,
    this.subjectCode,
    this.courseCode,
    this.extraInfo,
    this.attendance = const [],
    super.record,
  });

  factory HaldorCalendarEvent.fromRecord(RecordModel record) {
    return HaldorCalendarEvent(
      id: record.id,
      created: record.getStringValue('created'),
      updated: record.getStringValue('updated'),
      collectionId: record.collectionId,
      collectionName: record.collectionName,
      haldorId: record.data['haldorId'] as int? ?? 0,
      start: record.data['start'] as String? ?? '',
      end: record.data['end'] as String? ?? '',
      length: record.data['length'] as int? ?? 0,
      schoolId: record.data['school'] as String? ?? '',
      subjectCode: record.data['subjectCode'] as String?,
      courseCode: record.data['courseCode'] as String?,
      extraInfo: record.data['extraInfo'] as String?,
      attendance:
          (record.data['attendance'] as List<dynamic>?)?.cast<String>() ??
          const [],
      record: record,
    );
  }
}

// --- User (Auth Collection) ---

class User extends BaseModel {
  final String email;
  final String? name;
  final String? avatar;
  final String? schoolId;
  final String? cardId;
  final String? haldorUserId;
  final bool verified;
  final bool emailVisibility;

  User({
    required super.id,
    required super.created,
    required super.updated,
    required super.collectionId,
    required super.collectionName,
    required this.email,
    this.name,
    this.avatar,
    this.schoolId,
    this.cardId,
    this.haldorUserId,
    this.verified = false,
    this.emailVisibility = false,
    super.record,
  });

  factory User.fromRecord(RecordModel record) {
    return User(
      id: record.id,
      created: record.getStringValue('created'),
      updated: record.getStringValue('updated'),
      collectionId: record.collectionId,
      collectionName: record.collectionName,
      email: record.data['email'] as String? ?? '',
      name: record.data['name'] as String?,
      avatar: record.data['avatar'] as String?,
      schoolId: record.data['school'] as String?,
      cardId: record.data['cardId'] as String?,
      haldorUserId: record.data['haldorUserId'] as String?,
      verified: record.data['verified'] as bool? ?? false,
      emailVisibility: record.data['emailVisibility'] as bool? ?? false,
      record: record,
    );
  }
}

// --- Allowed User ---

class AllowedUser extends BaseModel {
  final String email;
  final String schoolId;
  final String? haldorUserId;

  AllowedUser({
    required super.id,
    required super.created,
    required super.updated,
    required super.collectionId,
    required super.collectionName,
    required this.email,
    required this.schoolId,
    this.haldorUserId,
    super.record,
  });

  factory AllowedUser.fromRecord(RecordModel record) {
    return AllowedUser(
      id: record.id,
      created: record.getStringValue('created'),
      updated: record.getStringValue('updated'),
      collectionId: record.collectionId,
      collectionName: record.collectionName,
      email: record.data['email'] as String? ?? '',
      schoolId: record.data['school'] as String? ?? '',
      haldorUserId: record.data['haldorUserId'] as String?,
      record: record,
    );
  }
}

// --- Calendar Event ---

class CalendarEvent extends BaseModel {
  final String lessonGuid;
  final String? summary;
  final String? description;
  final String start;
  final String end;
  final String? classId;

  CalendarEvent({
    required super.id,
    required super.created,
    required super.updated,
    required super.collectionId,
    required super.collectionName,
    required this.lessonGuid,
    this.summary,
    this.description,
    required this.start,
    required this.end,
    this.classId,
    super.record,
  });

  factory CalendarEvent.fromRecord(RecordModel record) {
    return CalendarEvent(
      id: record.id,
      created: record.getStringValue('created'),
      updated: record.getStringValue('updated'),
      collectionId: record.collectionId,
      collectionName: record.collectionName,
      lessonGuid: record.data['lessonGuid'] as String? ?? '',
      summary: record.data['summary'] as String?,
      description: record.data['description'] as String?,
      start: record.data['start'] as String? ?? '',
      end: record.data['end'] as String? ?? '',
      classId: record.data['class'] as String?,
      record: record,
    );
  }
}

// --- Survey Types ---

class SurveyOption {
  final String id;
  final String title;
  final String? icon;
  final String? iconColor;
  final String? color;
  final int votes;

  SurveyOption({
    required this.id,
    required this.title,
    this.icon,
    this.iconColor,
    this.color,
    this.votes = 0,
  });

  factory SurveyOption.fromJson(Map<String, dynamic> json) {
    return SurveyOption(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      icon: json['icon'] as String?,
      iconColor: json['iconColor'] as String?,
      color: json['color'] as String?,
      votes: json['votes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (icon != null) 'icon': icon,
      if (iconColor != null) 'iconColor': iconColor,
      if (color != null) 'color': color,
      'votes': votes,
    };
  }
}

class SurveyPage extends BaseModel {
  final String title;
  final String schoolId;
  final List<SurveyOption> options;

  SurveyPage({
    required super.id,
    required super.created,
    required super.updated,
    required super.collectionId,
    required super.collectionName,
    required this.title,
    required this.schoolId,
    this.options = const [],
    super.record,
  });

  factory SurveyPage.fromRecord(RecordModel record) {
    final optionsRaw = record.data['options'] as List<dynamic>?;
    final options =
        optionsRaw
            ?.map(
              (e) => SurveyOption.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        [];

    return SurveyPage(
      id: record.id,
      created: record.getStringValue('created'),
      updated: record.getStringValue('updated'),
      collectionId: record.collectionId,
      collectionName: record.collectionName,
      title: record.data['title'] as String? ?? '',
      schoolId: record.data['school'] as String? ?? '',
      options: options,
      record: record,
    );
  }
}

// --- Subscription Types ---

class SubscriptionCalendarEvent {
  final String id;
  final String title;
  final String start;
  final String end;

  SubscriptionCalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
  });

  factory SubscriptionCalendarEvent.fromJson(Map<String, dynamic> json) {
    return SubscriptionCalendarEvent(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      start: json['start'] as String? ?? '',
      end: json['end'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title, 'start': start, 'end': end};
  }
}

class EventNotificationLeadMinutes {
  final String id;
  final int minutesBeforeEvent;

  EventNotificationLeadMinutes({
    required this.id,
    required this.minutesBeforeEvent,
  });

  factory EventNotificationLeadMinutes.fromJson(Map<String, dynamic> json) {
    return EventNotificationLeadMinutes(
      id: json['id'] as String? ?? '',
      minutesBeforeEvent: json['minutesBeforeEvent'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'minutesBeforeEvent': minutesBeforeEvent};
  }
}

class SubscriptionPage extends BaseModel {
  final String? title;
  final String? schoolId;
  final List<SubscriptionCalendarEvent> calendarEvents;
  final List<String> emails;
  final List<String> phoneNumbers;
  final List<EventNotificationLeadMinutes> eventNotificationLeadMinutes;
  final String? registrationLink;
  final String? unRegistrationLink;

  SubscriptionPage({
    required super.id,
    required super.created,
    required super.updated,
    required super.collectionId,
    required super.collectionName,
    this.title,
    this.schoolId,
    this.calendarEvents = const [],
    this.emails = const [],
    this.phoneNumbers = const [],
    this.eventNotificationLeadMinutes = const [],
    this.registrationLink,
    this.unRegistrationLink,
    super.record,
  });

  factory SubscriptionPage.fromRecord(RecordModel record) {
    final calEventsRaw = record.data['calendarEvents'] as List<dynamic>?;
    final calEvents =
        calEventsRaw
            ?.map(
              (e) =>
                  SubscriptionCalendarEvent.fromJson(
                    e as Map<String, dynamic>,
                  ),
            )
            .toList() ??
        [];

    final emailsRaw = record.data['emails'] as List<dynamic>?;
    final emails = emailsRaw?.cast<String>() ?? [];

    final phonesRaw = record.data['phoneNumbers'] as List<dynamic>?;
    final phones = phonesRaw?.cast<String>() ?? [];

    final leadMinutesRaw =
        record.data['eventNotificationLeadMinutes'] as List<dynamic>?;
    final leadMinutes =
        leadMinutesRaw
            ?.map(
              (e) =>
                  EventNotificationLeadMinutes.fromJson(
                    e as Map<String, dynamic>,
                  ),
            )
            .toList() ??
        [];

    return SubscriptionPage(
      id: record.id,
      created: record.getStringValue('created'),
      updated: record.getStringValue('updated'),
      collectionId: record.collectionId,
      collectionName: record.collectionName,
      title: record.data['title'] as String?,
      schoolId: record.data['school'] as String?,
      calendarEvents: calEvents,
      emails: emails,
      phoneNumbers: phones,
      eventNotificationLeadMinutes: leadMinutes,
      registrationLink: record.data['registrationLink'] as String?,
      unRegistrationLink: record.data['unRegistrationLink'] as String?,
      record: record,
    );
  }
}

// --- Folder & Files ---

class FolderAndFile extends BaseModel {
  final String name;
  final String? parentFolder;
  final String path;
  final String schoolId;
  final List<String> files;

  FolderAndFile({
    required super.id,
    required super.created,
    required super.updated,
    required super.collectionId,
    required super.collectionName,
    required this.name,
    this.parentFolder,
    required this.path,
    required this.schoolId,
    this.files = const [],
    super.record,
  });

  factory FolderAndFile.fromRecord(RecordModel record) {
    return FolderAndFile(
      id: record.id,
      created: record.getStringValue('created'),
      updated: record.getStringValue('updated'),
      collectionId: record.collectionId,
      collectionName: record.collectionName,
      name: record.data['name'] as String? ?? '',
      parentFolder: record.data['parentFolder'] as String?,
      path: record.data['path'] as String? ?? '',
      schoolId: record.data['school'] as String? ?? '',
      files:
          (record.data['files'] as List<dynamic>?)?.cast<String>() ?? const [],
      record: record,
    );
  }
}

// --- Social Media Links ---

class SocialMediaLink extends BaseModel {
  final String? title;
  final String? url;
  final String? icon;
  final String schoolId;

  SocialMediaLink({
    required super.id,
    required super.created,
    required super.updated,
    required super.collectionId,
    required super.collectionName,
    this.title,
    this.url,
    this.icon,
    required this.schoolId,
    super.record,
  });

  factory SocialMediaLink.fromRecord(RecordModel record) {
    return SocialMediaLink(
      id: record.id,
      created: record.getStringValue('created'),
      updated: record.getStringValue('updated'),
      collectionId: record.collectionId,
      collectionName: record.collectionName,
      title: record.data['title'] as String?,
      url: record.data['url'] as String?,
      icon: record.data['icon'] as String?,
      schoolId: record.data['school'] as String? ?? '',
      record: record,
    );
  }
}
