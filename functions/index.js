const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const { rax } = require('retry-axios');

admin.initializeApp();

exports.sendStatusUpdateNotification = functions.database
  .ref('/complaints/{complaintId}')
  .onUpdate(async (change, context) => {
    const before = change.before.val();
    const after = change.after.val();
    
    // Check if status has changed
    if (before.status === after.status) {
      console.log('Status unchanged, no notification needed');
      return null;
    }

    try {
      // Get user details
      const userId = after.user_id;
      if (!userId) {
        console.error('No user_id found in complaint data');
        return null;
      }

      const userSnapshot = await admin.database().ref(`/users/${userId}`).once('value');
      const userData = userSnapshot.val();
      
      if (!userData) {
        console.error('User data not found for ID:', userId);
        return null;
      }

      // Check for FCM token
      const fcmToken = userData.fcmToken;
      if (!fcmToken) {
        console.warn('No FCM token found for user:', userId);
        return null;
      }

      const issueTitle = after.issue_type || 'Your complaint';
      const newStatus = after.status;
      const adminNote = after.admin_note || '';
      
      // Create notification payload
      const payload = {
        notification: {
          title: `Status Update: ${issueTitle}`,
          body: adminNote 
            ? `Your issue has been marked as ${newStatus}. ${adminNote}`
            : `Your issue has been marked as ${newStatus}.`,
          icon: '@mipmap/ic_launcher',
          sound: 'default',
        },
        data: {
          complaintId: context.params.complaintId,
          newStatus: newStatus,
          issueTitle: issueTitle,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
      };

      // Send notification with retry logic
      let response;
      try {
        response = await admin.messaging().sendToDevice(fcmToken, payload);
        console.log('Successfully sent notification:', response);
        
        // Count successful and failed message sends
        const successCount = response.successCount || 0;
        const failureCount = response.failureCount || 0;
        
        if (failureCount > 0 && response.results && response.results.length > 0) {
          console.warn('Some notification sends failed:', response.results);
        }
      } catch (sendError) {
        console.error('Error sending notification:', sendError);
        // Allow function to continue to store notification history even if send fails
      }
      
      // Log the notification in user's notification history (even if send fails)
      try {
        const notificationRef = admin.database().ref(`/users/${userId}/notifications`).push();
        await notificationRef.set({
          title: payload.notification.title,
          body: payload.notification.body,
          timestamp: admin.database.ServerValue.TIMESTAMP,
          complaintId: context.params.complaintId,
          status: newStatus,
          read: false,
        });
        console.log('Notification saved to history');
      } catch (historyError) {
        console.error('Failed to save notification to history:', historyError);
      }

      return response || null;
    } catch (error) {
      console.error('Error in sendStatusUpdateNotification function:', error);
      return null;
    }
  });

// Function to handle admin notes with notifications
exports.sendAdminNoteNotification = functions.database
  .ref('/complaints/{complaintId}/admin_note')
  .onUpdate(async (change, context) => {
    const newNote = change.after.val();
    const beforeNote = change.before.val();
    
    if (!newNote || newNote === beforeNote) {
      console.log('Admin note unchanged or empty, no notification needed');
      return null;
    }

    try {
      const complaintSnapshot = await admin.database().ref(`/complaints/${context.params.complaintId}`).once('value');
      const complaint = complaintSnapshot.val();
      
      if (!complaint) {
        console.error('Complaint data not found for ID:', context.params.complaintId);
        return null;
      }
      
      if (!complaint.user_id) {
        console.error('No user_id found in complaint data');
        return null;
      }

      const userId = complaint.user_id;
      const userSnapshot = await admin.database().ref(`/users/${userId}`).once('value');
      const userData = userSnapshot.val();
      
      if (!userData) {
        console.error('User data not found for ID:', userId);
        return null;
      }
      
      // Check for FCM token
      if (!userData.fcmToken) {
        console.warn('No FCM token found for user:', userId);
        return null;
      }

      const payload = {
        notification: {
          title: `Update on: ${complaint.issue_type || 'Your complaint'}`,
          body: newNote,
          icon: '@mipmap/ic_launcher',
          sound: 'default',
        },
        data: {
          complaintId: context.params.complaintId,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
      };

      // Send notification with error handling
      let response;
      try {
        response = await admin.messaging().sendToDevice(userData.fcmToken, payload);
        console.log('Successfully sent admin note notification:', response);
        
        // Count successful and failed message sends
        const successCount = response.successCount || 0;
        const failureCount = response.failureCount || 0;
        
        if (failureCount > 0 && response.results && response.results.length > 0) {
          console.warn('Some admin note notification sends failed:', response.results);
        }
      } catch (sendError) {
        console.error('Error sending admin note notification:', sendError);
        // Allow function to continue to store notification history even if send fails
      }
      
      // Log the notification in history even if send fails
      try {
        const notificationRef = admin.database().ref(`/users/${userId}/notifications`).push();
        await notificationRef.set({
          title: payload.notification.title,
          body: payload.notification.body,
          timestamp: admin.database.ServerValue.TIMESTAMP,
          complaintId: context.params.complaintId,
          read: false,
        });
        console.log('Admin note notification saved to history');
      } catch (historyError) {
        console.error('Failed to save admin note notification to history:', historyError);
      }

      return response || null;
    } catch (error) {
      console.error('Error in sendAdminNoteNotification function:', error);
      return null;
    }
  });

// Function to handle FCM token refreshes
exports.handleTokenRefresh = functions.database
  .ref('/users/{userId}/fcmToken')
  .onWrite(async (change, context) => {
    const newToken = change.after.val();
    const userId = context.params.userId;
    
    // If token is being deleted, skip
    if (!newToken) {
      console.log('FCM token removed for user:', userId);
      return null;
    }
    
    try {
      console.log(`FCM token ${change.before.exists() ? 'updated' : 'created'} for user: ${userId}`);
      
      // You could add additional logic here if needed, such as:
      // - Update user's subscription topics
      // - Send a welcome notification to the new token
      // - Log device information
      
      return null;
    } catch (error) {
      console.error('Error in handleTokenRefresh function:', error);
      return null;
    }
  });

// Function to send notification to all admins when a new complaint is created
exports.sendNewComplaintNotificationToAdmins = functions.database
  .ref('/complaints/{complaintId}')
  .onCreate(async (snapshot, context) => {
    const complaint = snapshot.val();
    const complaintId = context.params.complaintId;

    try {
      // 1. Get all admin users
      // Optimized: query only admin users instead of loading the full /users tree
      const adminTokens = [];
      const adminsSnapshot = await admin.database()
        .ref('/users')
        .orderByChild('isAdmin')
        .equalTo(true)
        .once('value');

      if (adminsSnapshot.exists()) {
        adminsSnapshot.forEach(childSnap => {
          const data = childSnap.val();
          if (data && data.fcmToken) {
            adminTokens.push(data.fcmToken);
          }
        });
      }

      if (adminTokens.length === 0) {
        console.log('No admin users with FCM tokens found. No notification sent.');
        return null;
      }

      // 2. Construct the notification message using FCM HTTP v1 API format
      const issueTypeText = complaint && complaint.issue_type ? `: ${complaint.issue_type}` : '';
      const message = {
        notification: {
          title: 'New Complaint Registered',
          body: `A new complaint has been registered${issueTypeText}`,
        },
        data: {
          complaintId: complaintId,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
      };

      // 3. Get OAuth2 access token
      const accessToken = await admin.credential.applicationDefault().getAccessToken();

      // 4. Send notification to each admin with timeout and retry
      const sendPromises = adminTokens.map(token => {
        const fcmMessage = { ...message, token };

        const axiosInstance = axios.create({
          headers: {
            'Authorization': `Bearer ${accessToken.access_token}`,
            'Content-Type': 'application/json',
          },
          // Add timeout to the request
          timeout: 10000, // 10 seconds timeout
        });

        // Attach retry-axios interceptor with custom retry configuration
        rax.attach(axiosInstance);
        axiosInstance.defaults.raxConfig = {
          retry: 3,
          noResponseRetries: 2,
          retryDelay: 1000, // initial retry delay in ms
          backoffType: 'exponential',
          onRetryAttempt: err => {
            const cfg = rax.getConfig(err);
            console.log(`Retry attempt #${cfg.currentRetryAttempt} for admin notification`);
          }
        };

        return axiosInstance.post(
          `https://fcm.googleapis.com/v1/projects/${process.env.GCLOUD_PROJECT}/messages:send`,
          { message: fcmMessage }
        );
      });

      const responses = await Promise.allSettled(sendPromises);

      responses.forEach((result, index) => {
        if (result.status === 'fulfilled') {
          console.log(`Successfully sent notification to admin at index ${index}.`);
        } else {
          console.error(`Failed to send notification to admin at index ${index}.`, result.reason);
        }
      });

      return null;
    } catch (error) {
      console.error('Error in sendNewComplaintNotificationToAdmins function:', error);
      return null;
    }
  });
