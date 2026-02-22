import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';

class L {
  L._();

  static final Map<String, Map<String, String>> _translations = {
    // ── Login page ──────────────────────────────────────────────────
    'login_title': {
      'en': 'Lemuru Receipt Scanner',
      'sw': 'Lemuru Skana ya Risiti',
    },
    'login_subtitle': {
      'en': 'Please login to continue',
      'sw': 'Tafadhali ingia ili kuendelea',
    },
    'email_label': {
      'en': 'Email',
      'sw': 'Barua pepe',
    },
    'email_hint': {
      'en': 'Enter your email',
      'sw': 'Ingiza barua pepe yako',
    },
    'password_label': {
      'en': 'Password',
      'sw': 'Nenosiri',
    },
    'password_hint': {
      'en': 'Enter your password',
      'sw': 'Ingiza nenosiri lako',
    },
    'login_button': {
      'en': 'Login',
      'sw': 'Ingia',
    },
    'powered_by': {
      'en': 'Powered by Moinfotech',
      'sw': 'Imetengenezwa na Moinfotech',
    },
    'email_required': {
      'en': 'Please enter your email',
      'sw': 'Tafadhali ingiza barua pepe yako',
    },
    'email_invalid': {
      'en': 'Please enter a valid email',
      'sw': 'Tafadhali ingiza barua pepe sahihi',
    },
    'password_required': {
      'en': 'Please enter your password',
      'sw': 'Tafadhali ingiza nenosiri lako',
    },
    'password_too_short': {
      'en': 'Password must be at least 6 characters',
      'sw': 'Nenosiri lazima liwe na herufi 6 au zaidi',
    },
    'biometric_reason': {
      'en': 'Authenticate to login',
      'sw': 'Thibitisha ili kuingia',
    },
    'biometric_login': {
      'en': 'Login with biometrics',
      'sw': 'Ingia kwa alama za kibayolojia',
    },
    'biometric_failed': {
      'en': 'Biometric authentication failed',
      'sw': 'Uthibitishaji wa kibayolojia umeshindikana',
    },
    'biometric_login_first': {
      'en': 'Please login with email & password first',
      'sw': 'Tafadhali ingia kwa barua pepe na nywila kwanza',
    },
    'session_expired': {
      'en': 'Session expired. Please login again',
      'sw': 'Muda wa kipindi umekwisha. Tafadhali ingia tena',
    },
    'login_success': {
      'en': 'Login successful!',
      'sw': 'Umefanikiwa kuingia!',
    },
    'invalid_server_response': {
      'en': 'Invalid server response. Please try again.',
      'sw': 'Jibu la seva si sahihi. Tafadhali jaribu tena.',
    },
    'network_error': {
      'en': 'Network error',
      'sw': 'Hitilafu ya mtandao',
    },

    // ── Home page ───────────────────────────────────────────────────
    'app_title': {
      'en': 'Lemuru Scanner',
      'sw': 'Lemuru Skana',
    },
    'search_hint': {
      'en': 'Search by company name...',
      'sw': 'Tafuta kwa jina la kampuni...',
    },
    'date_range': {
      'en': 'Date range',
      'sw': 'Kipindi cha tarehe',
    },
    'receipt_count': {
      'en': 'receipt',
      'sw': 'risiti',
    },
    'receipts_count': {
      'en': 'receipts',
      'sw': 'risiti',
    },
    'logout': {
      'en': 'Logout',
      'sw': 'Toka',
    },
    'confirm_logout': {
      'en': 'Confirm Logout',
      'sw': 'Thibitisha Kutoka',
    },
    'logout_confirm_msg': {
      'en': 'Are you sure you want to logout?',
      'sw': 'Una uhakika unataka kutoka?',
    },
    'cancel': {
      'en': 'Cancel',
      'sw': 'Ghairi',
    },
    'logged_out': {
      'en': 'Logged out successfully',
      'sw': 'Umetoka kwa mafanikio',
    },
    'ok': {
      'en': 'OK',
      'sw': 'Sawa',
    },
    'offline_mode': {
      'en': 'Offline Mode',
      'sw': 'Hali ya Nje ya Mtandao',
    },
    'logged_in_as': {
      'en': 'Logged in as',
      'sw': 'Umeingia kama',
    },

    // ── Receipt detail page ──────────────────────────────────────────
    'section_customer': {
      'en': 'Customer',
      'sw': 'Mteja',
    },
    'section_receipt_details': {
      'en': 'Receipt Details',
      'sw': 'Maelezo ya Risiti',
    },
    'section_items': {
      'en': 'Items',
      'sw': 'Bidhaa',
    },
    'section_adjustments': {
      'en': 'Adjustments',
      'sw': 'Marekebisho',
    },
    'section_payments': {
      'en': 'Payments',
      'sw': 'Malipo',
    },
    'section_totals': {
      'en': 'Totals',
      'sw': 'Jumla',
    },
    'label_name': {
      'en': 'Name',
      'sw': 'Jina',
    },
    'label_id_type': {
      'en': 'ID Type',
      'sw': 'Aina ya Kitambulisho',
    },
    'label_id': {
      'en': 'ID',
      'sw': 'Kitambulisho',
    },
    'label_mobile': {
      'en': 'Mobile',
      'sw': 'Simu',
    },
    'label_receipt_no': {
      'en': 'Receipt No',
      'sw': 'Nambari ya Risiti',
    },
    'label_z_number': {
      'en': 'Z Number',
      'sw': 'Nambari ya Z',
    },
    'table_description': {
      'en': 'DESCRIPTION',
      'sw': 'MAELEZO',
    },
    'table_qty': {
      'en': 'QTY',
      'sw': 'IDADI',
    },
    'table_amount': {
      'en': 'AMOUNT',
      'sw': 'KIASI',
    },
    'table_type': {
      'en': 'Type',
      'sw': 'Aina',
    },
    'table_description_lower': {
      'en': 'Description',
      'sw': 'Maelezo',
    },
    'table_amount_lower': {
      'en': 'Amount',
      'sw': 'Kiasi',
    },
    'total_excl_tax': {
      'en': 'Total Excl. of Tax',
      'sw': 'Jumla Bila Kodi',
    },
    'total_tax': {
      'en': 'Total Tax',
      'sw': 'Jumla ya Kodi',
    },
    'total_label': {
      'en': 'TOTAL',
      'sw': 'JUMLA',
    },
    'kwh_charge': {
      'en': 'KWH Charge',
      'sw': 'Malipo ya KWH',
    },
    'kva_charge': {
      'en': 'KVA Charge',
      'sw': 'Malipo ya KVA',
    },
    'service_charge': {
      'en': 'Service Charge',
      'sw': 'Malipo ya Huduma',
    },
    'interest_amount': {
      'en': 'Interest Amount',
      'sw': 'Kiasi cha Riba',
    },
    'rea_label': {
      'en': 'REA',
      'sw': 'REA',
    },
    'ewura_label': {
      'en': 'EWURA',
      'sw': 'EWURA',
    },
    'property_tax': {
      'en': 'Property Tax',
      'sw': 'Kodi ya Mali',
    },
    'failed_open_browser': {
      'en': 'Failed to open browser',
      'sw': 'Imeshindwa kufungua kivinjari',
    },
    'close': {
      'en': 'Close',
      'sw': 'Funga',
    },

    // ── Scan page ───────────────────────────────────────────────────
    'scan_title': {
      'en': 'Scan',
      'sw': 'Skani',
    },
    'please_wait': {
      'en': 'Please wait...',
      'sw': 'Tafadhali subiri...',
    },
    'receipt_already_scanned': {
      'en': 'Receipt already scanned!',
      'sw': 'Risiti tayari imeskanwa!',
    },
    'receipt_incorrect': {
      'en': 'Receipt Incorrect',
      'sw': 'Risiti si sahihi',
    },
    'try_again': {
      'en': 'Try Again',
      'sw': 'Jaribu Tena',
    },
    'scan_success': {
      'en': 'Receipt scanned and uploaded successfully!',
      'sw': 'Risiti imeskanwa na kupakiwa kwa mafanikio!',
    },
    'receipt_exists': {
      'en': 'Receipt already exists',
      'sw': 'Risiti tayari ipo',
    },
    'scan_failed_complete': {
      'en': 'Failed to get complete receipt data',
      'sw': 'Imeshindwa kupata data kamili ya risiti',
    },
    'request_timeout': {
      'en': 'Request timed out. Please try again.',
      'sw': 'Ombi limekwisha muda. Tafadhali jaribu tena.',
    },
    'invalid_format': {
      'en': 'Invalid data format received. Please try again.',
      'sw': 'Muundo wa data si sahihi. Tafadhali jaribu tena.',
    },

    // ── General / errors ────────────────────────────────────────────
    'no_connection': {
      'en': 'No connection',
      'sw': 'Hakuna muunganisho',
    },
    'something_wrong': {
      'en': 'Something went wrong',
      'sw': 'Kuna tatizo limetokea',
    },
    'retry': {
      'en': 'Retry',
      'sw': 'Jaribu tena',
    },
    'no_receipts': {
      'en': 'No receipts found.',
      'sw': 'Hakuna risiti zilizopatikana.',
    },
    'scan_to_start': {
      'en': 'Scan a receipt to get started',
      'sw': 'Skani risiti ili kuanza',
    },
    'page_load_error': {
      'en': 'This page cannot be loaded right now\nTry again.',
      'sw': 'Ukurasa huu hauwezi kupakiwa sasa\nJaribu tena.',
    },
    'check_internet': {
      'en': 'Check your internet connection.',
      'sw': 'Angalia muunganisho wako wa intaneti.',
    },

    // ── Navigation ──────────────────────────────────────────────────
    'nav_dashboard': {
      'en': 'Dashboard',
      'sw': 'Dashibodi',
    },
    'nav_receipts': {
      'en': 'Receipts',
      'sw': 'Risiti',
    },
    'nav_scan': {
      'en': 'Scan',
      'sw': 'Skani',
    },
    'nav_profile': {
      'en': 'Profile',
      'sw': 'Wasifu',
    },

    // ── Dashboard ───────────────────────────────────────────────────
    'stat_total_receipts': {
      'en': 'Total Receipts',
      'sw': 'Risiti Zote',
    },
    'stat_total_amount': {
      'en': 'Total Amount',
      'sw': 'Kiasi Chote',
    },
    'stat_today_scans': {
      'en': "Today's Scans",
      'sw': 'Leo',
    },
    'stat_avg_value': {
      'en': 'Avg Value',
      'sw': 'Wastani',
    },
    'stat_total_tax': {
      'en': 'Total Tax',
      'sw': 'Kodi Yote',
    },
    'stat_no_data': {
      'en': 'No data yet',
      'sw': 'Bado hakuna taarifa',
    },
    'dashboard_recent': {
      'en': 'Recent Activity',
      'sw': 'Shughuli za Karibuni',
    },

    // ── Profile ─────────────────────────────────────────────────────
    'profile_title': {
      'en': 'Profile',
      'sw': 'Wasifu',
    },
    'profile_theme': {
      'en': 'Dark Mode',
      'sw': 'Hali ya Giza',
    },
    'profile_language': {
      'en': 'Language',
      'sw': 'Lugha',
    },
    'profile_app_version': {
      'en': 'App Version',
      'sw': 'Toleo la Programu',
    },
    'profile_about': {
      'en': 'About',
      'sw': 'Kuhusu',
    },

    'profile_biometric': {
      'en': 'Biometric Login',
      'sw': 'Ingia kwa Alama',
    },

    // ── Dashboard date range ───────────────────────────────────────────
    'this_month': {
      'en': 'This Month',
      'sw': 'Mwezi Huu',
    },
    'dashboard_date_range': {
      'en': 'Filter by date range',
      'sw': 'Chuja kwa tarehe',
    },
  };

  /// Get a translated string for the current locale.
  static String tr(BuildContext context, String key) {
    final locale = Provider.of<AppState>(context, listen: false).locale;
    return _translations[key]?[locale] ?? _translations[key]?['en'] ?? key;
  }
}
