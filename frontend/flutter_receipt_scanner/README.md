# Lemuru Receipt Scanner App

A Flutter application for scanning and managing Tanzania Revenue Authority (TRA) receipts.

## Features

- Scan QR codes on receipts to verify and store them
- View a list of scanned receipts with pagination (load more functionality)
- Search and filter receipts by date range
- Login functionality with token authentication
- Configurable API endpoints for different environments

## Getting Started

### Prerequisites

- Flutter SDK 3.0.0 or higher
- Dart SDK 3.0.0 or higher
- Android Studio or VS Code with Flutter extensions

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd flutter_receipt_scanner
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the application:
   ```bash
   flutter run
   ```

### Configuration

The app supports different API endpoints based on the environment:

- Edit the `ApiConfig` class in `lib/main.dart` to configure:
  - Set `useLocalServer` to `true` for local development or `false` for production
  - Update `productionBaseUrl` and `localBaseUrl` as needed
  - For Android emulator, use `10.0.2.2` instead of `localhost` for local development

### Login

For demo purposes, you can use these credentials:
- Email: demo@example.com
- Password: password

## Project Structure

- `lib/main.dart` - Main application code including receipt listing and scanning
- `lib/login_page.dart` - Login page implementation
- `lib/utils/api_request_status.dart` - Enum for API request states

## Common Issues

1. **Missing Assets**: Ensure the assets directory contains the correct files:
   - Check that `assets/icon/lemurulogo.png` exists
   - Verify that the fonts in `assets/fonts/` are available

2. **Dependencies**: If you get package dependency errors, try:
   ```bash
   flutter clean
   flutter pub get
   ```

3. **API Connection**: If unable to connect to the API:
   - Check internet connection
   - Verify API configuration in `ApiConfig` class
   - For local development, ensure backend server is running
   - Check if the token is being correctly sent in API requests
   
4. **Performance Issues**: If experiencing lag or skipped frames:
   - Use profile mode for performance testing: `flutter run --profile`
   - Reduce unnecessary widget rebuilds
   - Follow Flutter performance best practices

## Contributing

Contributions are welcome! Please create a pull request or open an issue to propose changes or report bugs.

## License

This project is licensed under the MIT License - see the LICENSE file for details.