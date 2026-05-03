# Arkphora — User Guide

A complete walkthrough of the Arkphora mobile app for every kind of user.
Read this once and you'll know exactly what the app does and how to use it.

---

## 1. What is Arkphora?

Arkphora is a field-operations app for a pharmaceutical company. It connects three groups of people:

| Role | Who they are | What they do in the app |
|---|---|---|
| **Admin** | Office / head-office staff | Manage everything: users, doctors, orders, stock, approvals, reports |
| **MR** (Medical Representative) | Field reps who visit doctors | Visit doctors, place orders, submit daily reports, apply for leave |
| **Stockist** | Distributors / wholesalers | Receive and fulfil orders, report low stock |

All three roles use the **same app** — the screens you see are decided automatically based on your account.

---

## 2. Getting Started

### Installing
- Install the app on your Android (or iOS) phone.
- The app appears as **Arkphora** on your home screen.

### Logging in
1. Open Arkphora. You'll see the welcome screen with the Arkphora logo.
2. Enter your **email** and **password** (provided by your administrator).
3. Tap **Sign in**.
4. The app figures out your role automatically and takes you to the right home screen.

> **Stay signed in:** Once you log in, the app remembers you. You won't need to log in again unless you sign out or your account is deactivated.

### If login fails
- *Wrong email or password* → check spelling and try again.
- *Too many failed attempts* → wait a few minutes before retrying.
- *Account deactivated* → an admin has disabled your access. Contact them.

### Permissions the app will ask for
- **Location** — required for MRs (proves you visited the doctor).
- **Notifications** — so you get order updates, approvals, and alerts in real time.
- **Camera** — for capturing doctor / clinic photos when needed.

Please **allow** all of these. The app will not work properly without them.

---

## 3. For MRs (Medical Representatives)

Your job is to visit doctors in your area, place orders on their behalf, and submit a daily report. The app is built around that workflow.

> **Note for MRs:** Screenshots and screen recording are blocked on your screens for data protection. This is intentional.

### Bottom navigation (6 tabs)

#### 🏠 Dashboard
- Greets you ("Good Morning / Afternoon / Evening").
- **Today's Summary** — doctors visited, orders placed, whether your daily report is submitted.
- **This Month** — present / absent / leave / working days.
- **Total Incentives** — your cumulative allowances.
- A red banner reminds you if you haven't submitted today's report.
- 8 quick-action shortcuts: Visit Doctor, Place Order, Daily Report, Apply Leave, Add Doctor, New Conversion, Conversions History, RCPA.

#### 👨‍⚕️ Doctors
- The list of doctors assigned to you (search by name or hospital).
- Each doctor card shows tier (Normal / Core / Super Core / Premium) and division.
- **To check in to a doctor visit:**
  1. Tap the doctor's card.
  2. Allow GPS if prompted.
  3. The app captures your live location and verifies you're physically near the doctor's clinic (**geofence check**).
  4. Visit is recorded with timestamp.
- You can also **Add a new doctor** (captures their clinic location) or **Edit doctor info**.

> ⚠ **Don't use fake-GPS apps.** Arkphora detects mock locations and will block your check-in with a "Fake GPS detected" warning.

#### 💊 Products
- Browse the full product catalogue.
- See category, manufacturer, price, and stock quantity.
- Search or filter by category.

#### 📦 Orders
- See all orders you've placed; search by doctor or order ID.
- **To place a new order:**
  1. Tap **Place Order**.
  2. Select the doctor.
  3. Add products and quantities.
  4. Submit. Order goes to **pending** status, awaiting admin approval.
- You'll get a real-time notification each time the status changes:
  Pending → ✅ Approved → 🧾 Billed → 🚚 Dispatched → ✅ Delivered.

#### 📝 Reports
- View all your past daily reports.
- **Submit today's report** — write a short summary of your day's field activity. Only one report per day.

