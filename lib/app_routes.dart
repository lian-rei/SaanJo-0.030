import 'package:flutter/material.dart';
import 'package:saanjologin/pages/login_page.dart';
import 'package:saanjologin/pages/register_page.dart';
import 'package:saanjologin/pages/map_page.dart';
import 'package:saanjologin/pages/developer_dashboard.dart';
import 'package:saanjologin/services/add_terminal.dart';
import 'package:saanjologin/services/remove_terminal.dart';
import 'package:saanjologin/services/modify_terminal.dart';

// Route names
const String loginRoute = '/';
const String registerRoute = '/register';
const String mapPageRoute = '/map_page';
const String developerDashboardRoute = '/developer_dashboard';
const String addTerminalRoute = '/add_terminal';
const String removeTerminalRoute = '/remove_terminal';
const String modifyTerminalRoute = '/modify_terminal';

// Function to get all routes
Map<String, WidgetBuilder> getAppRoutes() {
  return {
    loginRoute: (context) => const LoginPage(),
    registerRoute: (context) => const RegisterPage(),
    mapPageRoute: (context) => MapPage(),
    developerDashboardRoute: (context) => DeveloperDashboard(),
    addTerminalRoute: (context) => AddTerminalPage(),
    removeTerminalRoute: (context) => RemoveTerminalPage(),
    modifyTerminalRoute: (context) => ModifyTerminalPage(),
  };
}
