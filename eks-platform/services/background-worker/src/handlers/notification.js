// Notification worker handler — sends email via SES / SendGrid
const { SESClient, SendEmailCommand } = require('@aws-sdk/client-ses');

const ses = new SESClient({ region: process.env.AWS_REGION || 'us-east-1' });

module.exports = {
  async process(body) {
    const { type, to, subject, htmlBody, textBody } = body;

    if (type !== 'EMAIL') {
      throw new Error(`Unknown notification type: ${type}`);
    }

    const provider = process.env.EMAIL_PROVIDER || 'ses';

    if (provider === 'ses') {
      await ses.send(new SendEmailCommand({
        Source: process.env.FROM_EMAIL || 'noreply@example.com',
        Destination: { ToAddresses: [to] },
        Message: {
          Subject: { Data: subject },
          Body: {
            Html: { Data: htmlBody },
            Text: { Data: textBody },
          },
        },
      }));
    } else {
      // SendGrid fallback — add @sendgrid/mail if needed
      throw new Error('SendGrid provider not yet implemented');
    }

    console.log(`[notification-handler] Email sent to ${to}: ${subject}`);
  },
};
