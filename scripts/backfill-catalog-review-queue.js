/**
 * Mark miscategorized active products for admin catalog review.
 *
 * Usage (from van1/my-flutter/functions with service account / firebase login):
 *   node ../scripts/backfill-catalog-review-queue.js --dry-run
 *   node ../scripts/backfill-catalog-review-queue.js --execute
 */
const admin = require('firebase-admin');
const catalogTaxonomy = require('../functions/catalog_taxonomy');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

function shouldQueueForReview(product, shopServiceType) {
  if (product.isActive !== true) {
    return false;
  }
  if (product.catalogAdminLocked === true) {
    return false;
  }
  if (product.catalogReviewStatus === 'pending') {
    return false;
  }

  const catalogType = String(product.catalogType || '').trim();
  const catalogHeading = String(product.catalogHeading || '').trim();
  if (!catalogType || !catalogHeading) {
    return true;
  }

  const reviewEval = catalogTaxonomy.evaluateCatalogReviewRequired({
    serviceType: shopServiceType,
    catalogType,
    catalogHeading,
    catalogTypeConfidence: product.catalogTypeConfidence ?? 0,
    catalogHeadingConfidence: product.catalogHeadingConfidence ?? 0,
    product,
    fromRule: false,
  });
  return reviewEval.required;
}

async function loadShopServiceTypes() {
  const snapshot = await db.collection('public_shops').get();
  const map = new Map();
  snapshot.docs.forEach((doc) => {
    const data = doc.data() || {};
    map.set(
      doc.id,
      catalogTaxonomy.normalizeShopServiceType(data.serviceType || data.service_type || ''),
    );
  });
  return map;
}

async function main() {
  const execute = process.argv.includes('--execute');
  const dryRun = !execute;
  const shopServiceTypes = await loadShopServiceTypes();
  const snapshot = await db.collection('products').where('isActive', '==', true).get();

  let queued = 0;
  for (const doc of snapshot.docs) {
    const product = doc.data() || {};
    const shopId = String(product.ownerUid || product.ownerId || '').trim();
    const serviceType = shopServiceTypes.get(shopId) || '';
    if (!shouldQueueForReview(product, serviceType)) {
      continue;
    }

    queued += 1;
    console.log(`[queue] ${doc.id} ${product.name || '-'} -> pending review`);
    if (!dryRun) {
      await doc.ref.set({
        catalogReviewStatus: 'pending',
        catalogReviewReasons: ['backfill_miscategorized'],
        catalogReviewReasonLabels: ['จัดหมวดใหม่หลังอัปเดตระบบ'],
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
  }

  console.log(`${dryRun ? 'Dry run' : 'Executed'}: queued ${queued} products`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
