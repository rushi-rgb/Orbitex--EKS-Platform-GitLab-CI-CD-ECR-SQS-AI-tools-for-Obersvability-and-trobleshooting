/**
 * Background Worker — SQS Consumer
 * KEDA autoscales this deployment based on SQS queue depth
 */

const {
  SQSClient,
  ReceiveMessageCommand,
  DeleteMessageCommand,
} = require('@aws-sdk/client-sqs');

const QUEUE_URL   = process.env.QUEUE_URL;
const AWS_REGION  = process.env.AWS_REGION || 'us-east-1';
const WORKER_TYPE = process.env.WORKER_TYPE; // content | market | ai | notification

const sqs = new SQSClient({ region: AWS_REGION });

// ── Handler registry ──────────────────────────────────────────────────────────
const handlers = {
  content:      require('./handlers/content'),
  market:       require('./handlers/market'),
  ai:           require('./handlers/ai'),
  notification: require('./handlers/notification'),
};

const handler = handlers[WORKER_TYPE];
if (!handler) {
  console.error(`Unknown WORKER_TYPE: ${WORKER_TYPE}`);
  process.exit(1);
}

// ── Poll loop ─────────────────────────────────────────────────────────────────
async function pollQueue() {
  console.log(`[${WORKER_TYPE}] Starting. Queue: ${QUEUE_URL}`);

  while (true) {
    try {
      const response = await sqs.send(new ReceiveMessageCommand({
        QueueUrl:            QUEUE_URL,
        MaxNumberOfMessages: 10,
        WaitTimeSeconds:     20, // Long polling
        VisibilityTimeout:   300,
      }));

      const messages = response.Messages || [];
      if (messages.length === 0) continue;

      console.log(`[${WORKER_TYPE}] Received ${messages.length} messages`);

      await Promise.allSettled(
        messages.map(async (msg) => {
          try {
            const body = JSON.parse(msg.Body);
            await handler.process(body);
            await sqs.send(new DeleteMessageCommand({
              QueueUrl:      QUEUE_URL,
              ReceiptHandle: msg.ReceiptHandle,
            }));
            console.log(`[${WORKER_TYPE}] Processed message ${msg.MessageId}`);
          } catch (err) {
            console.error(`[${WORKER_TYPE}] Failed message ${msg.MessageId}:`, err.message);
            // Message stays in queue → goes to DLQ after maxReceiveCount
          }
        })
      );
    } catch (err) {
      console.error(`[${WORKER_TYPE}] Poll error:`, err.message);
      await new Promise(r => setTimeout(r, 5000)); // Back off on error
    }
  }
}

// ── Graceful shutdown ─────────────────────────────────────────────────────────
process.on('SIGTERM', () => {
  console.log(`[${WORKER_TYPE}] SIGTERM received — shutting down`);
  process.exit(0);
});

pollQueue().catch((err) => {
  console.error('Fatal poll error:', err);
  process.exit(1);
});
