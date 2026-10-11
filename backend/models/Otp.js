import mongoose from 'mongoose';

const otpSchema = new mongoose.Schema({
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true,
  },
  // bcrypt hash of the code, so a database leak doesn't expose live codes.
  otp: {
    type: String,
    required: true,
  },
  attempts: { type: Number, default: 0 },
  // Set once the code is confirmed; /register consumes a verified record.
  verified: { type: Boolean, default: false },
  createdAt: {
    type: Date,
    default: Date.now,
    expires: 600, // MongoDB removes the record after 10 minutes
  },
});

const Otp = mongoose.model('Otp', otpSchema);

export default Otp;
