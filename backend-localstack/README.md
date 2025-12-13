# Backend for LocalStack demo

This tiny backend receives multipart uploads at `/upload` and stores files in S3 (LocalStack), creates a DynamoDB item, sends a message to SQS and publishes to SNS.

Run locally (outside Docker):

1. Install dependencies:

   ```bash
   cd backend-localstack
   npm install
   ```

2. Ensure LocalStack is running (see `docker-compose.localstack.yml`), then start the server:

   ```bash
   LOCALSTACK_ENDPOINT=http://localhost:4566 npm start
   ```

If running backend inside Docker Compose you can set `LOCALSTACK_ENDPOINT=http://localstack:4566` in compose or env.
