const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp();
const db = getFirestore();

// ── Helper: get FCM token for a user ─────────────────────────────────────────
async function getToken(uid) {
  if (!uid) return null;
  const doc = await db.collection("users").doc(uid).get();
  return doc.data()?.fcmToken ?? null;
}

// ── Helper: send FCM push ─────────────────────────────────────────────────────
async function sendPush(token, title, body, data = {}) {
  if (!token) return;
  try {
    await getMessaging().send({
      token,
      notification: { title, body },
      data: { ...data },          // payload for navigation on tap
      android: {
        priority: "high",
        notification: {
          channelId: "arka_high_importance",
          priority: "max",
          defaultSound: true,
        },
      },
      apns: {
        payload: {
          aps: { alert: { title, body }, sound: "default", badge: 1 },
        },
      },
    });
  } catch (e) {
    console.log("FCM send error:", e.message);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRIGGER 1: New order created → notify stockist
// ─────────────────────────────────────────────────────────────────────────────
exports.onNewOrder = onDocumentCreated("orders/{orderId}", async (event) => {
  const order = event.data.data();
  const stockistId = order?.stockistId;
  if (!stockistId) return;

  // stockistId is the stockist doc id — get uid from it
  const stockistDoc = await db.collection("stockists").doc(stockistId).get();
  const stockistUid = stockistDoc.data()?.uid;
  const token = await getToken(stockistUid);

  await sendPush(
    token,
    "📦 New Order Received",
    `Order for Dr. ${order.doctorName ?? "a doctor"} from MR ${order.mrName ?? ""}`,
    { type: "new_order", orderId: event.params.orderId }
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// TRIGGER 2: Order status changed → notify MR
// ─────────────────────────────────────────────────────────────────────────────
exports.onOrderUpdated = onDocumentUpdated("orders/{orderId}", async (event) => {
  const before = event.data.before.data();
  const after  = event.data.after.data();

  if (before.status === after.status) return; // no status change

  const mrUid = after.mrId;
  const token = await getToken(mrUid);

  const messages = {
    approved:   ["✅ Order Approved",    `Your order for Dr. ${after.doctorName} has been approved.`],
    rejected:   ["❌ Order Rejected",    `Your order for Dr. ${after.doctorName} was rejected.${after.rejectionReason ? " Reason: " + after.rejectionReason : ""}`],
    billed:     ["🧾 Order Billed",      `Bill #${after.billNumber} generated for Dr. ${after.doctorName}.`],
    dispatched: ["🚚 Order Dispatched",  `Your order for Dr. ${after.doctorName} has been dispatched.`],
    delivered:  ["✅ Order Delivered",   `Your order for Dr. ${after.doctorName} has been delivered.`],
  };

  const msg = messages[after.status];
  if (!msg) return;

  await sendPush(token, msg[0], msg[1], {
    type: "order_update",
    status: after.status,
    orderId: event.params.orderId,
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// TRIGGER 3: Stock report created → notify all admins
// ─────────────────────────────────────────────────────────────────────────────
exports.onStockReport = onDocumentCreated("stock_reports/{reportId}", async (event) => {
  const report = event.data.data();

  const admins = await db.collection("users")
    .where("role", "==", "admin")
    .get();

  const pushes = admins.docs.map((doc) => {
    const token = doc.data().fcmToken;
    return sendPush(
      token,
      "⚠️ Stock Report Filed",
      `${report.reporterName ?? "Stockist"} reported ${report.items?.length ?? 0} low/out-of-stock items.`,
      { type: "stock_report", reportId: event.params.reportId }
    );
  });

  await Promise.all(pushes);
});

// ─────────────────────────────────────────────────────────────────────────────
// TRIGGER 4: Low stock detected when stockist updates stock
// (watches stockist_stock doc changes)
// ─────────────────────────────────────────────────────────────────────────────
exports.onStockUpdated = onDocumentUpdated("stockist_stock/{uid}", async (event) => {
  const uid    = event.params.uid;
  const before = event.data.before.data();
  const after  = event.data.after.data();
  const token  = await getToken(uid);
  if (!token) return;

  const reminders = after.lowStockReminders ?? {};

  for (const [productId, newQty] of Object.entries(after)) {
    if (productId === "lowStockReminders") continue;
    if (typeof newQty !== "number") continue;

    const oldQty    = typeof before[productId] === "number" ? before[productId] : newQty + 1;
    if (newQty >= oldQty) continue; // stock went up, skip

    const threshold = reminders[productId] ?? 10;

    // fetch product name
    const productDoc = await db.collection("products").doc(productId).get();
    const productName = productDoc.data()?.name ?? "A product";

    if (newQty === 0) {
      await sendPush(token, "🚨 Out of Stock!", `${productName} is now out of stock.`,
        { type: "low_stock", productId });
    } else if (newQty <= threshold) {
      await sendPush(token, "⚠️ Low Stock Alert",
        `${productName} is running low — only ${newQty} units left.`,
        { type: "low_stock", productId });
    }
  }
});