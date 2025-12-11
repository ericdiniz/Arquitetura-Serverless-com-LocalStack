const AWS = require('aws-sdk');

const snsEndpoint = process.env.AWS_ENDPOINT_URL;
const snsConfig = {
    ...(snsEndpoint ? { endpoint: snsEndpoint } : {}),
    region: process.env.AWS_REGION || 'us-east-1',
    ...(snsEndpoint ? { accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'test', secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'test' } : {})
};

const sns = new AWS.SNS(snsConfig);

async function publishMessage(topicArn, message, subject = 'Notification', attributes = {}) {
    const params = {
        TopicArn: topicArn,
        Message: typeof message === 'object' ? JSON.stringify(message) : message,
        Subject: subject,
        MessageAttributes: {}
    };

    Object.keys(attributes).forEach(key => {
        params.MessageAttributes[key] = {
            DataType: 'String',
            StringValue: String(attributes[key])
        };
    });

    try {
        console.log(`📢 Publicando mensagem SNS: ${subject}`);
        const result = await sns.publish(params).promise();
        console.log(`✅ Mensagem publicada. MessageId: ${result.MessageId}`);
        return result;
    } catch (error) {
        console.error('❌ Erro ao publicar mensagem SNS:', error);
        throw error;
    }
}

async function createTopic(topicName) {
    try {
        const result = await sns.createTopic({ Name: topicName }).promise();
        console.log(`✅ Tópico criado: ${result.TopicArn}`);
        return result.TopicArn;
    } catch (error) {
        console.error('❌ Erro ao criar tópico:', error);
        throw error;
    }
}

async function subscribe(topicArn, protocol, endpoint) {
    try {
        const result = await sns.subscribe({ TopicArn: topicArn, Protocol: protocol, Endpoint: endpoint }).promise();
        console.log(`✅ Inscrição criada. SubscriptionArn: ${result.SubscriptionArn}`);
        return result;
    } catch (error) {
        console.error('❌ Erro ao criar inscrição:', error);
        throw error;
    }
}

async function listTopics() {
    try {
        const result = await sns.listTopics().promise();
        return result.Topics;
    } catch (error) {
        console.error('❌ Erro ao listar tópicos:', error);
        throw error;
    }
}

module.exports = {
    publishMessage,
    createTopic,
    subscribe,
    listTopics
};