#### 👤 Profile
- Your name, email, mobile, division, and location.
- **Allowances** — see your salary, incentives, deductions.
- **Attendance** — calendar view of present / absent / leave per month.
- **Leave history** — past leave requests and statuses.
- **Notifications** — in-app feed of all alerts you've received.
- **GPS Override request** — if a geofence check is failing for a valid reason, request the admin to allow you to skip it.
- **Change password.**

### Other things MRs can do
- **Apply Leave** — pick a date range, give a reason, submit. Admin approves or rejects.
- **Conversions** — report a new doctor you'd like added to the system. Admin reviews.
- **RCPA / Tour Plan** — see the route the admin has planned for you.

---

## 4. For Stockists

Your job is to receive orders from MRs (after admin approval), fulfil them, and keep the admin informed about stock levels.

### Bottom navigation (4 tabs)

#### 🏠 Dashboard
- Welcome banner with your name.
- Counts: Pending Orders, Accepted Orders, Total Products, All Orders.
- Quick actions: Manage Orders, View Products, Report Low Stock.

#### 📦 Orders
- Two tabs: **Pending** and **All Orders**.
- Each card shows the MR name, doctor name, products, and total amount.
- **To process an order:**
  1. Tap an order to open the detail view.
  2. Review items, quantities, and rates.
  3. Tap **Accept** to confirm, or **Reject** if you can't fulfil it.
- You'll get a real-time **📦 New Order Received** notification whenever a new one arrives.

#### 📊 Stock
- View all products and current stock levels.
- Items at or below their threshold are highlighted as **low stock**.

#### 👤 Profile
- Your name, email, mobile.
- **Change password.**

### Other things stockists can do
- **Report Low Stock** — pick the products that are running low / out of stock and submit a report to the admin.
- **Notifications** — in-app feed of all alerts.

---

## 5. For Admins

You see and control everything. The admin app has 7 main tabs plus several sub-screens.

### Bottom navigation (7 tabs)

#### 🏠 Dashboard
At-a-glance cards for the whole operation:
- Total MRs, Total Doctors, Pending Orders, Pending Leave Requests, Approved Orders, Reports Today, Stockists.
- Bell icon (top) shows pending-approvals count → tap to jump to the **Approvals** screen.

#### 📊 Stock
- Live inventory across all products.
- Stock levels and status of each item.

#### 📦 Orders
- Two tabs: **Pending** and **All Orders**.
- View MR name, doctor, products, status.
- Move orders along the lifecycle: pending → approved → billed → dispatched → delivered.

#### 👥 MRs
- Search and filter all MRs.
- View / edit MR profile (name, email, mobile).
- See an MR's allowance / commission history.
- **Add a new MR.**
- Assign a **tour plan** (RCPA) to an MR.

#### 🔄 Conversions
- Pending and historical conversion requests (MRs proposing new doctors).
- Approve or reject each request. The badge shows how many are pending.

#### 🗺 RCPA
- Route Call Plan Analysis: tour planning for the field force.
- Manage **headquarters** and **areas**.
- Assign HQs / areas to MRs.

#### ⚙ Manage
- Your admin profile.
- **Change password.**
- **Logout.**

### Sub-screens you can reach from the dashboard / approvals

- **Leave Approvals** — pending leave requests; see the date range, reason, MR; approve or reject.
- **GPS Override Requests** — MRs asking permission to skip a failed geofence; approve case-by-case.
- **Doctor Management** — search, add, edit doctors; filter by tier (Core / Super Core / Premium).
- **Stockist Management** — add and manage stockist accounts.
- **Attendance** — see daily attendance for any date; mark present / absent / leave.
- **MR Reports** — view daily reports submitted by each MR.
- **Stock Reports** — low-stock alerts filed by stockists.
- **Doctor Order Summary** — analytics: total orders per doctor, conversion timeline.

---

## 6. Notifications

