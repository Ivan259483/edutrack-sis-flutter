import { matchedData, validationResult } from 'express-validator';

// Runs after express-validator chains: rejects invalid input and replaces
// req.body with only the validated fields (prevents mass assignment).
export const validate = (req, res, next) => {
  const result = validationResult(req);
  if (!result.isEmpty()) {
    const errors = result.array().map((e) => ({ field: e.path, message: e.msg }));
    return res.status(400).json({
      message: errors.map((e) => `${e.field}: ${e.message}`).join('; '),
      errors,
    });
  }
  req.body = matchedData(req, { locations: ['body'] });
  next();
};
