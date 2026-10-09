/// All API endpoint paths. Base URL is already in Dio, so these are
/// relative paths appended to it.
class ApiUrls {
  ApiUrls._();

  // Auth
  static const String login = '/auth/login/';
  static const String refresh = '/auth/refresh/';
  static const String logout = '/auth/logout/';
  static const String me = '/auth/me/';
  static const String passwordResetRequest = '/auth/password-reset/request/';
  static const String passwordResetConfirm = '/auth/password-reset/confirm/';

  // Firms
  static const String firms = '/firms/';
  static String firmDetail(String uuid) => '/firms/$uuid/';
  static String firmActivate(String uuid) => '/firms/$uuid/activate/';
  static String firmDeactivate(String uuid) => '/firms/$uuid/deactivate/';

  // Firms — admins
  static String firmAdmins(String firmUuid) => '/firms/$firmUuid/admins/';
  static String firmAdminCreate(String firmUuid) => '/firms/$firmUuid/admins/create/';
  static const String allFirmAdmins = '/firms/firm-admins/';
  // Firm Admin: students and courses
  static const String students = '/students/';
  static String studentDetail(String uuid) => '/students/$uuid/';
  static String studentStatus(String uuid, bool active) =>
      '/students/$uuid/${active ? 'activate' : 'deactivate'}/';
  static String studentEnableLogin(String uuid) => '/students/$uuid/enable-login/';
  static const String courses = '/courses/';
  static String courseDetail(String uuid) => '/courses/$uuid/';

  // Course Categories
  static const String courseCategories = '/course-categories/';
  static String courseCategoryDetail(String uuid) => '/course-categories/$uuid/';

  // Teachers
  static const String teachers = '/teachers/';
  static String teacherDetail(String uuid) => '/teachers/$uuid/';
  static String teacherActivate(String uuid) => '/teachers/$uuid/activate/';
  static String teacherDeactivate(String uuid) => '/teachers/$uuid/deactivate/';

  // Staff
  static const String staff = '/staff/';
  static String staffDetail(String uuid) => '/staff/$uuid/';
  static String staffActivate(String uuid) => '/staff/$uuid/activate/';
  static String staffDeactivate(String uuid) => '/staff/$uuid/deactivate/';

  // Enrollments
  static const String enrollments = '/enrollments/';
  static String enrollmentDetail(String uuid) => '/enrollments/$uuid/';
  static const String bulkEnrollmentByAdmissionDate =
      '/enrollments/bulk-assign-by-admission-date/';

  // Live Classes
  static const String liveClasses = '/live-classes/';
  static String liveClassDetail(String uuid) => '/live-classes/$uuid/';
  static String liveClassStart(String uuid) => '/live-classes/$uuid/start/';
  static String liveClassComplete(String uuid) => '/live-classes/$uuid/complete/';
  static String liveClassCancel(String uuid) => '/live-classes/$uuid/cancel/';

  // Materials
  static const String materials = '/materials/';
  static String materialDetail(String uuid) => '/materials/$uuid/';

  // Assignments
  static const String assignments = '/assignments/';
  static String adminAssignmentDetail(String uuid) =>
      '/assignments/$uuid/';
  static String assignmentQuestions(String uuid) =>
      '/assignments/$uuid/questions/';
  static String assignmentQuestionDetail(
    String assignmentUuid,
    String questionUuid,
  ) =>
      '/assignments/$assignmentUuid/questions/$questionUuid/';
  static String assignmentPublish(String uuid) =>
      '/assignments/$uuid/publish/';
  static String assignmentUnpublish(String uuid) =>
      '/assignments/$uuid/unpublish/';
  static const String assignmentPdfImport =
      '/assignments/import-pdf/';
  static String assignmentSubmissions(String uuid) =>
      '/assignments/$uuid/submissions/';
  static String assignmentSubmissionDetail(
    String submissionUuid,
  ) =>
      '/assignments/submissions/$submissionUuid/';
  static String assignmentSubmissionGrade(
    String submissionUuid,
  ) =>
      '/assignments/submissions/$submissionUuid/grade/';

  // Subjects
  static const String subjects = '/subjects/';
  static String subjectDetail(String uuid) => '/subjects/$uuid/';

  // Chapters
  static const String chapters = '/chapters/';
  static String chapterDetail(String uuid) => '/chapters/$uuid/';

  // Lessons
  static const String lessons = '/lessons/';
  static String lessonDetail(String uuid) => '/lessons/$uuid/';
  static const String studentRegister = '/auth/student/register/';

  static const String publicCourses = '/public/courses/';
  static const String publicCategories = '/public/courses/categories/';
  static String publicCourse(String uuid) => '/public/courses/$uuid/';

  static const String myCourses = '/student/courses/';
  static String myCourse(String uuid) => '/student/courses/$uuid/';
  static String myCourseMaterials(String uuid) =>
      '/student/courses/$uuid/materials/';
  static String myCourseClasses(String uuid) =>
      '/student/courses/$uuid/live-classes/';
  static const String publicBanners = '/public/banners/';

  // Banners - Admin
  static const String banners = '/banners/';
  static String bannerDetail(String uuid) => '/banners/$uuid/';

  static String studentMaterial(String uuid) =>
      '/student/materials/$uuid/';

  static String materialProgress(String uuid) =>
      '/student/materials/$uuid/progress/';

  static String courseProgress(String uuid) =>
      '/student/courses/$uuid/progress/';

  static const String studentLiveClasses = '/student/live-classes/';

  static String studentLiveClass(String uuid) =>
      '/student/live-classes/$uuid/';

  static String courseAssignments(String courseUuid) =>
      '/student/courses/$courseUuid/assignments/';

  static String assignmentDetail(String uuid) =>
      '/student/assignments/$uuid/';

  static String assignmentSubmit(String uuid) =>
      '/student/assignments/$uuid/submit/';

  static String assignmentResult(String uuid) =>
      '/student/assignments/$uuid/result/';

  // Student Payments
  static const String studentCoursePayments =
      '/student/course-payments/';

  // Admin Payments (legacy)
  // NOTE: the backend retired the student-submitted payment flow.
  // GET still lists old requests, but PATCH .../review/ now returns 410 Gone.
  // Use fee accounts + installments below instead.
  static const String payments =
      '/payments/';

  static String paymentReview(String uuid) =>
      '/payments/$uuid/review/';

  // Fees (admin / staff)
  static const String feeAccounts = '/payments/fee-accounts/';
  static const String installments = '/payments/installments/';
  static String installmentVoid(String uuid) =>
      '/payments/installments/$uuid/void/';

  // Fees (student)
  static const String studentFeeAccounts = '/student/fee-accounts/';
}