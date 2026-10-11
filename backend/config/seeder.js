// Resets the database to the shared demo dataset used by both portals.
// Run with: npm run seed   (WARNING: deletes all existing records)
import dotenv from 'dotenv';
import mongoose from 'mongoose';
import connectDB from './db.js';
import { seedDatabase } from './seed.js';

dotenv.config({ quiet: true });

try {
  await connectDB();
  await seedDatabase();
  await mongoose.disconnect();
} catch (error) {
  console.error(`❌ Seeding failed: ${error.message}`);
  process.exit(1);
}
