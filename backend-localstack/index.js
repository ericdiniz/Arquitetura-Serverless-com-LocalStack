/*
 Simple Express backend that accepts multipart uploads at POST /upload
 and sends the file to S3 (LocalStack), puts a message on SQS, publishes to SNS
 and creates an entry in DynamoDB. Configuration: set LOCALSTACK_ENDPOINT to
 http://localhost:4566 or to http://localstack:4566 if running inside Docker Compose.
*/

const express = require('express');
const multer = require('multer');
const AWS = require('aws-sdk');
const bodyParser = require('body-parser');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const UPLOAD_BUCKET = process.env.UPLOAD_BUCKET || 'shopping-images';
const LOCALSTACK_ENDPOINT = process.env.LOCALSTACK_ENDPOINT || 'http://localhost:4566';

// Configure AWS SDK to point to LocalStack
AWS.config.update({
  accessKeyId: 'test',
  secretAccessKey: 'test',
  region: 'us-east-1',
  sslEnabled: false,
  s3ForcePathStyle: true,
  endpoint: LOCALSTACK_ENDPOINT
});

const s3 = new AWS.S3({ endpoint: LOCALSTACK_ENDPOINT });
const sqs = new AWS.SQS({ endpoint: LOCALSTACK_ENDPOINT });
const sns = new AWS.SNS({ endpoint: LOCALSTACK_ENDPOINT });
const dynamo = new AWS.DynamoDB.DocumentClient({ endpoint: LOCALSTACK_ENDPOINT });

const app = express();
app.use(cors());
app.use(bodyParser.json());

const upload = multer({ dest: path.join(__dirname, 'uploads/') });

async function ensureBucket() {
  try {
    await s3.headBucket({ Bucket: UPLOAD_BUCKET }).promise();
    console.log('Bucket exists:', UPLOAD_BUCKET);
  } catch (err) {
    if (err.statusCode === 404 || err.code === 'NotFound') {
      console.log('Creating bucket:', UPLOAD_BUCKET);
      await s3.createBucket({ Bucket: UPLOAD_BUCKET }).promise();
    } else {
      console.log('headBucket err', err);
    }
  }
}

async function ensureDynamoTable() {
  const tableName = 'Images';
  const dynamoRaw = new AWS.DynamoDB({ endpoint: LOCALSTACK_ENDPOINT });
  const tables = await dynamoRaw.listTables().promise();
  if (!tables.TableNames.includes(tableName)) {
    console.log('Creating DynamoDB table:', tableName);
    await dynamoRaw.createTable({
      TableName: tableName,
      AttributeDefinitions: [
        { AttributeName: 'id', AttributeType: 'S' }
      ],
      KeySchema: [
        { AttributeName: 'id', KeyType: 'HASH' }
      ],
      BillingMode: 'PAY_PER_REQUEST'
    }).promise();
  }
}

(async () => {
  // Ensure resources exist in LocalStack
  await ensureBucket();
  await ensureDynamoTable();

  app.post('/upload', upload.single('file'), async (req, res) => {
    try {
      if (!req.file) return res.status(400).json({ error: 'file required' });

      const fileStream = fs.createReadStream(req.file.path);
      const key = `${Date.now()}_${req.file.originalname}`;

      await s3.upload({ Bucket: UPLOAD_BUCKET, Key: key, Body: fileStream }).promise();

      // Put item into DynamoDB
      const item = { id: key, filename: req.file.originalname, uploadedAt: Date.now() };
      await dynamo.put({ TableName: 'Images', Item: item }).promise();

      // Send message to SQS (create queue if not exists)
      const queueName = 'images-queue';
      const q = await sqs.createQueue({ QueueName: queueName }).promise();
      await sqs.sendMessage({ QueueUrl: q.QueueUrl, MessageBody: JSON.stringify({ s3Key: key }) }).promise();

      // Publish to SNS (create topic if not exists)
      const topicName = 'images-topic';
      const t = await sns.createTopic({ Name: topicName }).promise();
      await sns.publish({ TopicArn: t.TopicArn, Message: JSON.stringify({ s3Key: key }) }).promise();

      // cleanup uploaded tmp file
      fs.unlink(req.file.path, () => {});

      return res.json({ success: true, key });
    } catch (error) {
      console.error('upload error', error);
      return res.status(500).json({ error: error.message });
    }
  });

  const port = process.env.PORT || 3000;
  app.listen(port, () => console.log(`Backend listening on http://localhost:${port}`));
})();
