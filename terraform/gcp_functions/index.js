const { MongoClient } = require('mongodb');

let cached;

function applyCors(res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.set('Access-Control-Allow-Headers', '*');
  res.set('Access-Control-Max-Age', '3600');
  res.set('Cache-Control', 'no-store, max-age=0');
  res.set('Pragma', 'no-cache');
  res.set('Expires', '0');
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
      heartbeatFrequencyMS: 2000,
      serverSelectionTimeoutMS: 5000,
      connectTimeoutMS: 10000,
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
  applyCors(res);

  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }
  try {
    const client = await getClient();
    const coll = client.db('test').collection('test');
    const path = (req.path || req.url || '/');
    // Default read preference  
    let rp = 'primary';
    if(req.method==='GET' && (path === '/latest' || path === '/' || path.startsWith('/latest'))){
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
      const r = await coll.insertOne({ message, timestamp: now });
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
