import mongoose from 'mongoose';

// One connection per process, reused across requests. On Vercel a function
// instance serves many invocations, so the promise is cached on globalThis and
// only retried if the previous attempt failed.
const cache = (globalThis.__edutrackMongo ??= { promise: null });

const connectDB = async () => {
  if (mongoose.connection.readyState === 1) return mongoose.connection;
  if (!cache.promise) {
    if (!process.env.MONGO_URI) throw new Error('MONGO_URI is not set.');
    cache.promise = mongoose
      .connect(process.env.MONGO_URI, { serverSelectionTimeoutMS: 10000 })
      .then((conn) => {
        console.log(`🍃 MongoDB Connected: ${conn.connection.host}/${conn.connection.name}`);
        return conn.connection;
      })
      .catch((error) => {
        cache.promise = null; // let the next request try again
        throw error;
      });
  }
  return cache.promise;
};

export default connectDB;
