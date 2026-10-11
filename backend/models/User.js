import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';

const userSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Please add a name'],
      trim: true,
    },
    email: {
      type: String,
      required: [true, 'Please add an email'],
      unique: true,
      lowercase: true,
      trim: true,
      // Last line of defence only; routes validate with express-validator isEmail().
      // Accepts any domain ending (.info, .education, ...) and has no nested
      // quantifiers, so it can't backtrack catastrophically.
      match: [/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/, 'Please add a valid email'],
    },
    password: {
      type: String,
      required: [true, 'Please add a password'],
      minlength: [6, 'Password must be at least 6 characters'],
      select: false, // Don't return password in query results by default
    },
    role: {
      type: String,
      enum: ['admin', 'student'],
      default: 'student',
    },
    studentId: {
      type: String,
      trim: true,
      default: null,
    },
  },
  {
    timestamps: true, // Automatically manages createdAt and updatedAt
  }
);

// Encrypt password using bcrypt before saving to MongoDB
// (Only when it changed, so saving a user for other reasons never re-hashes the hash.)
userSchema.pre('save', async function () {
  if (!this.isModified('password')) return;
  const salt = await bcrypt.genSalt(10);
  this.password = await bcrypt.hash(this.password, salt);
});

userSchema.set('toJSON', {
  versionKey: false,
  transform: (_doc, ret) => {
    ret.id = ret._id;
    delete ret._id;
    delete ret.password;
    return ret;
  },
});

// Helper method to compare entered password with hashed password in database
userSchema.methods.matchPassword = async function (enteredPassword) {
  return await bcrypt.compare(enteredPassword, this.password);
};

const User = mongoose.model('User', userSchema);

export default User;