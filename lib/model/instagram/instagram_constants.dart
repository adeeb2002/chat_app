class InstagramConstants {
  InstagramConstants._();

  static const String clientId = 'YOUR_APP_ID';
  static const String clientSecret = 'YOUR_APP_SECRET';

  // ✅ هذا الرابط بنعترضه داخل WebView - ما لازم يكون حقيقي
  // لكن لازم تضيفه في Meta Console كـ Valid OAuth Redirect URI
  static const String redirectUri =
      'https://localhost/instagram/callback';

  static const String authBaseUrl =
      'https://api.instagram.com/oauth/authorize';
  static const String tokenUrl =
      'https://api.instagram.com/oauth/access_token';
  static const String longLivedTokenUrl =
      'https://graph.instagram.com/access_token';
  static const String graphBaseUrl = 'https://graph.instagram.com';

  static const List<String> scopes = [
    'instagram_basic',
    'instagram_content_publish',
  ];

  static const String accessTokenKey = 'ig_access_token';
  static const String userIdKey = 'ig_user_id';
  static const String tokenExpiryKey = 'ig_token_expiry';

  // حقول أساسية تشتغل مع Basic Display API
  static const String userFields =
      'id,username,account_type,media_count';

  // حقول إضافية تحتاج Business Account
  static const String fullUserFields =
      'id,username,name,biography,followers_count,'
      'follows_count,media_count,profile_picture_url,'
      'website,account_type';

  static const String mediaFields =
      'id,caption,media_type,media_url,thumbnail_url,'
      'permalink,timestamp,like_count,comments_count';

  static const String storyFields =
      'id,media_type,media_url,thumbnail_url,timestamp';
}