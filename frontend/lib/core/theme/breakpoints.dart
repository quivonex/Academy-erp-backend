/// Breakpoints lifted directly from DESIGN.md's "Responsive Breakpoints"
/// section, so every screen queries the same constants.
class AppBreakpoints {
  AppBreakpoints._();

  static const double desktop = 1280;
  static const double laptopTablet = 1024;

  static bool isDesktop(double width) => width >= desktop;
  static bool isLaptopOrTabletLandscape(double width) =>
      width >= laptopTablet && width < desktop;
  static bool isCompact(double width) => width < laptopTablet;
}
