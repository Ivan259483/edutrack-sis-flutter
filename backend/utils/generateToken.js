import jwt from 'jsonwebtoken';

// Signs a JWT containing the user's ID and role, valid for 24 hours.
const generateToken = (userId, role) =>
  jwt.sign({ id: String(userId), role }, process.env.JWT_SECRET, {
    algorithm: 'HS256',
    expiresIn: '24h',
  });

export default generateToken;
