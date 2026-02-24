// App Constants
const String appName = 'Chatly';
const String appVersion = '1.0.0';

// Colors
const int primaryColorValue = 0xFF6366F1; // Indigo
const int secondaryColorValue = 0xFF8B5CF6; // Purple
const int accentColorValue = 0xFF06B6D4; // Cyan
const int backgroundColorValue = 0xFFFFFFFF; // White
const int surfaceColorValue = 0xFFF8FAFC; // Light Gray
const int errorColorValue = 0xFFEF4444; // Red
const int successColorValue = 0xFF10B981; // Green

// Strings
const String welcomeMessage = 'Welcome to Chatly!';
const String loginPrompt = 'Please log in to continue';
const String signupPrompt = 'Create your account';
const String forgotPasswordPrompt = 'Forgot your password?';
const String chatPlaceholder = 'Type a message...';
const String noChatsMessage = 'No chats yet. Start a conversation!';
const String loadingMessage = 'Loading...';
const String errorMessage = 'Something went wrong. Please try again.';
const String networkErrorMessage =
    'No internet connection. Please check your network.';
const String permissionDeniedMessage =
    'Permission denied. Please grant the required permissions.';

// Firebase Collection Names
const String usersCollection = 'users';
const String chatsCollection = 'chats';
const String messagesCollection = 'messages';
const String groupsCollection = 'groups';

// Database Table Names
const String chatsTableName = 'chats';
const String messagesTableName = 'messages';
const String usersTableName = 'users';

// Other Constants
const int maxMessageLength = 1000;
const int maxGroupMembers = 50;
const Duration messageReadTimeout = Duration(seconds: 30);
const String defaultProfileImageUrl = 'https://via.placeholder.com/150';

// API Keys (if needed, replace with actual keys)
const String firebaseApiKey = 'your_firebase_api_key_here';
const String googleMapsApiKey = 'your_google_maps_api_key_here';

// Notification Channels
const String chatNotificationChannelId = 'chat_notifications';
const String chatNotificationChannelName = 'Chat Notifications';
const String chatNotificationChannelDescription =
    'Notifications for new messages';

// Storage Keys
const String themeModeKey = 'theme_mode';
const String userIdKey = 'user_id';
const String authTokenKey = 'auth_token';
const String settingsKey = 'app_settings';