Arkphora sends real-time notifications for every important event. They appear as phone notifications **and** in your in-app notifications feed.

| You'll be notified when… | Who gets it |
|---|---|
| New order is placed | Admin, Stockist |
| Order is approved / rejected / billed / dispatched / delivered / cancelled | MR |
| Leave request is submitted | Admin |
| Leave request is approved / rejected | MR |
| Daily report is submitted | Admin |
| Stockist files a low-stock report | Admin |
| Stock is low or out for a product | Stockist |

Tapping a notification opens the relevant screen directly.

---

## 7. Security & Anti-Fraud

Arkphora has several built-in safeguards. Most users won't notice them — they exist to keep field data honest.

- **Geofence check** — MRs can only check in to a doctor when physically near the clinic.
- **Mock-location detection** — fake-GPS apps are detected and blocked. You'll see "⚠ Fake GPS detected. Disable mock location apps and try again."
- **Screen security (MR only)** — screenshots and screen recording are blocked.
- **Single active session per user** — logging in on a new device evicts the old session.
- **Account deactivation** — admins can instantly disable an MR's access; the app will lock them out on next launch.

---

## 8. Common Workflows (Quick Reference)

### MR: Visit a doctor and place an order
1. Open **Doctors** tab → tap doctor → check in (GPS verified).
2. Open **Orders** tab → **Place Order** → select doctor → add products → submit.
3. Wait for admin to approve. You'll get a notification.

### MR: Submit your daily report
1. Open **Reports** tab → **Submit today's report** → write summary → submit.
2. Once submitted, the warning banner on your dashboard disappears.

### MR: Apply for leave
1. **Profile** → **Apply Leave** → pick date range → enter reason → submit.
2. Admin will approve or reject; you'll be notified.

### Stockist: Process a new order
1. Notification: 📦 New Order Received → tap.
2. Review items → **Accept** (or reject if you can't fulfil).

### Stockist: Report low stock
1. **Dashboard** → **Report Low Stock** → select items → submit.
2. Admin sees it on the **Stock Reports** screen.

### Admin: Approve a leave request
1. Bell icon on dashboard (or open **Leave Approvals**).
2. See request details → **Approve** or **Reject**.

### Admin: Add a new MR
1. **MRs** tab → **Add MR** → fill in name, email, mobile, division → save.
2. The new MR can now log in with the credentials provided.

### Admin: Approve a new doctor (conversion)
1. **Conversions** tab → see pending → review doctor and hospital → **Approve** / **Reject**.

---

## 9. Troubleshooting

| Problem | Try this |
|---|---|
| Can't log in | Confirm email/password. If "Account Deactivated" — contact your admin. |
| Doctor check-in fails | Make sure GPS is on, you're near the clinic, and you're not using a fake-GPS app. If you have a valid reason, request a **GPS Override** from your profile. |
| Not getting notifications | Check that notifications are allowed for Arkphora in your phone's settings. |
| Order stuck in "pending" | The admin hasn't approved it yet. They'll get to it; you'll be notified when status changes. |
| Forgot password | Ask your admin to reset it for you. |
| App shows "Connecting…" forever | Check your internet connection and reopen the app. |

---

## 10. Glossary

- **MR** — Medical Representative; the field rep who visits doctors.
- **Stockist** — distributor / wholesaler who fulfils orders.
- **RCPA** — Route Call Plan Analysis; the planned daily/weekly route an MR follows.
- **Tier** — doctor classification: Normal / Core / Super Core / Premium.
- **Geofence** — a virtual radius around a doctor's clinic; MRs must be inside it to check in.
- **Conversion** — adding a new doctor to the official list (needs admin approval).
- **Allowance / Incentive** — money earned by an MR based on activity / performance.
- **HQ / Area** — headquarters and the geographical areas under it; MRs are assigned to specific HQs.

---

*This guide covers the app at a glance. For account-specific issues (password resets, role changes, feature access), contact your administrator.*
