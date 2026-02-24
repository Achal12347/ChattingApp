const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// Trigger when a new message is created in Firestore
exports.sendMessageNotification = functions.firestore
    .document("chats/{chatId}/messages/{messageId}")
    .onCreate(async (snap, context) => {
      const messageData = snap.data();
      const receiverId = messageData.receiverId;

      // Get receiver's FCM token
      const userDoc = await admin.firestore()
          .collection("users")
          .doc(receiverId)
          .get();
      const token = userDoc.data().fcmToken;

      if (token) {
        // Fetch sender's username
        const senderDoc = await admin.firestore()
            .collection("users")
            .doc(messageData.senderId)
            .get();
        const senderName = senderDoc.data().username || "Unknown User";

        const payload = {
          notification: {
            title: `New message from ${senderName}`,
            body: messageData.text || "📩 New message",
          },
          data: {
            chatId: context.params.chatId,
            senderId: messageData.senderId,
          },
          token: token,
        };

        try {
          await admin.messaging().send(payload);
          console.log("Notification sent successfully");
        } catch (err) {
          console.error("Error sending notification:", err);
        }
      } else {
        console.log("No token for user:", receiverId);
      }
    });

// Trigger when a new unblock request is created
exports.sendUnblockRequestNotification = functions.firestore
    .document("unblockRequests/{requestId}")
    .onCreate(async (snap, context) => {
      const requestData = snap.data();
      const toUserId = requestData.toUserId;

      // Get receiver's FCM token
      const userDoc = await admin.firestore()
          .collection("users")
          .doc(toUserId)
          .get();
      const token = userDoc.data().fcmToken;

      if (token) {
        const fromUserDoc = await admin.firestore()
            .collection("users")
            .doc(requestData.fromUserId)
            .get();
        const fromUserName = fromUserDoc.data().username;

        const payload = {
          notification: {
            title: "Unblock Request",
            body: `You have received an unblock request from ${fromUserName}`,
          },
          data: {
            requestId: context.params.requestId,
          },
          token: token,
        };

        try {
          await admin.messaging().send(payload);
          console.log("Unblock request notification sent successfully");
        } catch (err) {
          console.error("Error sending notification:", err);
        }
      } else {
        console.log("No token for user:", toUserId);
      }
    });
