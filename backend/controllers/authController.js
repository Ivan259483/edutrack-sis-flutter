import bcrypt from 'bcryptjs';
import { randomInt } from 'node:crypto';
import User from '../models/User.js';
import Student from '../models/Student.js';
import Otp from '../models/Otp.js';
import { PROGRAM_NAMES, PROGRAMS } from '../models/plugins.js';
import { asyncHandler, HttpError } from '../middleware/error.js';
import generateToken from '../utils/generateToken.js';
import { sendVerificationEmail } from '../utils/sendEmail.js';
import { initials, today } from '../utils/rules.js';

const OTP_LIFETIME_MS = 5 * 60 * 1000;
const MAX_OTP_ATTEMPTS = 5;

const publicUser = (user, profile = null) => ({
  id: user.id,
  name: user.name,
  email: user.email,
  role: user.role,
  studentId: user.studentId,
  profile,
});

const programCode = (value) =>
  PROGRAMS.includes(value) ? value : Object.keys(PROGRAM_NAMES).find((k) => PROGRAM_NAMES[k] === value);

// @desc    Send a 5-digit verification code to the email address
// @route   POST /api/auth/send-otp
// @access  Public
export const sendOtp = asyncHandler(async (req, res) => {
  const { email } = req.body;
  if (await User.exists({ email })) {
    throw new HttpError(400, 'An account with this email already exists. Please sign in instead.');
  }
  // Cryptographically secure code; only its hash is stored.
  const otp = String(randomInt(10000, 100000));
  await Otp.findOneAndUpdate(
    { email },
    { otp: await bcrypt.hash(otp, 10), attempts: 0, verified: false, createdAt: new Date() },
    { upsert: true, setDefaultsOnInsert: true }
  );
  try {
    await sendVerificationEmail(email, otp);
  } catch (emailErr) {
    console.error('SMTP delivery error:', emailErr.message);
    if (process.env.NODE_ENV === 'production') {
      throw new HttpError(502, 'The verification email could not be sent. Please try again later.');
    }
    console.log(`[SMTP DEV LOG] Recipient: ${email} | Verification OTP: ${otp}`);
  }
  res.json({ status: 'success', message: `A 5-digit verification code has been sent to ${email}.` });
});

// @desc    Verify the emailed code
// @route   POST /api/auth/verify-otp
// @access  Public
export const verifyOtp = asyncHandler(async (req, res) => {
  const { email, otp } = req.body;
  const record = await Otp.findOne({ email });
  if (!record || Date.now() - record.createdAt.getTime() > OTP_LIFETIME_MS) {
    throw new HttpError(400, 'Verification code has expired or was not requested. Please request a new code.');
  }
  if (record.attempts >= MAX_OTP_ATTEMPTS) {
    throw new HttpError(429, 'Too many incorrect attempts. Please request a new code.');
  }
  if (!(await bcrypt.compare(otp, record.otp))) {
    record.attempts += 1;
    await record.save();
    throw new HttpError(400, 'Invalid verification code. Please check your email and try again.');
  }
  record.verified = true;
  await record.save();
  res.json({ status: 'success', message: 'Email address successfully verified.' });
});

// @desc    Register a student account (requires a verified email)
// @route   POST /api/auth/register
// @access  Public
export const registerUser = asyncHandler(async (req, res) => {
  const { firstName, lastName, email, password, yearLevel } = req.body;
  const program = programCode(req.body.program);

  const verification = await Otp.findOne({ email, verified: true });
  if (!verification) {
    throw new HttpError(400, 'Please verify your email address before registering.');
  }
  if (await User.exists({ email })) {
    throw new HttpError(400, 'An account with this email already exists.');
  }

  // A student record the registrar already created can be claimed by its owner
  // (email ownership was just proven by the verification code).
  let student = await Student.findOne({ email });
  if (student?.user) throw new HttpError(400, 'This student record already has an account.');

  const fullName = `${firstName} ${lastName}`;
  if (!student) {
    let studentId;
    do studentId = `${new Date().getFullYear()}-${randomInt(10000, 100000)}`;
    while (await Student.exists({ studentId }));
    student = new Student({
      studentId,
      fullName,
      email,
      contactNumber: 'Not provided',
      address: 'Not provided',
      emergencyContact: 'Not provided',
      emergencyContactNumber: 'Not provided',
      program,
      yearLevel,
      section: `${program} ${yearLevel[0]}A`,
      academicStatus: 'Active',
      dateEnrolled: today(),
      avatarInitials: initials(fullName),
    });
  }

  // Role is never taken from the request: self-registration is student-only.
  const user = await User.create({
    name: student.fullName,
    email,
    password,
    role: 'student',
    studentId: student.studentId,
  });
  student.user = user._id;
  try {
    await student.save();
  } catch (err) {
    await User.deleteOne({ _id: user._id });
    throw err;
  }
  await Otp.deleteOne({ _id: verification._id });

  res.status(201).json({
    status: 'success',
    token: generateToken(user._id, user.role),
    user: publicUser(user, student),
  });
});

// @desc    Sign in with email or student ID and get a JWT
// @route   POST /api/auth/login
// @access  Public
export const loginUser = asyncHandler(async (req, res) => {
  const { identifier, password, role } = req.body;
  const user = await User.findOne({
    $or: [{ email: identifier.toLowerCase() }, { studentId: identifier }],
  }).select('+password');

  // Same message for unknown user and wrong password (no account enumeration).
  if (!user || !(await user.matchPassword(password))) {
    throw new HttpError(401, 'Invalid email/student ID or password.');
  }
  if (role && user.role !== role) {
    throw new HttpError(
      403,
      `This account is registered as ${user.role === 'admin' ? 'an administrator' : 'a student'}. Please switch to the ${user.role} tab.`
    );
  }
  const profile = user.role === 'student' ? await Student.findOne({ user: user._id }) : null;
  res.json({
    status: 'success',
    token: generateToken(user._id, user.role),
    user: publicUser(user, profile),
  });
});

// @desc    Current signed-in user
// @route   GET /api/auth/me
// @access  Private
export const getMe = asyncHandler(async (req, res) => {
  const profile = req.user.role === 'student' ? await Student.findOne({ user: req.user._id }) : null;
  res.json({ user: publicUser(req.user, profile) });
});

// @desc    Change own password
// @route   PUT /api/auth/password
// @access  Private
export const changePassword = asyncHandler(async (req, res) => {
  const user = await User.findById(req.user._id).select('+password');
  if (!(await user.matchPassword(req.body.currentPassword))) {
    throw new HttpError(400, 'Current password is incorrect.');
  }
  user.password = req.body.password;
  await user.save();
  res.json({ status: 'success', message: 'Password updated.' });
});
