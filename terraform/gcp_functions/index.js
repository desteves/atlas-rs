const { MongoClient } = require('mongodb');

const DEFAULT_OPERATION_TIMEOUT_MS = 8000;
const MAX_OPERATION_TIMEOUT_MS = 9000;
const DEFAULT_ALLOWED_ORIGINS = [
  'https://storage.googleapis.com',
];

const configuredTimeout = Number.parseInt(process.env.OPERATION_TIMEOUT_MS || process.env.MONGODB_TIMEOUT_MS || '', 10);
const operationTimeoutMs = Math.max(
  2000,
  Math.min(Number.isFinite(configuredTimeout) ? configuredTimeout : DEFAULT_OPERATION_TIMEOUT_MS, MAX_OPERATION_TIMEOUT_MS)
);

const allowAnyOrigin = process.env.CORS_ALLOW_ANY === '1';
const allowedOriginSet = new Set([
  ...DEFAULT_ALLOWED_ORIGINS,
  ...String(process.env.CORS_ALLOWED_ORIGINS || '')
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.length > 0),
]);

let cached;

function isStorageOrigin(origin) {
  return Boolean(origin && origin.endsWith('.storage.googleapis.com'));
}

function resolveAllowedOrigin(origin) {
  if (allowAnyOrigin) {
    return '*';
  }
  if (origin && (allowedOriginSet.has(origin) || isStorageOrigin(origin))) {
    return origin;
  }
  if (allowAnyOrigin || allowedOriginSet.has('*')) {
    return '*';
  }
  return allowedOriginSet.values().next().value || '*';
}

function applyCors(req, res) {
  const origin = req.get('Origin');
  res.set('Vary', 'Origin');
  res.set('Access-Control-Allow-Origin', resolveAllowedOrigin(origin));
  res.set('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.set('Access-Control-Allow-Headers', req.get('Access-Control-Request-Headers') || 'Content-Type, Accept');
  res.set('Access-Control-Max-Age', '3600');
}

function isTimeoutError(err) {
  if (!err) return false;
  if (err.name === 'MongoServerSelectionError' || err.name === 'MongoNetworkTimeoutError') return true;
  if (typeof err.code === 'number' && (err.code === 50 || err.code === 89)) return true; // MaxTimeMSExpired / NetworkTimeout
  if (typeof err.message === 'string' && err.message.toLowerCase().includes('timed out')) return true;
  return false;
}

async function getClient(){
  if(!cached){
    const uri = process.env.MONGODB_URI; if(!uri) throw new Error('MONGODB_URI not set');
    const client = new MongoClient(uri,{
      maxPoolSize:5,
      serverSelectionTimeoutMS: operationTimeoutMs,
      connectTimeoutMS: operationTimeoutMs,
      socketTimeoutMS: operationTimeoutMs,
    });
    cached = client.connect();
  }
  return cached;
}
const allowedReadPrefs = new Set(['primary', 'primaryPreferred', 'secondary', 'secondaryPreferred', 'nearest']);
function getReadPreference() {
  const rp = (process.env.READ_PREFERENCE || 'primary').trim();
  return allowedReadPrefs.has(rp) ? rp : 'primary';
}

exports.handler = async (req, res) => {
  applyCors(req, res);
  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }
  try {
    const client = await getClient();
    const coll = client.db('test').collection('test');
    const path = (req.path || req.url || '/');

    // Default read preference  
    let rp = 'primary';

    if (req.method === 'GET') {
      // Look for rp in query string, e.g. /latest?rp=secondary  
      const queryRp = (req.query && req.query.rp) ? String(req.query.rp).trim() : '';
      if (allowedReadPrefs.has(queryRp)) {
        rp = queryRp;
      }
      if (path === '/latest' || path === '/' || path.startsWith('/latest')) {
        const t0 = Date.now();
        const doc = await coll.find({}, { readPreference: rp }).sort({ timestamp: -1 }).limit(1).next();
        const dbMs = Date.now() - t0;
        res.status(200).json({ latest: doc || null, readPreference: rp, dbMs: dbMs }); return;
      }
    }
    if (req.method === 'POST' && (path === '/greet' || path.startsWith('/greet'))) {
      const greetings = ['Hello', 'Hi', 'Gday', 'Hola', 'Bonjour', 'Ciao', 'Kia Ora', 'Namaste'];
      const message = greetings[Math.floor(Math.random() * greetings.length)] + ' from Cloud Function';
      const now = new Date().toISOString();
      const t0 = Date.now();
      const r = await coll.insertOne({ message, timestamp: now }, { maxTimeMS: operationTimeoutMs });
      const dbMs = Date.now() - t0;
      res.status(200).json({ insertedId: r.insertedId, message, timestamp: now, dbMs }); return;
    }
    res.status(404).json({ error:'Not found' });
  } catch(e){
    console.error(e);
    if (!res.headersSent) {
      if (isTimeoutError(e)) {
        res.status(504).json({ error: 'Upstream timeout talking to MongoDB', detail: e.message });
      } else {
        res.status(500).json({ error: e.message });
      }
    }
  }
};
