const AWS = require('aws-sdk');

// Configuração para LocalStack
const ddbEndpoint = process.env.AWS_ENDPOINT_URL;
const dynamoDbConfig = {
    ...(ddbEndpoint ? { endpoint: ddbEndpoint } : {}),
    region: process.env.AWS_REGION || 'us-east-1',
    ...(ddbEndpoint ? { accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'test', secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'test' } : {})
};

const dynamodb = new AWS.DynamoDB.DocumentClient(dynamoDbConfig);
const tableName = process.env.TABLE_NAME || 'ProcessedData';

async function putItem(item) {
    const params = {
        TableName: tableName,
        Item: item
    };

    try {
        await dynamodb.put(params).promise();
        console.log(`✅ Item inserido no DynamoDB: ${item.id}`);
        return { success: true, item };
    } catch (error) {
        console.error('❌ Erro ao inserir item no DynamoDB:', error);
        throw error;
    }
}

async function getItem(id, timestamp) {
    const params = {
        TableName: tableName,
        Key: { id, timestamp }
    };

    try {
        const result = await dynamodb.get(params).promise();
        return result.Item;
    } catch (error) {
        console.error('❌ Erro ao buscar item:', error);
        throw error;
    }
}

async function queryByIdAsync(id) {
    const params = {
        TableName: tableName,
        KeyConditionExpression: 'id = :id',
        ExpressionAttributeValues: {
            ':id': id
        }
    };

    try {
        const result = await dynamodb.query(params).promise();
        return result.Items;
    } catch (error) {
        console.error('❌ Erro ao fazer query:', error);
        throw error;
    }
}

async function scanTable(limit = 100) {
    const params = {
        TableName: tableName,
        Limit: limit
    };

    try {
        const result = await dynamodb.scan(params).promise();
        console.log(`📊 Scan retornou ${result.Items.length} items`);
        return result.Items;
    } catch (error) {
        console.error('❌ Erro ao fazer scan:', error);
        throw error;
    }
}

async function updateItem(id, timestamp, updates) {
    const updateExpressionParts = [];
    const expressionAttributeNames = {};
    const expressionAttributeValues = {};

    Object.keys(updates).forEach((key, index) => {
        const placeholder = `#attr${index}`;
        const valuePlaceholder = `:val${index}`;
        updateExpressionParts.push(`${placeholder} = ${valuePlaceholder}`);
        expressionAttributeNames[placeholder] = key;
        expressionAttributeValues[valuePlaceholder] = updates[key];
    });

    const params = {
        TableName: tableName,
        Key: { id, timestamp },
        UpdateExpression: `SET ${updateExpressionParts.join(', ')}`,
        ExpressionAttributeNames: expressionAttributeNames,
        ExpressionAttributeValues: expressionAttributeValues,
        ReturnValues: 'ALL_NEW'
    };

    try {
        const result = await dynamodb.update(params).promise();
        console.log(`✏️ Item atualizado: ${id}`);
        return result.Attributes;
    } catch (error) {
        console.error('❌ Erro ao atualizar item:', error);
        throw error;
    }
}

async function deleteItem(id, timestamp) {
    const params = {
        TableName: tableName,
        Key: { id, timestamp }
    };

    try {
        await dynamodb.delete(params).promise();
        console.log(`🗑️ Item deletado: ${id}`);
        return { success: true };
    } catch (error) {
        console.error('❌ Erro ao deletar item:', error);
        throw error;
    }
}

module.exports = {
    putItem,
    getItem,
    queryByIdAsync,
    scanTable,
    updateItem,
    deleteItem
};
