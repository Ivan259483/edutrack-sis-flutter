import mongoose from 'mongoose';
import { clientJson, PROGRAMS, recordFields, YEAR_LEVELS } from './plugins.js';

const studentSchema = new mongoose.Schema(
  {
    ...recordFields,
    // Login account; null until the student registers/claims the record.
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    studentId: {
      type: String,
      required: [true, 'Student ID is required'],
      unique: true,
      trim: true,
    },
    fullName: { type: String, required: [true, 'Full name is required'], trim: true },
    email: {
      type: String,
      required: [true, 'Email is required'],
      unique: true,
      trim: true,
      lowercase: true,
    },
    contactNumber: { type: String, required: true, trim: true },
    address: { type: String, required: true, trim: true },
    emergencyContact: { type: String, required: true, trim: true },
    emergencyContactNumber: { type: String, required: true, trim: true },
    program: { type: String, enum: PROGRAMS, required: true },
    yearLevel: { type: String, enum: YEAR_LEVELS, required: true },
    section: { type: String, required: true, trim: true },
    academicStatus: {
      type: String,
      enum: ['Active', 'On Leave', 'Graduated', 'Suspended'],
      default: 'Active',
    },
    dateEnrolled: { type: String, required: true },
    avatarInitials: { type: String, required: true },

    // Optional personal details shown on the student portal profile.
    gender: { type: String, default: '' },
    dateOfBirth: { type: String, default: '' },
    civilStatus: { type: String, default: 'Single' },
    nationality: { type: String, default: 'Filipino' },
    personalEmail: { type: String, default: '', trim: true, lowercase: true },
    guardianRelationship: { type: String, default: '' },
  },
  { timestamps: true }
);

clientJson(studentSchema, ['user']);

export default mongoose.model('Student', studentSchema);
