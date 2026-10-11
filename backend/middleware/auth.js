import jwt from 'jsonwebtoken';
import User from '../models/User.js';

// Verifies the `Authorization: Bearer <JWT>` header and loads the user.
export const protect = async (req, res, next) => {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({ message: 'Not authorized. Please sign in.' });
  }
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET, { algorithms: ['HS256'] });
    const user = await User.findById(decoded.id);
    if (!user) {
      return res.status(401).json({ message: 'Account no longer exists. Please sign in again.' });
    }
    req.user = user;
    next();
  } catch {
    return res.status(401).json({ message: 'Session expired or invalid. Please sign in again.' });
  }
};

// Restricts a route to the given roles, e.g. authorize('admin').
export const authorize =
  (...roles) =>
  (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ message: 'You do not have permission to perform this action.' });
    }
    next();
  };
