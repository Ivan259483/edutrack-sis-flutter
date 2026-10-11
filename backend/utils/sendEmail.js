import nodemailer from 'nodemailer';

/**
 * Send an email verification OTP to a recipient's Gmail address
 * @param {string} toEmail - Recipient email address
 * @param {string} otpCode - 6-digit numeric OTP code
 */
export const sendVerificationEmail = async (toEmail, otpCode) => {
  const emailUser = process.env.EMAIL_USER;
  const emailPass = process.env.EMAIL_PASS;

  // Check if SMTP credentials are configured
  if (!emailUser || !emailPass) {
    console.warn('⚠️ EMAIL_USER or EMAIL_PASS not set in .env. Falling back to console verification code.');
    console.log(`[SMTP DEV LOG] Recipient: ${toEmail} | Verification OTP: ${otpCode}`);
    return { success: true, simulated: true };
  }

  // Create Nodemailer Transporter for Gmail SMTP
  const transporter = nodemailer.createTransport({
    service: 'gmail',
    host: 'smtp.gmail.com',
    port: 465,
    secure: true, // Use SSL
    auth: {
      user: emailUser,
      pass: emailPass, // Gmail 16-character App Password
    },
  });

  const htmlContent = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>EduTrack Email Verification</title>
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f1f5f9; margin: 0; padding: 20px; color: #1e293b; }
        .container { max-width: 520px; margin: 0 auto; background: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.06); border: 1px solid #e2e8f0; }
        .header { background: #0f172a; padding: 24px; text-align: center; }
        .header h1 { color: #ffffff; margin: 0; font-size: 20px; font-weight: 700; letter-spacing: -0.5px; }
        .header p { color: #94a3b8; margin: 4px 0 0; font-size: 13px; }
        .content { padding: 32px 28px; text-align: center; }
        .greeting { font-size: 16px; font-weight: 600; color: #0f172a; margin-bottom: 12px; }
        .message { font-size: 14px; color: #475569; line-height: 1.6; margin-bottom: 24px; }
        .otp-box { background: #f8fafc; border: 2px dashed #2563eb; border-radius: 10px; padding: 18px 24px; display: inline-block; margin-bottom: 24px; }
        .otp-label { font-size: 11px; text-transform: uppercase; letter-spacing: 1px; color: #64748b; margin-bottom: 6px; font-weight: 600; }
        .otp-code { font-size: 32px; font-weight: 800; color: #1d4ed8; letter-spacing: 8px; font-family: 'Courier New', Courier, monospace; }
        .expiry { font-size: 12px; color: #dc2626; font-weight: 500; margin-bottom: 24px; }
        .footer { background: #f8fafc; padding: 18px 24px; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #f1f5f9; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>EduTrack Student Information System</h1>
          <p>Academic Portal Security & Account Verification</p>
        </div>
        <div class="content">
          <div class="greeting">Student Account Verification</div>
          <div class="message">
            Thank you for registering on the EduTrack portal. To complete your student registration and verify your email address, please enter the one-time verification code below:
          </div>
          <div class="otp-box">
            <div class="otp-label">One-Time Password (OTP)</div>
            <div class="otp-code">${otpCode}</div>
          </div>
          <div class="expiry">
            This verification code is valid for 5 minutes only. Do not share this code with anyone.
          </div>
          <div style="font-size: 12px; color: #64748b;">
            If you did not initiate this registration request, please disregard this email.
          </div>
        </div>
        <div class="footer">
          &copy; ${new Date().getFullYear()} EduTrack SIS. All rights reserved.<br>
          Office of the University Registrar & Admissions
        </div>
      </div>
    </body>
    </html>
  `;

  const mailOptions = {
    from: `"EduTrack SIS Portal" <${emailUser}>`,
    to: toEmail,
    subject: `EduTrack Verification Code: ${otpCode}`,
    text: `Your EduTrack Student Registration verification code is: ${otpCode}. Valid for 5 minutes.`,
    html: htmlContent,
  };

  const info = await transporter.sendMail(mailOptions);
  console.log(`[SMTP] Verification email sent to ${toEmail}: ${info.messageId}`);
  return { success: true, messageId: info.messageId };
};
