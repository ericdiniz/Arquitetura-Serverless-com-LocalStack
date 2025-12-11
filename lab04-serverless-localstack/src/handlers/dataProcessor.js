const { getObject } = require('../utils/s3');
const { putItem } = require('../utils/dynamodb');
const { publishMessage } = require('../utils/sns');
const { v4: uuidv4 } = require('uuid');

exports.handler = async (event, context) => {
    console.log('🚀 Lambda Data Processor iniciada');
    console.log('📋 Evento recebido:', JSON.stringify(event, null, 2));

    try {
        const record = event.Records[0];
        const bucket = record.s3.bucket.name;
        const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));

        console.log(`📁 Processando arquivo: s3://${bucket}/${key}`);

        const csvContent = await getObject(bucket, key);
        console.log(`📄 Conteúdo do arquivo lido (${csvContent.length} bytes)`);

        const lines = csvContent.trim().split('\n');
        const headers = lines[0].split(',').map(h => h.trim());

        console.log(`📊 Headers encontrados: ${headers.join(', ')}`);
        console.log(`📈 Total de linhas (incluindo header): ${lines.length}`);

        let processedCount = 0;
        let errorCount = 0;

        for (let i = 1; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line) continue;

            try {
                const values = line.split(',').map(v => v.trim());
                const rec = {};
                headers.forEach((header, index) => {
                    rec[header] = values[index];
                });

                if (!rec.id || !rec.nome) {
                    console.warn(`⚠️ Linha ${i + 1}: Dados incompletos, pulando...`);
                    errorCount++;
                    continue;
                }

                const enrichedRecord = {
                    id: String(rec.id),
                    timestamp: Date.now(),
                    nome: rec.nome,
                    categoria: rec.categoria || 'Sem categoria',
                    preco: parseFloat(rec.preco) || 0,
                    estoque: parseInt(rec.estoque) || 0,
                    source_file: key,
                    processed_at: new Date().toISOString(),
                    processor_version: '1.0.0'
                };

                await putItem(enrichedRecord);
                processedCount++;
                console.log(`✅ Linha ${i + 1} processada: ${rec.nome}`);

            } catch (error) {
                console.error(`❌ Erro ao processar linha ${i + 1}:`, error.message);
                errorCount++;
            }
        }

        const topicArn = process.env.TOPIC_ARN;
        const notification = {
            event_type: 'DATA_PROCESSING_COMPLETED',
            file: key,
            bucket: bucket,
            records_processed: processedCount,
            records_failed: errorCount,
            total_records: lines.length - 1,
            processed_at: new Date().toISOString(),
            lambda_request_id: context.requestId
        };

        if (topicArn) {
            await publishMessage(
                topicArn,
                notification,
                'Data Processing Completed',
                {
                    event_type: 'processing_completed',
                    file_name: key,
                    records_count: String(processedCount)
                }
            );
        }

        const result = {
            statusCode: 200,
            body: JSON.stringify({
                message: 'Processamento concluído com sucesso',
                file: key,
                records_processed: processedCount,
                records_failed: errorCount,
                total_records: lines.length - 1,
                success_rate: ((processedCount / (lines.length - 1)) * 100).toFixed(2) + '%'
            })
        };

        console.log('✅ Processamento concluído:', result.body);
        return result;

    } catch (error) {
        console.error('❌ Erro fatal no processamento:', error);
        try {
            const topicArn = process.env.TOPIC_ARN;
            if (topicArn) {
                await publishMessage(
                    topicArn,
                    {
                        event_type: 'DATA_PROCESSING_FAILED',
                        error: error.message,
                        stack: error.stack,
                        processed_at: new Date().toISOString()
                    },
                    'Data Processing Failed'
                );
            }
        } catch (notifyError) {
            console.error('❌ Erro ao enviar notificação de falha:', notifyError);
        }

        return {
            statusCode: 500,
            body: JSON.stringify({ message: 'Erro no processamento', error: error.message })
        };
    }
};
