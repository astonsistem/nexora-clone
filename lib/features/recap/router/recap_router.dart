class RecapRouter {
  static const recap = '/recap';
  static const leaveTab = '/recap?tab=leave';
  static const salaryTab = '/recap?tab=salary';

  static String salaryDetail(String id) => '/recap/gaji/$id';
}
