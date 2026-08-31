const AI_CONFIDENCE_THRESHOLD = 80;

const MARKET_CATALOG_TYPES = [
  { label: 'ผักสด', sort: 10, headings: ['ผักใบ', 'ผักสวนครัว', 'ผักสด'] },
  { label: 'ผลไม้', sort: 20, headings: ['ผลไม้สด', 'มะม่วง', 'กล้วย', 'ส้ม', 'ทุเรียน', 'แก้วมังกร'] },
  { label: 'เนื้อสัตว์', sort: 30, headings: ['หมูสด', 'ไก่สด', 'เนื้อสด', 'เนื้อสัตว์'] },
  { label: 'อาหารทะเลสด', sort: 40, headings: ['ปลาสด', 'กุ้งสด', 'ปูสด', 'หอยสด', 'ปลาหมึกสด', 'อาหารทะเลสด'] },
  {
    label: 'อาหารทะเลแปรรูป',
    sort: 50,
    headings: ['ปลาหมึกแห้ง', 'ปลาแห้ง / ปลาแดดเดียว', 'อาหารทะเลแปรรูป'],
  },
  { label: 'ไข่ / เต้าหู้', sort: 60, headings: ['ไข่', 'เต้าหู้'] },
  { label: 'อาหารพร้อมทาน', sort: 70, headings: ['อาหารพร้อมทาน'] },
  { label: 'ของแห้ง / วัตถุดิบ', sort: 80, headings: ['ข้าวสาร', 'เส้น / บะหมี่', 'ของแห้ง / วัตถุดิบ'] },
  { label: 'เครื่องปรุง / ซอส', sort: 90, headings: ['น้ำปลา', 'ซอส / ซีอิ๊ว', 'เครื่องปรุง / ซอส'] },
  { label: 'ขนม / เบเกอรี่', sort: 100, headings: ['ขนม', 'เบเกอรี่'] },
  { label: 'เครื่องดื่ม', sort: 110, headings: ['น้ำดื่ม', 'ชา', 'กาแฟ', 'เครื่องดื่ม'] },
  { label: 'เสื้อผ้า', sort: 120, headings: ['เสื้อ', 'กางเกง', 'กระโปรง', 'เสื้อผ้า'] },
  { label: 'ชุดนักเรียน / เครื่องแบบ', sort: 130, headings: ['ชุดนักเรียน'] },
  { label: 'รองเท้า / กระเป๋า', sort: 140, headings: ['รองเท้านักเรียน', 'รองเท้า', 'กระเป๋า'] },
  { label: 'ของใช้ในบ้าน', sort: 150, headings: ['ซักผ้า', 'ล้างจาน', 'ของใช้ในบ้าน'] },
  { label: 'ของใช้ส่วนตัว', sort: 160, headings: ['ของใช้ส่วนตัว'] },
  { label: 'เครื่องเขียน / อุปกรณ์เรียน', sort: 170, headings: ['สมุด / กระดาษ', 'ปากกา / ดินสอ'] },
  { label: 'ของสด', sort: 190, headings: ['ของสด'] },
  { label: 'อื่นๆ', sort: 500000, headings: ['อื่นๆ'] },
];

const PHARMACY_CATALOG_TYPE = {
  label: 'ยาและเวชภัณฑ์',
  sort: 180,
  headings: [
    'ยาแก้ปวด / ลดไข้',
    'ยาแก้แพ้ / หวัด / ไอ',
    'ยาทางเดินอาหาร',
    'ยาภายนอก',
    'เวชภัณฑ์',
    'อุปกรณ์การแพทย์',
    'วิตามิน / อาหารเสริม',
    'แม่และเด็ก',
    'สุขภาพช่องปาก',
    'ดูแลผิว / ของใช้ส่วนตัว',
    'ยาและเวชภัณฑ์',
  ],
};

const CATALOG_REVIEW_REASON_LABELS = {
  low_catalog_type_confidence: 'ความมั่นใจหมวดใหญ่ต่ำกว่า 80%',
  low_catalog_heading_confidence: 'ความมั่นใจหัวข้อย่อยต่ำกว่า 80%',
  unknown_catalog_type: 'หมวดใหญ่ไม่อยู่ในรายการมาตรฐาน',
  unknown_catalog_heading: 'หัวข้อย่อยไม่อยู่ในรายการมาตรฐาน',
  service_type_mismatch: 'หมวดไม่ตรงประเภทร้าน',
  keyword_conflict: 'AI ขัดกับกฎสินค้าที่รู้จัก',
};

function normalizeShopServiceType(rawValue) {
  const normalized = String(rawValue || '').trim().toLowerCase();
  if (!normalized) return '';
  if (normalized.includes('ตลาด') || normalized.includes('market')) return 'ตลาด';
  if (
    normalized.includes('ร้านขายยา')
    || normalized === 'ยาและเวชภัณฑ์'
    || normalized.includes('pharmacy')
  ) {
    return 'ร้านขายยา';
  }
  if (normalized.includes('ร้านอาหาร') || normalized.includes('restaurant')) {
    return 'ร้านอาหาร';
  }
  if (normalized.includes('ร้านค้า') || normalized.includes('shop')) {
    return 'ร้านค้า';
  }
  return String(rawValue || '').trim();
}

