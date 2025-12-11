const { putItem } = require('../utils/dynamodb');
const { publishMessage } = require('../utils/sns');
const { v4: uuidv4 } = require('uuid');

exports.handler = async (event, context) => {
    console.log('🌐 Lambda API Handler iniciada');
    console.log('📋 Evento recebido:', JSON.stringify(event, null, 2));

    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type'
    };

    if (event.httpMethod === 'OPTIONS') {
        return { statusCode: 200, headers, body: JSON.stringify({ message: 'CORS preflight successful' }) };
    }

    try {
        if (event.httpMethod !== 'POST') {
            return { statusCode: 405, headers, body: JSON.stringify({ error: 'Method Not Allowed', message: 'Apenas POST é permitido' }) };
        }

        let body;
        try {
            body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
        } catch (parseError) {
            return { statusCode: 400, headers, body: JSON.stringify({ error: 'Invalid JSON', message: 'Body da requisição não é um JSON válido' }) };
        }

        if (!body.nome) {
            return { statusCode: 400, headers, body: JSON.stringify({ error: 'Validation Error', message: 'Campo "nome" é obrigatório' }) };
        }

        const itemId = body.id || uuidv4();
        const timestamp = Date.now();

        const item = {
            id: itemId,
            timestamp: timestamp,
            nome: body.nome,
            categoria: body.categoria || 'API',
            preco: parseFloat(body.preco) || 0,
            estoque: parseInt(body.estoque) || 0,
            source: 'API',
            created_at: new Date().toISOString(),
            created_by: event.requestContext?.identity?.sourceIp || 'unknown',
            request_id: context.requestId
        };

        console.log('📝 Criando registro:', JSON.stringify(item));

        await putItem(item);

        const topicArn = process.env.TOPIC_ARN;
        if (topicArn) {
            await publishMessage(
                topicArn,
                {
                    event_type: 'RECORD_CREATED_VIA_API',
                    record_id: itemId,
                    record_name: body.nome,
                    created_at: item.created_at
                },
                'New Record Created via API',
                {
                    event_type: 'api_creation',
                    record_id: itemId
                }
            );
        }

        return {
            statusCode: 201,
            headers,
            body: JSON.stringify({ message: 'Registro criado com sucesso', id: itemId, timestamp: timestamp, data: item })
        };

    } catch (error) {
        console.error('❌ Erro ao criar registro:', error);
        return { statusCode: 500, headers, body: JSON.stringify({ error: 'Internal Server Error', message: error.message }) };
    }
};
