class InstagramConstants {
  // ⚠️ احصل عليهم من Meta Developer Console
  static const String clientId = 'YOUR_INSTAGRAM_APP_ID';
  static const String clientSecret = 'YOUR_INSTAGRAM_APP_SECRET';
  static const String redirectUri = 'myapp://instagram-callback';

  // OAuth Endpoints
  static const String authBaseUrl = 'https://api.instagram.com/oauth/authorize';
  static const String tokenUrl = 'https://api.instagram.com/oauth/access_token';
  static const String longLivedTokenUrl = 'https://graph.instagram.com/access_token';

  // Graph API
  static const String graphBaseUrl = 'https://graph.instagram.com';

  // Scopes المطلوبة
  static const List<String> scopes = [
    'instagram_basic',
    'instagram_content_publish',
    'instagram_manage_insights',
    'pages_show_list',
    'pages_read_engagement',
  ];

  // Storage Keys
  static const String accessTokenKey = 'instagram_access_token';
  static const String userIdKey = 'instagram_user_id';
  static const String tokenExpiryKey = 'instagram_token_expiry';

  // الحقول المطلوبة من API
  static const String userFields =
      'id,username,name,biography,followers_count,'
      'follows_count,media_count,profile_picture_url,website';

  static const String mediaFields =
      'id,caption,media_type,media_url,thumbnail_url,'
      'permalink,timestamp,like_count,comments_count';
}