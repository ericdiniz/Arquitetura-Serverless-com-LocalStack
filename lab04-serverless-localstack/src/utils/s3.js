const AWS = require('aws-sdk');

const endpoint = process.env.AWS_ENDPOINT_URL;
const s3Config = {
    ...(endpoint ? { endpoint } : {}),
    region: process.env.AWS_REGION || 'us-east-1',
    ...(endpoint ? { accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'test', secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'test', s3ForcePathStyle: true } : {})
};

const s3 = new AWS.S3(s3Config);

async function getObject(bucket, key) {
    const params = { Bucket: bucket, Key: key };
    try {
        console.log(`📥 Lendo arquivo: s3://${bucket}/${key}`);
        const result = await s3.getObject(params).promise();
        return result.Body.toString('utf-8');
    } catch (error) {
        console.error('❌ Erro ao ler objeto do S3:', error);
        throw error;
    }
}

async function putObject(bucket, key, body, contentType = 'text/plain') {
    const params = { Bucket: bucket, Key: key, Body: body, ContentType: contentType };
    try {
        console.log(`📤 Fazendo upload: s3://${bucket}/${key}`);
        const result = await s3.putObject(params).promise();
        console.log(`✅ Upload concluído: ${key}`);
        return result;
    } catch (error) {
        console.error('❌ Erro ao fazer upload para S3:', error);
        throw error;
    }
}

async function listObjects(bucket, prefix = '') {
    const params = { Bucket: bucket, Prefix: prefix };
    try {
        const result = await s3.listObjectsV2(params).promise();
        console.log(`📋 Encontrados ${result.Contents ? result.Contents.length : 0} objetos`);
        return result.Contents || [];
    } catch (error) {
        console.error('❌ Erro ao listar objetos:', error);
        throw error;
    }
}

async function deleteObject(bucket, key) {
    const params = { Bucket: bucket, Key: key };
    try {
        await s3.deleteObject(params).promise();
        console.log(`🗑️ Objeto deletado: ${key}`);
        return { success: true };
    } catch (error) {
        console.error('❌ Erro ao deletar objeto:', error);
        throw error;
    }
}

async function bucketExists(bucket) {
    try {
        await s3.headBucket({ Bucket: bucket }).promise();
        return true;
    } catch (error) {
        if (error.code === 'NotFound') return false;
        throw error;
    }
}

module.exports = {
    getObject,
    putObject,
    listObjects,
    deleteObject,
    bucketExists
};
