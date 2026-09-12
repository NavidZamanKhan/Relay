const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Cloud Function triggered on new message creation in Cloud Firestore.
 * Dispatches high-priority push notifications to the recipient's registered device.
 */
exports.onNewMessage = onDocumentCreated(
  {
    document: "chats/{chatId}/messages/{messageId}",
    region: "us-central1",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const messageData = snapshot.data();
    const chatId = event.params.chatId;
    const messageId = event.params.messageId;
    const senderId = messageData.senderId;
    const senderName = messageData.senderName || "Relay Contact";

    const db = admin.firestore();
    const messaging = admin.messaging();

    try {
      // 1. Resolve recipients
      let recipientIds = [];
      if (messageData.recipientId) {
        recipientIds = [messageData.recipientId];
      } else {
        const chatDoc = await db.collection("chats").doc(chatId).get();
        if (chatDoc.exists) {
          const participants = chatDoc.data().participantIds || [];
          recipientIds = participants.filter((uid) => uid !== senderId);
        }
      }

      if (recipientIds.length === 0) return;

      // 2. Format body preview based on message kind
      let bodyPreview = "New message";
      if (messageData.kind === "voice") {
        bodyPreview = "Voice message";
      } else if (messageData.kind === "image") {
        bodyPreview = "Photo attachment";
      } else if (messageData.text && messageData.text.trim().length > 0) {
        bodyPreview = messageData.text.trim();
      }

      // 3. Retrieve parent chat doc to read recipient unread count for badge
      let unreadMap = {};
      try {
        const chatDoc = await db.collection("chats").doc(chatId).get();
        if (chatDoc.exists) {
          unreadMap = chatDoc.data().unreadCount || {};
        }
      } catch (_) {}

      // 4. Dispatch notification to each recipient with a valid FCM token
      for (const recipientId of recipientIds) {
        if (!recipientId || recipientId === senderId) continue;

        const userDoc = await db.collection("users").doc(recipientId).get();
        if (!userDoc.exists) continue;

        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;
        if (!fcmToken || typeof fcmToken !== "string" || fcmToken.length === 0) {
          continue;
        }

        const badgeCount =
          typeof unreadMap[recipientId] === "number"
            ? unreadMap[recipientId]
            : 1;

        const payload = {
          token: fcmToken,
          notification: {
            title: senderName,
            body: bodyPreview,
          },
          data: {
            chatId: chatId,
            senderId: senderId,
            messageId: messageId,
            title: senderName,
            body: bodyPreview,
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: badgeCount,
                alert: {
                  title: senderName,
                  body: bodyPreview,
                },
              },
            },
          },
          android: {
            priority: "high",
            notification: {
              sound: "default",
              channelId: "relay_messages",
              priority: "max",
            },
          },
        };

        try {
          await messaging.send(payload);
        } catch (sendError) {
          // If token has expired or is unregistered, clean it up from Firestore
          if (
            sendError.code === "messaging/registration-token-not-registered" ||
            sendError.code === "messaging/invalid-registration-token"
          ) {
            await db.collection("users").doc(recipientId).update({
              fcmToken: admin.firestore.FieldValue.delete(),
            });
          }
        }
      }
    } catch (err) {
      console.error("Error processing message push notification:", err);
    }
  }
);
