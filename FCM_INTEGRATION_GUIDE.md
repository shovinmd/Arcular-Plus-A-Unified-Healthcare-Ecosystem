# 🔥 FCM Integration Guide for Arcular+

## 📋 Overview

This guide documents the complete Firebase Cloud Messaging (FCM) integration for Arcular+ app, specifically for menstrual cycle reminders that work even when the app is closed.

## ✨ Features Implemented

### ✅ **Backend (Node.js)**
- **FCM Token Storage**: User model updated with FCM token and notification preferences
- **FCM Service**: Complete service for sending notifications to users
- **Menstrual Reminder Service**: Calculates and schedules reminders based on cycle data
- **Cron Service**: Daily automated reminder processing at 9:00 AM IST
- **FCM Routes**: RESTful API endpoints for token management and testing

### ✅ **Frontend (Flutter)**
- **FCM Service**: Handles token registration, notification preferences, and backend communication
- **Menstrual Cycle Screen**: Updated to integrate with FCM for real-time reminders
- **Upcoming Reminders**: Displays next 30 days of predicted reminders

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Flutter App  │    │   Node.js Backend│    │   Firebase FCM  │
│                 │    │                  │    │                 │
│ • FCM Service  │◄──►│ • FCM Service    │◄──►│ • Push Notif.   │
│ • Token Mgmt   │    │ • Cron Jobs      │    │ • Token Mgmt    │
│ • Preferences  │    │ • Reminder Calc  │    │ • Topic Mgmt    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 📱 How It Works

### 1. **Token Registration**
- User opens app → FCM token generated
- Token sent to backend with notification preferences
- Stored in MongoDB User collection

### 2. **Daily Processing**
- Cron job runs at 9:00 AM IST daily
- Checks all users with enabled reminders
- Calculates next period, ovulation, fertile window dates
- Sends FCM notifications if today matches any reminder date

### 3. **Real-time Notifications**
- Notifications work even when app is closed
- Users receive push notifications on their devices
- Tapping notification opens app to relevant screen

## 🚀 Installation & Setup

### **Backend Dependencies**
```bash
cd node_backend
npm install node-cron@^3.0.3
```

### **Environment Variables**
Ensure these are set in your `.env` file:
```env
# Firebase Admin SDK
GOOGLE_APPLICATION_CREDENTIALS=path/to/serviceAccountKey.json
FIREBASE_PROJECT_ID=your-project-id

# MongoDB
MONGODB_URI=your-mongodb-connection-string

# Timezone (for cron jobs)
TZ=Asia/Kolkata
```

## 📊 API Endpoints

### **FCM Token Management**
```
POST /api/fcm/register-token
- Registers/updates user's FCM token
- Updates notification preferences

DELETE /api/fcm/remove-token
- Removes user's FCM token

GET /api/fcm/upcoming-reminders
- Gets next 30 days of reminders for user
```

### **Testing & Admin**
```
POST /api/fcm/test-notification
- Sends test notification to current user

POST /api/fcm/trigger-reminders
- Manually triggers reminder processing (admin/staff only)

GET /api/fcm/cron-status
- Gets cron service status (admin/staff only)

POST /api/fcm/restart-cron
- Restarts cron service (admin only)
```

## 🔧 Configuration

### **Cron Job Schedule**
- **Daily Reminders**: 9:00 AM IST (`0 9 * * *`)
- **Health Check**: Every hour (`0 * * * *`)
- **Cleanup**: 2:00 AM IST (`0 2 * * *`)

### **Notification Channels**
- **Android**: `menstrual-reminders` channel with high priority
- **iOS**: Standard notification settings with sound and badge

## 🧪 Testing

### **Run Test Script**
```bash
cd node_backend
node test-fcm.js
```

### **Test Individual Components**
```javascript
// Test FCM service
const fcmService = require('./services/fcmService');
await fcmService.sendToUser(userId, notification);

// Test reminder calculations
const menstrualService = require('./services/menstrualReminderService');
const nextPeriod = menstrualService.calculateNextPeriod(lastDate, cycleLength);

// Test cron service
const cronService = require('./services/cronService');
await cronService.triggerMenstrualReminders();
```

## 📱 Flutter Integration

### **Initialize FCM Service**
```dart
final fcmService = FCMService();
await fcmService.initialize();
```

