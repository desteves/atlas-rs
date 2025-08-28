const express = require('express');
const { MongoClient } = require('mongodb');
const PORT = process.env.PORT || 8080;
const MONGODB_URI = process.env.MONGODB_URI;
if(!MONGODB_URI) {
  console.error('MONGODB_URI not set');
  process.exit(1);
}
let clientPromise;
function getClient(){
  if(!clientPromise){
    const client = new MongoClient(MONGODB_URI,{ maxPoolSize:5, serverSelectionTimeoutMS:3000 });
    clientPromise = client.connect();
  }
  return clientPromise;
}
async function latest(req,res){
  try {
    const client = await getClient();
    const coll = client.db('test').collection('test');
    const doc = await coll.find({}, { readPreference:'nearest' }).sort({ timestamp:-1 }).limit(1).next();
    res.json({ latest: doc || null });
  } catch(e){ res.status(500).json({ error: e.message }); }
}
async function greet(req,res){
  try {
    const greetings=['Hello','Howdy','Gday','Hola','Bonjour','Ciao','Kia Ora','Namaste'];
    const message = greetings[Math.floor(Math.random()*greetings.length)] + ' from Cloud Run';
    const now = new Date().toISOString();
    const client = await getClient();
    const coll = client.db('test').collection('test');
    const r = await coll.insertOne({ message, timestamp: now });
    res.json({ insertedId: r.insertedId, message, timestamp: now });
  } catch(e){ res.status(500).json({ error: e.message }); }
}
const app = express();
app.get('/latest', latest);
app.post('/greet', greet);
app.get('/', (req,res)=>res.send('OK'));
app.listen(PORT, ()=>console.log(`Demo app listening on ${PORT}`));