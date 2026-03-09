/**
 * One-time script to set Firebase custom claim role=admin.
 * Run: node tools/set_admin_claim.js metiennewebdesigns@gmail.com
 */

const admin = require("firebase-admin");

const email = process.argv[2];
if (!email) {
  console.error("Usage: node tools/set_admin_claim.js <email>");
  process.exit(1);
}

// IMPORTANT: download a service account json from Firebase project settings
// and save it as: tools/pink-fleets-service-account.json
const serviceAccount = require("./pink-fleets-service-account.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

(async () => {
  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().setCustomUserClaims(user.uid, { role: "admin" });
  console.log(`✅ Set role=admin for ${email} (uid=${user.uid})`);
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