### **Update Notification Preferences**
```dart
await fcmService.updateMenstrualReminderPreferences(
  menstrualReminders: true,
  reminderTime: '09:00',
  timezone: 'Asia/Kolkata',
);
```

### **Get Upcoming Reminders**
```dart
final reminders = await fcmService.getUpcomingReminders();
```

## 🔍 Monitoring & Debugging

### **Backend Logs**
- FCM token registration/updates
- Daily reminder processing results
- Cron job execution status
- Error logs with stack traces

### **Frontend Logs**
- FCM service initialization
- Token registration with backend
- Notification preference updates
- API call results

### **Health Check Endpoint**
```
GET /api/fcm/cron-status
```
Returns:
```json
{
  "success": true,
  "data": {
    "initialized": true,
    "activeJobs": 3,
    "jobs": {
      "menstrualReminders": {
        "running": true,
        "lastRun": "2024-01-28T09:00:00.000Z",
        "nextRun": "2024-01-29T09:00:00.000Z"
      }
    }
  }
}
```

## 🚨 Troubleshooting

### **Common Issues**

#### 1. **FCM Notifications Not Working**
- Check Firebase Admin SDK configuration
- Verify FCM token is stored in database
- Check user notification preferences are enabled
- Review backend logs for FCM errors

#### 2. **Cron Jobs Not Running**
- Verify timezone settings
- Check cron service initialization
- Review server startup logs
- Test manual trigger endpoint

#### 3. **Token Registration Fails**
- Check authentication middleware
- Verify user exists in database
- Check FCM token format
- Review API endpoint logs

### **Debug Commands**
```bash
# Check cron service status
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://your-backend.com/api/fcm/cron-status

# Manually trigger reminders
curl -X POST -H "Authorization: Bearer YOUR_TOKEN" \
  https://your-backend.com/api/fcm/trigger-reminders

# Send test notification
curl -X POST -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","body":"Test notification"}' \
  https://your-backend.com/api/fcm/test-notification
```

## 📈 Performance Considerations

### **Optimizations**
- **Batch Processing**: Process users in batches to avoid overwhelming FCM
- **Rate Limiting**: 100ms delay between FCM calls
- **Token Validation**: Only process users with valid FCM tokens
- **Error Handling**: Graceful degradation for failed notifications

### **Scalability**
- **Horizontal Scaling**: Multiple server instances can run cron jobs
- **Database Indexing**: FCM token and notification preference indexes
- **Caching**: Cache user preferences and cycle data
- **Queue System**: Future implementation with Redis/Message queues

## 🔮 Future Enhancements

### **Planned Features**
- **Smart Scheduling**: Adjust reminder times based on user activity
- **Custom Notifications**: Personalized message content
- **Analytics Dashboard**: Notification delivery statistics
- **A/B Testing**: Different notification strategies
- **Multi-language**: Localized notification content

### **Advanced Reminders**
- **Symptom Tracking**: Remind users to log symptoms
- **Medication Reminders**: Birth control pill reminders
- **Doctor Appointments**: Follow-up appointment reminders
- **Health Tips**: Daily wellness notifications

## 📚 Resources

### **Documentation**
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Node-cron Documentation](https://github.com/node-cron/node-cron)
- [Flutter Local Notifications](https://pub.dev/packages/flutter_local_notifications)

### **Code Examples**
- `node_backend/services/fcmService.js` - Complete FCM service
- `node_backend/services/menstrualReminderService.js` - Reminder calculations
- `node_backend/services/cronService.js` - Automated scheduling
- `lib/services/fcm_service.dart` - Flutter FCM integration

## ✅ Success Metrics

### **Key Performance Indicators**
- **Token Registration Rate**: >95% of active users
- **Notification Delivery Rate**: >90% successful deliveries
- **User Engagement**: Increased app opens from notifications
- **Reminder Accuracy**: Correct prediction dates

### **Monitoring Dashboard**
- Daily reminder processing statistics
- FCM delivery success rates
- User notification preference trends
- System health and performance metrics

---

## 🎉 Conclusion

The FCM integration provides a robust, scalable solution for menstrual cycle reminders that work reliably even when the app is closed. The system automatically processes reminders daily, ensuring users never miss important cycle information.

**Next Steps:**
1. Install `node-cron` dependency
2. Test the integration with real users
3. Monitor performance and delivery rates
4. Gather user feedback and iterate
5. Implement additional reminder types

For support or questions, refer to the backend logs and test endpoints provided in this guide.
