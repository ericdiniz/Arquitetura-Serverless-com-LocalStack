#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const AWS = require('aws-sdk');
const { bucketExists, putObject } = require('../src/utils/s3');
const { createTopic, listTopics } = require('../src/utils/sns');
const { putItem, scanTable } = require('../src/utils/dynamodb');

// importa o handler
const { handler } = require('../src/handlers/dataProcessor');

// Config defaults
const S3_BUCKET = process.env.S3_BUCKET || 'local-data-bucket';
const S3_KEY = process.env.S3_KEY || 'produtos.csv';
const LOCAL_CSV = path.join(__dirname, '..', 'data', 'input', 'produtos.csv');
const AWS_ENDPOINT = process.env.AWS_ENDPOINT_URL || 'http://localhost:4566';

// Configure AWS default for this script (same as utils)
AWS.config.update({
    endpoint: AWS_ENDPOINT,
    region: process.env.AWS_REGION || 'us-east-1',
    accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'test',
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'test'
});

async function ensureDynamoTable() {
    // The utils expect a table named by TABLE_NAME or 'ProcessedData'
    const tableName = process.env.TABLE_NAME || 'ProcessedData';
    const dynamodb = new AWS.DynamoDB({ endpoint: AWS_ENDPOINT });
    try {
        const tables = await dynamodb.listTables().promise();
        if ((tables.TableNames || []).includes(tableName)) {
            console.log(`✅ DynamoDB table exists: ${tableName}`);
            return;
        }

        console.log(`🛠️  Criando tabela DynamoDB: ${tableName}`);
        const params = {
            TableName: tableName,
            AttributeDefinitions: [{ AttributeName: 'id', AttributeType: 'S' }],
            KeySchema: [{ AttributeName: 'id', KeyType: 'HASH' }],
            BillingMode: 'PAY_PER_REQUEST'
        };
        await dynamodb.createTable(params).promise();
        // esperar até a tabela ficar ativa
        let status = '';
        do {
            await new Promise(r => setTimeout(r, 1000));
            const desc = await dynamodb.describeTable({ TableName: tableName }).promise();
            status = desc.Table.TableStatus;
            process.stdout.write('.');
        } while (status !== 'ACTIVE');
        console.log(`\n✅ Tabela criada: ${tableName}`);
    } catch (err) {
        console.error('Erro ao garantir tabela DynamoDB:', err.message);
        throw err;
    }
}

async function ensureBucketAndUpload() {
    // cria bucket se não existir e faz upload do CSV local
    const s3 = new AWS.S3({ endpoint: AWS_ENDPOINT, s3ForcePathStyle: true });
    try {
        const exists = await bucketExists(S3_BUCKET);
        if (!exists) {
            console.log(`🛠️  Criando bucket S3: ${S3_BUCKET}`);
            await s3.createBucket({ Bucket: S3_BUCKET }).promise();
        } else {
            console.log(`✅ Bucket existe: ${S3_BUCKET}`);
        }

        const csv = fs.readFileSync(LOCAL_CSV, 'utf8');
        await putObject(S3_BUCKET, S3_KEY, csv, 'text/csv');
        console.log(`✅ CSV enviado para s3://${S3_BUCKET}/${S3_KEY}`);
    } catch (err) {
        console.error('Erro ao criar bucket/enviar CSV:', err.message);
        throw err;
    }
}

async function maybeCreateTopic() {
    const topicName = process.env.TOPIC_NAME || 'DataProcessingTopic';
    const sns = new AWS.SNS({ endpoint: AWS_ENDPOINT });
    const topics = await sns.listTopics().promise();
    const found = (topics.Topics || []).find(t => t.TopicArn && t.TopicArn.includes(topicName));
    if (found) {
        console.log(`✅ Topic exists: ${found.TopicArn}`);
        process.env.TOPIC_ARN = found.TopicArn;
        return found.TopicArn;
    }
    console.log(`🛠️  Criando tópico SNS: ${topicName}`);
    const res = await sns.createTopic({ Name: topicName }).promise();
    console.log(`✅ Tópico criado: ${res.TopicArn}`);
    process.env.TOPIC_ARN = res.TopicArn;
    return res.TopicArn;
}

async function run() {
    try {
        console.log('🔎 Garantindo recursos necessários...');
        await ensureDynamoTable();
        await ensureBucketAndUpload();
        await maybeCreateTopic();

        // construir evento S3 simulado
        const event = {
            Records: [
                {
                    eventVersion: '2.1',
                    eventSource: 'aws:s3',
                    s3: {
                        bucket: { name: S3_BUCKET },
                        object: { key: S3_KEY }
                    }
                }
            ]
        };

        console.log('▶️ Invocando handler localmente...');
        const context = { requestId: `local-${Date.now()}` };
        const res = await handler(event, context);
        console.log('--- Handler result ---');
        console.log(JSON.stringify(res, null, 2));

        console.log('🔎 Lista de itens na tabela (scan):');
        const items = await scanTable(100);
        console.log(items);

        console.log('\n✅ Pipeline local executado com sucesso.');
    } catch (err) {
        console.error('❌ Erro na execução local:', err);
        process.exitCode = 1;
    }
}

run();
