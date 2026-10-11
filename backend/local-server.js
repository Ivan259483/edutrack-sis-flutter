// Local development server (`npm run dev` / `npm start`). On Vercel, app.js is
// the entrypoint instead and connects to MongoDB on the first request.
import dotenv from 'dotenv';

// Load environment variables before anything reads them
dotenv.config({ quiet: true });

if (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < 32) {
  console.error('❌ JWT_SECRET must be set in .env and be at least 32 characters long.');
  process.exit(1);
}

const { default: connectDB } = await import('./config/db.js');
const { default: app } = await import('./app.js');

// Connect to MongoDB before accepting requests
try {
  await connectDB();
} catch (error) {
  console.error(`❌ MongoDB Connection Error: ${error.message}`);
  console.error('   Is MongoDB running? (brew services start mongodb-community@8.0)');
  process.exit(1);
}

const PORT = process.env.PORT || 5001;
app.listen(PORT, () => {
  console.log(`🚀 Server running in ${process.env.NODE_ENV || 'development'} mode on http://localhost:${PORT}`);
});