function marketTypeLabels() {
  return MARKET_CATALOG_TYPES.map((entry) => entry.label);
}

function pharmacyTypeLabel() {
  return PHARMACY_CATALOG_TYPE.label;
}

function isKnownCatalogType(serviceType, catalogType) {
  const label = String(catalogType || '').trim();
  if (!label) return false;
  const normalizedService = normalizeShopServiceType(serviceType);
  if (normalizedService === 'ร้านขายยา') {
    return label === PHARMACY_CATALOG_TYPE.label;
  }
  if (normalizedService === 'ตลาด' || !normalizedService) {
    return MARKET_CATALOG_TYPES.some((entry) => entry.label === label);
  }
  return label === 'อื่นๆ' || marketTypeLabels().includes(label);
}

function headingsForType(serviceType, catalogType) {
  const label = String(catalogType || '').trim();
  const normalizedService = normalizeShopServiceType(serviceType);
  if (normalizedService === 'ร้านขายยา' && label === PHARMACY_CATALOG_TYPE.label) {
    return PHARMACY_CATALOG_TYPE.headings.slice();
  }
  const marketEntry = MARKET_CATALOG_TYPES.find((entry) => entry.label === label);
  return marketEntry ? marketEntry.headings.slice() : ['อื่นๆ'];
}

function isKnownCatalogHeading(serviceType, catalogType, catalogHeading) {
  const heading = String(catalogHeading || '').trim();
  if (!heading) return false;
  return headingsForType(serviceType, catalogType).includes(heading);
}

function defaultHeadingForType(serviceType, catalogType) {
  const allowed = headingsForType(serviceType, catalogType);
  return allowed[0] || 'อื่นๆ';
}

function sortForType(catalogType) {
  const label = String(catalogType || '').trim();
  const marketEntry = MARKET_CATALOG_TYPES.find((entry) => entry.label === label);
  if (marketEntry) return marketEntry.sort;
  if (label === PHARMACY_CATALOG_TYPE.label) return PHARMACY_CATALOG_TYPE.sort;
  return 500000;
}

function detectKeywordConflict(product, catalogType) {
  const source = [
    String(product?.name || '').trim(),
    String(product?.description || '').trim(),
    String(product?.aiProductType || product?.productType || '').trim(),
  ].join(' ').toLowerCase();
  const type = String(catalogType || '').trim();

  if (/แก้วมังกร|dragon fruit/.test(source) && type !== 'ผลไม้') {
    return true;
  }
  if (/ปลาหมึกแห้ง/.test(source) && type !== 'อาหารทะเลแปรรูป') {
    return true;
  }
  if (
    /เนื้อไก่สด|ไก่สด|เนื้อสด|หมูสด|fresh chicken|fresh meat|fresh pork/.test(source)
    && type !== 'ของสด'
    && type !== 'เนื้อสัตว์'
  ) {
    return true;
  }
  return false;
}

function evaluateCatalogReviewRequired({
  serviceType,
  catalogType,
  catalogHeading,
  catalogTypeConfidence,
  catalogHeadingConfidence,
  product,
  fromRule = false,
}) {
  if (fromRule) {
    return { required: false, reasons: [], reasonLabels: [] };
  }

  const reasons = [];
  const normalizedService = normalizeShopServiceType(serviceType);
  const type = String(catalogType || '').trim();
  const heading = String(catalogHeading || '').trim();
  const typeConfidence = Number(catalogTypeConfidence);
  const headingConfidence = Number(catalogHeadingConfidence);

  if (!Number.isFinite(typeConfidence) || typeConfidence < AI_CONFIDENCE_THRESHOLD) {
    reasons.push('low_catalog_type_confidence');
  }
  if (!Number.isFinite(headingConfidence) || headingConfidence < AI_CONFIDENCE_THRESHOLD) {
    reasons.push('low_catalog_heading_confidence');
  }
  if (!isKnownCatalogType(normalizedService, type)) {
    reasons.push('unknown_catalog_type');
  }
  if (!isKnownCatalogHeading(normalizedService, type, heading)) {
    reasons.push('unknown_catalog_heading');
  }
  if (normalizedService === 'ตลาด' && type === PHARMACY_CATALOG_TYPE.label) {
    reasons.push('service_type_mismatch');
  }
  if (normalizedService === 'ร้านขายยา' && type !== PHARMACY_CATALOG_TYPE.label) {
    reasons.push('service_type_mismatch');
  }
  if (detectKeywordConflict(product, type)) {
    reasons.push('keyword_conflict');
  }

  return {
    required: reasons.length > 0,
    reasons,
    reasonLabels: reasons.map((key) => CATALOG_REVIEW_REASON_LABELS[key] || key),
  };
}

function normalizeConfidence(value, fallback = 0) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(0, Math.min(100, Math.round(parsed)));
}

module.exports = {
  AI_CONFIDENCE_THRESHOLD,
  MARKET_CATALOG_TYPES,
  PHARMACY_CATALOG_TYPE,
  CATALOG_REVIEW_REASON_LABELS,
  normalizeShopServiceType,
  marketTypeLabels,
  pharmacyTypeLabel,
  isKnownCatalogType,
  isKnownCatalogHeading,
  headingsForType,
  defaultHeadingForType,
  sortForType,
  evaluateCatalogReviewRequired,
  normalizeConfidence,
};
