const { MongoClient } = require('mongodb');
let cached;
async function getClient(){
  if(!cached){
    const uri = process.env.MONGODB_URI; if(!uri) throw new Error('MONGODB_URI not set');
    const client = new MongoClient(uri,{ maxPoolSize:5, serverSelectionTimeoutMS:30000 });
    cached = client.connect();
  }
  return cached;
}
exports.handler = async (req, res) => {
  // Basic CORS support for cross-origin GCS -> Functions calls
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }
  try {
    const client = await getClient();
    const coll = client.db('test').collection('test');
    const path = (req.path || req.url || '/');
    if(req.method==='GET' && (path === '/latest' || path === '/' || path.startsWith('/latest'))){
      const doc = await coll.find({}, { readPreference:'nearest' }).sort({ timestamp:-1 }).limit(1).next();
      res.status(200).json({ latest: doc||null }); return;
    }
    if(req.method==='POST' && (path === '/greet' || path.startsWith('/greet'))){
      const greetings=['Hello','Hi','Gday','Hola','Bonjour','Ciao','Kia Ora','Namaste'];
      const message = greetings[Math.floor(Math.random()*greetings.length)] + ' from Cloud Function';
      const now = new Date().toISOString();
      const r = await coll.insertOne({ message, timestamp: now });
      res.status(200).json({ insertedId: r.insertedId, message, timestamp: now }); return;
    }
    res.status(404).json({ error:'Not found' });
  } catch(e){ console.error(e); res.status(500).json({ error: e.message }); }
};
