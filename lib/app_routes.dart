import 'package:flutter/material.dart';
import 'package:saanjologin/pages/faq.dart';
import 'package:saanjologin/pages/login_page.dart';
import 'package:saanjologin/pages/register_page.dart';
import 'package:saanjologin/pages/map_page.dart';
import 'package:saanjologin/pages/developer_dashboard.dart';
import 'package:saanjologin/services/add_terminal.dart';
import 'package:saanjologin/services/add_tricycle.dart';
import 'package:saanjologin/services/remove_terminal.dart';
import 'package:saanjologin/services/modify_terminal.dart';
import 'package:saanjologin/services/map_controller.dart';
import 'package:saanjologin/services/ticket_dash.dart'; // Make sure to import your MapController

// Route names
const String loginRoute = '/';
const String registerRoute = '/register';
const String mapPageRoute = '/map_page';
const String developerDashboardRoute = '/developer_dashboard';
const String addTerminalRoute = '/add_terminal';
const String removeTerminalRoute = '/remove_terminal';
const String modifyTerminalRoute = '/modify_terminal';
const String _AddTricycleScreenState = '/add_tricycle';
const String ticketDashboard = '/ticket_dash';
const String faq = '/faq';

// Assuming you have a MapController instance available
final MapController mapController = MapController();

Map<String, WidgetBuilder> getAppRoutes() {
  return {
    _AddTricycleScreenState: (context) => AddTricycleScreen(),
    loginRoute: (context) => const LoginPage(),
    registerRoute: (context) => const RegisterPage(),
    mapPageRoute: (context) => MapPage(),
    developerDashboardRoute: (context) => DeveloperDashboard(),
    addTerminalRoute: (context) => AddTerminalPage(),
    removeTerminalRoute: (context) => RemoveTerminalPage(),
    modifyTerminalRoute: (context) => ModifyTerminalPage(mapController: mapController), 
    ticketDashboard: (context) => TicketDashboard(),
    faq: (context) => FAQPage(),
  };
}
