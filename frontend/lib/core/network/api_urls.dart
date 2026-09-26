/// All API endpoint paths. Base URL is already in Dio, so these are
/// relative paths appended to it.
class ApiUrls {
  ApiUrls._();

  // Auth
  static const String login = '/auth/login/';
  static const String refresh = '/auth/refresh/';
  static const String logout = '/auth/logout/';
  static const String me = '/auth/me/';

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
}