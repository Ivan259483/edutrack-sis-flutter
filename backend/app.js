import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import connectDB from './config/db.js';
import { errorHandler, notFound } from './middleware/error.js';
import { sanitize } from './middleware/sanitize.js';
import adminRoutes from './routes/adminRoutes.js';
import authRoutes from './routes/authRoutes.js';
import portalRoutes from './routes/portalRoutes.js';

// Frontends allowed to call this API (student portal + admin portal).
const allowedOrigins = (process.env.CLIENT_ORIGINS || 'http://localhost:5173,http://localhost:5174')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

// Fail fast (also on Vercel, where this module is the function entrypoint).
if (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < 32) {
  throw new Error('JWT_SECRET must be set and be at least 32 characters long.');
}

const app = express();
app.disable('x-powered-by');
// On Vercel, requests arrive through Vercel's proxy. Trust that one hop so
// req.ip is the visitor's address and the login rate limit counts each user
// separately. Locally there is no proxy, so this stays off.
if (process.env.VERCEL) app.set('trust proxy', 1);
app.use(helmet());
app.use(
  cors({
    origin: (origin, callback) =>
      // Requests without an Origin (curl, server-to-server) carry no browser credentials.
      callback(null, !origin || allowedOrigins.includes(origin)),
  })
);
app.use(express.json({ limit: '200kb' }));
app.use(sanitize);

app.get('/', (_req, res) => {
  res.json({
    message: '🎓 EduTrack: Student Information System API is running...',
    status: 'success',
  });
});
app.get('/api/health', (_req, res) => res.json({ status: 'ok' }));

// Every API route below needs the database: connect once, reuse afterwards.
app.use('/api', async (_req, res, next) => {
  try {
    await connectDB();
    next();
  } catch (error) {
    console.error(`❌ MongoDB Connection Error: ${error.message}`);
    res.status(503).json({ message: 'The database is unavailable. Please try again shortly.' });
  }
});

app.use('/api/auth', authRoutes);
app.use('/api/portal', portalRoutes);
app.use('/api', adminRoutes);

app.use(notFound);
app.use(errorHandler);

export default app;
