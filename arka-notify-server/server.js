const admin = require("firebase-admin");
const express = require("express");

const app = express();

// Paste your Firebase service account JSON here
const serviceAccount = require("./serviceAccount.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const messaging = admin.messaging();

async function sendPush(token, title, body, data = {}) {
  if (!token) return;
  try {
    await messaging.send({
      token,
      notification: { title, body },
      data,
      android: {
        priority: "high",
        notification: {
          channelId: "arka_high_importance",
          priority: "max",
          defaultSound: true,
        },
      },
    });
    console.log("Push sent:", title);
  } catch (e) {
    console.log("Push error:", e.message);
  }
}

async function getToken(uid) {
  if (!uid) return null;
  const doc = await db.collection("users").doc(uid).get();
  return doc.data()?.fcmToken ?? null;
}

// ── Watch new orders → notify stockist ───────────────────────────────────────
db.collection("orders").onSnapshot((snapshot) => {
  snapshot.docChanges().forEach(async (change) => {
    if (change.type !== "added") return;
    const order = change.doc.data();
    const stockistId = order.stockistId;
    if (!stockistId) return;

    const stockistDoc = await db.collection("stockists").doc(stockistId).get();
    const stockistUid = stockistDoc.data()?.uid;
    const token = await getToken(stockistUid);

    await sendPush(
      token,
      "📦 New Order Received",
      `Order for Dr. ${order.doctorName ?? "a doctor"} from MR ${order.mrName ?? ""}`,
      { type: "new_order", orderId: change.doc.id }
    );
  });
});

// ── Watch order updates → notify MR ──────────────────────────────────────────
db.collection("orders").onSnapshot((snapshot) => {
  snapshot.docChanges().forEach(async (change) => {
    if (change.type !== "modified") return;
    const order = change.doc.data();
    const mrUid = order.mrId;
    const token = await getToken(mrUid);

    const messages = {
      approved:   ["✅ Order Approved",   `Your order for Dr. ${order.doctorName} has been approved.`],
      rejected:   ["❌ Order Rejected",   `Your order for Dr. ${order.doctorName} was rejected.`],
      billed:     ["🧾 Order Billed",     `Bill #${order.billNumber} generated.`],
      dispatched: ["🚚 Order Dispatched", `Your order for Dr. ${order.doctorName} has been dispatched.`],
      delivered:  ["✅ Order Delivered",  `Your order for Dr. ${order.doctorName} has been delivered.`],
    };

    const msg = messages[order.status];
    if (!msg) return;

    await sendPush(token, msg[0], msg[1], {
      type: "order_update",
      status: order.status,
      orderId: change.doc.id,
    });
  });
});

// ── Watch stock reports → notify admins ──────────────────────────────────────
db.collection("stock_reports").onSnapshot((snapshot) => {
  snapshot.docChanges().forEach(async (change) => {
    if (change.type !== "added") return;
    const report = change.doc.data();

    const admins = await db.collection("users").where("role", "==", "admin").get();
    admins.docs.forEach(async (doc) => {
      const token = doc.data().fcmToken;
      await sendPush(
        token,
        "⚠️ Stock Report Filed",
        `${report.reporterName ?? "Stockist"} reported ${report.items?.length ?? 0} low/out-of-stock items.`,
        { type: "stock_report", reportId: change.doc.id }
      );
    });
  });
});

// Keep server alive
app.get("/", (req, res) => res.send("Arka notification server running"));
app.listen(3000, () => console.log("Server started on port 3000"));