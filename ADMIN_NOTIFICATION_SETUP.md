# Admin Push Notification Setup Guide

## Overview
This implementation adds push notifications for admins when new complaints are submitted by users. The system uses Firebase Cloud Messaging (FCM) to send notifications to admin devices.

## Components Added

### 1. Notification Service Updates
- **File**: `lib/service/notification_service.dart`
- **Changes**: Added methods to:
  - Save admin FCM tokens to Firebase database
  - Retrieve all admin tokens
  - Send push notifications to admins
  - Notify admins of new complaints

### 2. Complaint Form Updates
- **File**: `lib/components/shared_issue_form.dart`
- **Changes**: Added admin notification trigger after successful complaint submission

### 3. Admin Dashboard Updates
- **File**: `lib/screen/admin_dashboard.dart`
- **Changes**: Added automatic FCM token registration for logged-in admins

## Setup Instructions

### 1. Firebase Configuration
- Ensure Firebase project is properly configured
- Enable Firebase Cloud Messaging in Firebase Console
- Add FCM server key to the notification service

### 2. Database Structure
The system expects the following Firebase Realtime Database structure:
```
admins/
  {adminId}/
    fcmToken: "admin_device_token"
    name: "Admin Name"
    email: "admin@example.com"
```

### 3. FCM Server Key Configuration
The system now uses environment variables for the FCM server key. Update your `.env` file:

```
FCM_SERVER_KEY=your_actual_fcm_server_key_here
```

**Setup Steps:**
1. Copy `.env.example` to `.env`
2. Add your actual FCM server key from Firebase Console
3. Ensure `.env` is added to `.gitignore` to prevent committing sensitive data

**Important**: Store the FCM server key securely using environment variables or a secrets management system.

## Testing Instructions

### 1. Admin Setup
1. Log in as an admin (email containing "gov")
2. Navigate to admin dashboard
3. Verify FCM token is saved in Firebase under `admins/{adminId}/fcmToken`

### 2. Complaint Submission Test
1. Log in as a regular user
2. Submit a new complaint
3. Verify admin receives push notification with complaint details

### 3. Notification Content
Admin notifications include:
- Issue type (Water, Electricity, etc.)
- Location (City, State)
- User name
- Complaint ID for reference

## Security Considerations

### Firebase Rules
Add appropriate security rules for admin tokens:
```javascript
{
  "rules": {
    "admins": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    }
  }
}
```

### Environment Variables
The system now automatically reads from environment variables using `flutter_dotenv`:
1. **Development**: Use `.env` file with your FCM server key
2. **Production**: Configure environment variables in your deployment platform
3. **Security**: Never commit actual `.env` file with real keys

**Required Environment Variable:**
- `FCM_SERVER_KEY`: Your Firebase Cloud Messaging server key

## Troubleshooting

### Common Issues
1. **No notifications received**: Check if admin FCM token is saved in database
2. **Authentication errors**: Verify Firebase rules and authentication
3. **FCM server errors**: Check FCM server key validity

### Debug Steps
1. Check Firebase console for FCM delivery reports
2. Verify admin device token registration
3. Test with Firebase console notification composer
4. Check application logs for error messages

## Future Enhancements
- Add notification preferences for admins
- Implement notification batching for multiple complaints
- Add notification history tracking
- Support for multiple admin roles
- Implement notification analytics
