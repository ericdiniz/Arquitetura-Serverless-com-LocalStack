# Roteiro 4: Arquitetura Serverless com LocalStack

**Laboratório de Desenvolvimento de Aplicações Móveis e Distribuídas**
**Curso de Engenharia de Software - PUC Minas**
**Professores:** Artur Mol, Cleiton Tavares e Cristiano Neto

---

## Objetivos

- Compreender os fundamentos da arquitetura serverless
- Implementar funções Lambda com Node.js usando Serverless Framework
- Desenvolver pipeline de processamento de dados event-driven
- Integrar serviços AWS (S3, DynamoDB, SNS) usando LocalStack
- Comparar arquiteturas serverless com modelos tradicionais
- Implementar práticas de Infrastructure as Code (IaC)

## Fundamentação Teórica

A arquitetura serverless representa uma evolução significativa no desenvolvimento de aplicações distribuídas. Segundo Roberts (2018), "serverless computing permite que desenvolvedores construam e executem aplicações sem pensar em servidores" <sup>[1]</sup>.

### Características da Arquitetura Serverless

Segundo Baldini et al. (2017), serverless computing possui três características fundamentais <sup>[2]</sup>:

1. **Event-driven Execution**: Funções são executadas em resposta a eventos específicos
2. **Stateless Computation**: Cada invocação é independente, sem estado persistente
3. **Auto-scaling**: Escalamento automático baseado em demanda

**Vantagens:**
- **Custo**: Pagamento apenas por execução real (pay-per-use)
- **Escalabilidade**: Escala automaticamente de zero a milhões de requisições
- **Manutenção**: Infraestrutura gerenciada pelo provedor cloud
- **Desenvolvimento**: Foco em lógica de negócio, não em infraestrutura

**Limitações:**
- **Cold Start**: Latência inicial quando função está "fria"
- **Vendor Lock-in**: Dependência de provedores específicos
- **Tempo de Execução**: Limitações de timeout (AWS Lambda: 15 minutos máximo)
- **Debugging**: Complexidade no rastreamento distribuído

### Function as a Service (FaaS)

O modelo FaaS representa o núcleo do serverless. Na AWS Lambda, funções são executadas em containers efêmeros que:
- Inicializam sob demanda
- Processam um único evento por vez
- São descartados após período de inatividade
- Escalam horizontalmente de forma transparente

### LocalStack para Desenvolvimento Local

LocalStack é um emulador completo de serviços AWS que permite desenvolvimento e testes locais sem custos de cloud. Segundo a documentação oficial, "LocalStack fornece um ambiente de teste fácil de usar para desenvolvimento de aplicações cloud" <sup>[3]</sup>.

**Serviços Suportados:**
- AWS Lambda (execução de funções)
- S3 (armazenamento de objetos)
- DynamoDB (banco NoSQL)
- SNS (notificações pub/sub)
- API Gateway (gerenciamento de APIs)
- CloudFormation (infraestrutura como código)

## Cenário do Laboratório

Sistema de processamento de dados serverless implementando pipeline event-driven:

1. **Upload de arquivo CSV** → S3 Bucket
2. **Trigger automático** → Lambda Function
3. **Processamento** → Parsing e validação de dados
4. **Persistência** → DynamoDB Table
5. **Notificação** → SNS Topic
6. **API REST** → Criação manual de registros

**Arquitetura Implementada:**

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   CSV File  │────▶│  S3 Bucket   │────▶│   Lambda    │
└─────────────┘     └──────────────┘     │  Processor  │
                                          └──────┬──────┘
                                                 │
                    ┌────────────────────────────┼────────────┐
                    │                            │            │
                    ▼                            ▼            ▼
            ┌──────────────┐           ┌──────────────┐  ┌─────────┐
            │  API Gateway │           │   DynamoDB   │  │   SNS   │
            └──────┬───────┘           └──────────────┘  └─────────┘
                   │
                   ▼
            ┌──────────────┐
            │   Lambda     │
            │  API Handler │
            └──────────────┘
```

## Pré-requisitos

- Node.js 18+ e NPM
- Docker Desktop instalado e rodando
- VS Code ou editor similar
- AWS CLI (opcional, para testes avançados)
- Conhecimento básico de JavaScript/Node.js

---

## **PASSO 1: Configuração do Ambiente**

### 1.1 Instalar Ferramentas Globais

```bash
# Instalar Serverless Framework versão 3
# Versão 3 é mais estável para desenvolvimento educacional
npm install -g serverless@3

# Verificar instalação
serverless --version
# Saída esperada: Framework Core: 3.x.x

# Instalar AWS CLI Local (opcional, mas recomendado)
pip install awscli-local
```

### 1.2 Criar Estrutura do Projeto

```bash
# Criar diretório raiz
mkdir lab04-serverless-localstack
cd lab04-serverless-localstack

# Criar estrutura de diretórios
mkdir -p data/input
mkdir -p src/handlers
mkdir -p src/utils
mkdir -p scripts
mkdir -p tests

# Inicializar projeto Node.js
npm init -y
```

### 1.3 Instalar Dependências

```bash
# Dependências principais
npm install aws-sdk uuid csv-parser

# Dependências de desenvolvimento
npm install --save-dev \
  serverless@3 \
  serverless-localstack \
  serverless-offline \
  @types/node \
  @types/aws-lambda \
  eslint

# Configurar TypeScript (opcional)
npm install --save-dev typescript @types/node
```

### 1.4 Estrutura Final de Diretórios

```
lab04-serverless-localstack/
├── package.json
├── serverless.yml              # Configuração Infrastructure as Code
├── docker-compose.yml          # LocalStack container
├── .env                        # Variáveis de ambiente
├── .gitignore
├── tsconfig.json               # Configuração TypeScript (opcional)
├── data/
│   └── input/
│       └── produtos.csv        # Dados de teste
├── src/
│   ├── handlers/
│   │   ├── dataProcessor.js    # Lambda: Processar CSV
│   │   └── createRecord.js     # Lambda: API REST
│   └── utils/
│       ├── dynamodb.js         # Helper DynamoDB
│       ├── s3.js               # Helper S3
│       └── sns.js              # Helper SNS
├── scripts/
│   ├── test-pipeline.js        # Script de teste automatizado
│   └── setup.js                # Setup inicial
└── tests/
    ├── test-event.json         # Evento S3 simulado
    └── test-api.json           # Requisição API simulada
```

---

## **PASSO 2: Configuração do LocalStack**

### 2.1 Docker Compose Configuration (`docker-compose.yml`)

```yaml
version: '3.8'

services:
  localstack:
    container_name: localstack-serverless-lab
    image: localstack/localstack:latest
    ports:
      - "4566:4566"            # Gateway principal LocalStack
      - "4510-4559:4510-4559"  # Range para serviços externos

    environment:
      # Serviços AWS a serem emulados
      - SERVICES=lambda,dynamodb,s3,sns,iam,logs,cloudwatch,cloudformation,apigateway

      # Configurações de debug
      - DEBUG=1
      - LS_LOG=INFO

      # Configurações Lambda
      - LAMBDA_EXECUTOR=docker
      - LAMBDA_REMOTE_DOCKER=0
      - LAMBDA_DOCKER_NETWORK=localstack-network

      # Persistência desabilitada para desenvolvimento
      # Em produção, considere habilitar para manter dados
      - PERSISTENCE=0

      # Configurações adicionais
      - DOCKER_HOST=unix:///var/run/docker.sock

    volumes:
      # Volume para persistência (se habilitado)
      - localstack-data:/var/lib/localstack
      # Socket do Docker para execução de Lambda
      - "/var/run/docker.sock:/var/run/docker.sock"

    networks:
      - localstack-network

    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4566/_localstack/health"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 30s

volumes:
  localstack-data:
    driver: local

networks:
  localstack-network:
    driver: bridge
```

**Explicação dos Componentes:**

- **SERVICES**: Lista de serviços AWS emulados localmente
- **LAMBDA_EXECUTOR=docker**: Lambda executa em containers Docker isolados
- **PERSISTENCE=0**: Dados não são persistidos entre reinicializações (ideal para desenvolvimento)
- **healthcheck**: Verifica se LocalStack está pronto para receber requisições

### 2.2 Iniciar LocalStack

```bash
# Iniciar containers em background
docker-compose up -d

# Verificar status
docker-compose ps

# Aguardar LocalStack ficar pronto
echo "Aguardando LocalStack inicializar..."
sleep 30

# Verificar saúde do serviço
curl http://localhost:4566/_localstack/health
```

### 2.3 Verificar Serviços Disponíveis

```bash
# Listar serviços rodando
curl http://localhost:4566/_localstack/health | json_pp

# Saída esperada:
# {
#   "services": {
#     "lambda": "running",
#     "dynamodb": "running",
#     "s3": "running",
#     "sns": "running",
#     ...
#   }
# }
```

---

## **PASSO 3: Configuração do Serverless Framework**

### 3.1 Serverless Configuration (`serverless.yml`)

```yaml
service: data-processing-service

# Versão do Serverless Framework
frameworkVersion: '^3.38.0'

provider:
  name: aws
  runtime: nodejs18.x
  stage: ${opt:stage, 'local'}
  region: us-east-1

  # Variáveis de ambiente globais para todas as funções
  environment:
    TABLE_NAME: ${self:custom.tableName}
    BUCKET_NAME: ${self:custom.bucketName}
    TOPIC_ARN:
      Ref: DataProcessingTopic
    AWS_ENDPOINT_URL: ${self:custom.localstack.endpoint}

  # Políticas IAM para as funções Lambda
  iam:
    role:
      statements:
        # Permissões DynamoDB
        - Effect: Allow
          Action:
            - dynamodb:PutItem
            - dynamodb:GetItem
            - dynamodb:Query
            - dynamodb:Scan
            - dynamodb:UpdateItem
            - dynamodb:DeleteItem
          Resource:
            Fn::GetAtt:
              - ProcessedDataTable
              - Arn

        # Permissões S3
        - Effect: Allow
          Action:
            - s3:GetObject
            - s3:ListBucket
          Resource:
            - Fn::GetAtt:
                - DataProcessingBucket
                - Arn
            - Fn::Join:
                - ''
                - - Fn::GetAtt:
                      - DataProcessingBucket
                      - Arn
                  - '/*'

        # Permissões SNS
        - Effect: Allow
          Action:
            - sns:Publish
          Resource:
            Ref: DataProcessingTopic

        # Permissões CloudWatch Logs
        - Effect: Allow
          Action:
            - logs:CreateLogGroup
            - logs:CreateLogStream
            - logs:PutLogEvents
          Resource: '*'

# Configurações customizadas
custom:
  # Nomes dos recursos
  tableName: ProcessedData
  bucketName: data-processing-bucket
  topicName: data-processing-notifications

  # Configuração LocalStack
  localstack:
    stages:
      - local
    host: http://localhost
    edgePort: 4566
    autostart: false
    endpoint: http://localhost:4566
    lambda:
      mountCode: false
    docker:
      sudo: false

# Plugins necessários
plugins:
  - serverless-localstack
  - serverless-offline

# Definição das funções Lambda
functions:
  # Função 1: Processar arquivos CSV do S3
  dataProcessor:
    handler: src/handlers/dataProcessor.handler
    name: DataProcessorFunction
    description: Processa arquivos CSV do S3 e salva no DynamoDB
    timeout: 60
    memorySize: 256
    environment:
      # Override de variáveis específicas para LocalStack
      AWS_ACCESS_KEY_ID: test
      AWS_SECRET_ACCESS_KEY: test
    events:
      # Trigger: Evento S3 quando arquivo é criado
      - s3:
          bucket:
            Ref: DataProcessingBucket
          event: s3:ObjectCreated:*
          rules:
            - prefix: input/
            - suffix: .csv
          existing: true

  # Função 2: API REST para criar registros
  createRecord:
    handler: src/handlers/createRecord.handler
    name: CreateRecordFunction
    description: API REST para criar registros no DynamoDB
    timeout: 10
    memorySize: 128
    environment:
      AWS_ACCESS_KEY_ID: test
      AWS_SECRET_ACCESS_KEY: test
    events:
      # Trigger: HTTP POST /records
      - http:
          path: records
          method: post
          cors: true

# Recursos AWS (Infrastructure as Code usando CloudFormation)
resources:
  Resources:
    # S3 Bucket para armazenar arquivos CSV
    DataProcessingBucket:
      Type: AWS::S3::Bucket
      Properties:
        BucketName: ${self:custom.bucketName}
        PublicAccessBlockConfiguration:
          BlockPublicAcls: true
          BlockPublicPolicy: true
          IgnorePublicAcls: true
          RestrictPublicBuckets: true

    # Permissão para S3 invocar Lambda
    DataProcessorLambdaPermissionS3:
      Type: AWS::Lambda::Permission
      Properties:
        FunctionName:
          Fn::GetAtt:
            - DataProcessorLambdaFunction
            - Arn
        Action: lambda:InvokeFunction
        Principal: s3.amazonaws.com
        SourceArn:
          Fn::GetAtt:
            - DataProcessingBucket
            - Arn

    # Tabela DynamoDB para armazenar dados processados
    ProcessedDataTable:
      Type: AWS::DynamoDB::Table
      Properties:
        TableName: ${self:custom.tableName}
        BillingMode: PAY_PER_REQUEST
        AttributeDefinitions:
          - AttributeName: id
            AttributeType: S
          - AttributeName: timestamp
            AttributeType: N
        KeySchema:
          - AttributeName: id
            KeyType: HASH
          - AttributeName: timestamp
            KeyType: RANGE
        StreamSpecification:
          StreamViewType: NEW_AND_OLD_IMAGES
        Tags:
          - Key: Environment
            Value: ${self:provider.stage}
          - Key: Service
            Value: ${self:service}

    # Tópico SNS para notificações
    DataProcessingTopic:
      Type: AWS::SNS::Topic
      Properties:
        TopicName: ${self:custom.topicName}
        DisplayName: Data Processing Notifications
        Tags:
          - Key: Environment
            Value: ${self:provider.stage}

  # Outputs (valores exportados para referência)
  Outputs:
    BucketName:
      Description: Nome do bucket S3
      Value:
        Ref: DataProcessingBucket
      Export:
        Name: ${self:service}-${self:provider.stage}-BucketName

    TableName:
      Description: Nome da tabela DynamoDB
      Value:
        Ref: ProcessedDataTable
      Export:
        Name: ${self:service}-${self:provider.stage}-TableName

    TopicArn:
      Description: ARN do tópico SNS
      Value:
        Ref: DataProcessingTopic
      Export:
        Name: ${self:service}-${self:provider.stage}-TopicArn

    FunctionArn:
      Description: ARN da função Lambda principal
      Value:
        Fn::GetAtt:
          - DataProcessorLambdaFunction
          - Arn
      Export:
        Name: ${self:service}-${self:provider.stage}-FunctionArn

    ApiEndpoint:
      Description: URL do API Gateway
      Value:
        Fn::Sub: http://localhost:4566/restapis/${ApiGatewayRestApi}/local/_user_request_
```

**Conceitos Importantes:**

- **Infrastructure as Code (IaC)**: Toda infraestrutura definida em código versionável
- **Resources**: Recursos AWS definidos usando CloudFormation syntax
- **Outputs**: Valores exportados que podem ser referenciados por outros stacks
- **IAM Policies**: Princípio de menor privilégio - apenas permissões necessárias

---

## **PASSO 4: Implementação dos Helpers**

### 4.1 DynamoDB Helper (`src/utils/dynamodb.js`)

```javascript
const AWS = require('aws-sdk');

/**
 * Helper para operações com DynamoDB
 *
 * Abstrai a complexidade das operações com DynamoDB,
 * facilitando put, get, query e scan operations
 */

// Configuração para LocalStack
const dynamoDbConfig = {
  endpoint: process.env.AWS_ENDPOINT_URL || 'http://localhost:4566',
  region: process.env.AWS_REGION || 'us-east-1',
  accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'test',
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'test'
};

const dynamodb = new AWS.DynamoDB.DocumentClient(dynamoDbConfig);
const tableName = process.env.TABLE_NAME || 'ProcessedData';

/**
 * Inserir item no DynamoDB
 * @param {Object} item - Item a ser inserido
 * @returns {Promise<Object>} Resultado da operação
 */
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

/**
 * Buscar item por chave primária
 * @param {string} id - Partition key
 * @param {number} timestamp - Sort key
 * @returns {Promise<Object>} Item encontrado
 */
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

/**
 * Query items por partition key
 * @param {string} id - Partition key
 * @returns {Promise<Array>} Lista de items
 */
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

/**
 * Scan completo da tabela (use com cuidado em produção!)
 * @param {number} limit - Limite de items a retornar
 * @returns {Promise<Array>} Lista de todos os items
 */
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

/**
 * Atualizar item existente
 * @param {string} id - Partition key
 * @param {number} timestamp - Sort key
 * @param {Object} updates - Campos a atualizar
 * @returns {Promise<Object>} Item atualizado
 */
async function updateItem(id, timestamp, updates) {
  // Construir expressão de update dinamicamente
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

/**
 * Deletar item
 * @param {string} id - Partition key
 * @param {number} timestamp - Sort key
 * @returns {Promise<Object>} Resultado da operação
 */
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
```

### 4.2 S3 Helper (`src/utils/s3.js`)

```javascript
const AWS = require('aws-sdk');

/**
 * Helper para operações com S3
 *
 * Facilita operações de leitura e escrita em buckets S3
 */

const s3Config = {
  endpoint: process.env.AWS_ENDPOINT_URL || 'http://localhost:4566',
  region: process.env.AWS_REGION || 'us-east-1',
  accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'test',
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'test',
  s3ForcePathStyle: true // Necessário para LocalStack
};

const s3 = new AWS.S3(s3Config);

/**
 * Ler conteúdo de arquivo do S3
 * @param {string} bucket - Nome do bucket
 * @param {string} key - Chave do objeto
 * @returns {Promise<string>} Conteúdo do arquivo
 */
async function getObject(bucket, key) {
  const params = {
    Bucket: bucket,
    Key: key
  };

  try {
    console.log(`📥 Lendo arquivo: s3://${bucket}/${key}`);
    const result = await s3.getObject(params).promise();
    return result.Body.toString('utf-8');
  } catch (error) {
    console.error('❌ Erro ao ler objeto do S3:', error);
    throw error;
  }
}

/**
 * Upload de arquivo para S3
 * @param {string} bucket - Nome do bucket
 * @param {string} key - Chave do objeto
 * @param {string|Buffer} body - Conteúdo do arquivo
 * @param {string} contentType - MIME type
 * @returns {Promise<Object>} Resultado do upload
 */
async function putObject(bucket, key, body, contentType = 'text/plain') {
  const params = {
    Bucket: bucket,
    Key: key,
    Body: body,
    ContentType: contentType
  };

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

/**
 * Listar objetos em um bucket
 * @param {string} bucket - Nome do bucket
 * @param {string} prefix - Prefixo para filtrar objetos
 * @returns {Promise<Array>} Lista de objetos
 */
async function listObjects(bucket, prefix = '') {
  const params = {
    Bucket: bucket,
    Prefix: prefix
  };

  try {
    const result = await s3.listObjectsV2(params).promise();
    console.log(`📋 Encontrados ${result.Contents.length} objetos`);
    return result.Contents;
  } catch (error) {
    console.error('❌ Erro ao listar objetos:', error);
    throw error;
  }
}

/**
 * Deletar objeto do S3
 * @param {string} bucket - Nome do bucket
 * @param {string} key - Chave do objeto
 * @returns {Promise<Object>} Resultado da operação
 */
async function deleteObject(bucket, key) {
  const params = {
    Bucket: bucket,
    Key: key
  };

  try {
    await s3.deleteObject(params).promise();
    console.log(`🗑️ Objeto deletado: ${key}`);
    return { success: true };
  } catch (error) {
    console.error('❌ Erro ao deletar objeto:', error);
    throw error;
  }
}

/**
 * Verificar se bucket existe
 * @param {string} bucket - Nome do bucket
 * @returns {Promise<boolean>} True se existe
 */
async function bucketExists(bucket) {
  try {
    await s3.headBucket({ Bucket: bucket }).promise();
    return true;
  } catch (error) {
    if (error.code === 'NotFound') {
      return false;
    }
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
```

### 4.3 SNS Helper (`src/utils/sns.js`)

```javascript
const AWS = require('aws-sdk');

/**
 * Helper para notificações SNS
 *
 * Simplifica publicação de mensagens em tópicos SNS
 */

const snsConfig = {
  endpoint: process.env.AWS_ENDPOINT_URL || 'http://localhost:4566',
  region: process.env.AWS_REGION || 'us-east-1',
  accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'test',
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'test'
};

const sns = new AWS.SNS(snsConfig);

/**
 * Publicar mensagem em tópico SNS
 * @param {string} topicArn - ARN do tópico
 * @param {string} message - Mensagem a publicar
 * @param {string} subject - Assunto da mensagem
 * @param {Object} attributes - Atributos adicionais
 * @returns {Promise<Object>} Resultado da publicação
 */
async function publishMessage(topicArn, message, subject = 'Notification', attributes = {}) {
  const params = {
    TopicArn: topicArn,
    Message: typeof message === 'object' ? JSON.stringify(message) : message,
    Subject: subject,
    MessageAttributes: {}
  };

  // Adicionar atributos customizados
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

/**
 * Criar tópico SNS
 * @param {string} topicName - Nome do tópico
 * @returns {Promise<string>} ARN do tópico criado
 */
async function createTopic(topicName) {
  const params = {
    Name: topicName
  };

  try {
    const result = await sns.createTopic(params).promise();
    console.log(`✅ Tópico criado: ${result.TopicArn}`);
    return result.TopicArn;
  } catch (error) {
    console.error('❌ Erro ao criar tópico:', error);
    throw error;
  }
}

/**
 * Inscrever endpoint em tópico
 * @param {string} topicArn - ARN do tópico
 * @param {string} protocol - Protocolo (email, sms, http, etc)
 * @param {string} endpoint - Endpoint a ser inscrito
 * @returns {Promise<Object>} Resultado da inscrição
 */
async function subscribe(topicArn, protocol, endpoint) {
  const params = {
    TopicArn: topicArn,
    Protocol: protocol,
    Endpoint: endpoint
  };

  try {
    const result = await sns.subscribe(params).promise();
    console.log(`✅ Inscrição criada. SubscriptionArn: ${result.SubscriptionArn}`);
    return result;
  } catch (error) {
    console.error('❌ Erro ao criar inscrição:', error);
    throw error;
  }
}

/**
 * Listar tópicos SNS
 * @returns {Promise<Array>} Lista de tópicos
 */
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
```

---

## **PASSO 5: Implementação das Funções Lambda**

### 5.1 Lambda Data Processor (`src/handlers/dataProcessor.js`)

```javascript
const { getObject } = require('../utils/s3');
const { putItem } = require('../utils/dynamodb');
const { publishMessage } = require('../utils/sns');
const { v4: uuidv4 } = require('uuid');

/**
 * Lambda Handler: Data Processor
 *
 * Função principal que processa arquivos CSV do S3:
 * 1. Recebe evento de criação de arquivo no S3
 * 2. Lê e parseia o arquivo CSV
 * 3. Valida e transforma os dados
 * 4. Salva cada registro no DynamoDB
 * 5. Publica notificação SNS ao concluir
 *
 * @param {Object} event - Evento S3 trigger
 * @param {Object} context - Contexto da execução Lambda
 * @returns {Promise<Object>} Resultado do processamento
 */
exports.handler = async (event, context) => {
  console.log('🚀 Lambda Data Processor iniciada');
  console.log('📋 Evento recebido:', JSON.stringify(event, null, 2));

  try {
    // Extrair informações do evento S3
    const record = event.Records[0];
    const bucket = record.s3.bucket.name;
    const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));

    console.log(`📁 Processando arquivo: s3://${bucket}/${key}`);

    // 1. Ler arquivo CSV do S3
    const csvContent = await getObject(bucket, key);
    console.log(`📄 Conteúdo do arquivo lido (${csvContent.length} bytes)`);

    // 2. Parsear CSV manualmente (sem dependência externa de csv-parser)
    const lines = csvContent.trim().split('\n');
    const headers = lines[0].split(',').map(h => h.trim());

    console.log(`📊 Headers encontrados: ${headers.join(', ')}`);
    console.log(`📈 Total de linhas (incluindo header): ${lines.length}`);

    const records = [];
    let processedCount = 0;
    let errorCount = 0;

    // 3. Processar cada linha do CSV
    for (let i = 1; i < lines.length; i++) {
      const line = lines[i].trim();

      // Pular linhas vazias
      if (!line) continue;

      try {
        const values = line.split(',').map(v => v.trim());

        // Criar objeto a partir dos headers e values
        const record = {};
        headers.forEach((header, index) => {
          record[header] = values[index];
        });

        // Validar registro
        if (!record.id || !record.nome) {
          console.warn(`⚠️ Linha ${i + 1}: Dados incompletos, pulando...`);
          errorCount++;
          continue;
        }

        // 4. Enriquecer dados
        const enrichedRecord = {
          id: String(record.id),
          timestamp: Date.now(),
          nome: record.nome,
          categoria: record.categoria || 'Sem categoria',
          preco: parseFloat(record.preco) || 0,
          estoque: parseInt(record.estoque) || 0,
          source_file: key,
          processed_at: new Date().toISOString(),
          processor_version: '1.0.0'
        };

        // 5. Salvar no DynamoDB
        await putItem(enrichedRecord);
        records.push(enrichedRecord);
        processedCount++;

        console.log(`✅ Linha ${i + 1} processada: ${record.nome}`);

      } catch (error) {
        console.error(`❌ Erro ao processar linha ${i + 1}:`, error.message);
        errorCount++;
      }
    }

    // 6. Publicar notificação SNS
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

    // 7. Retornar resultado
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

    // Publicar notificação de erro
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
      body: JSON.stringify({
        message: 'Erro no processamento',
        error: error.message
      })
    };
  }
};
```

### 5.2 Lambda API Handler (`src/handlers/createRecord.js`)

```javascript
const { putItem } = require('../utils/dynamodb');
const { publishMessage } = require('../utils/sns');
const { v4: uuidv4 } = require('uuid');

/**
 * Lambda Handler: Create Record API
 *
 * Endpoint REST para criar registros diretamente no DynamoDB
 * via requisição HTTP POST
 *
 * Endpoint: POST /records
 * Body: JSON com dados do registro
 *
 * @param {Object} event - Evento API Gateway
 * @param {Object} context - Contexto da execução Lambda
 * @returns {Promise<Object>} Resposta HTTP
 */
exports.handler = async (event, context) => {
  console.log('🌐 Lambda API Handler iniciada');
  console.log('📋 Evento recebido:', JSON.stringify(event, null, 2));

  // Headers CORS para permitir requisições cross-origin
  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type'
  };

  // Tratar preflight request (OPTIONS)
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({ message: 'CORS preflight successful' })
    };
  }

  try {
    // 1. Validar método HTTP
    if (event.httpMethod !== 'POST') {
      return {
        statusCode: 405,
        headers,
        body: JSON.stringify({
          error: 'Method Not Allowed',
          message: 'Apenas POST é permitido'
        })
      };
    }

    // 2. Parsear body da requisição
    let body;
    try {
      body = typeof event.body === 'string'
        ? JSON.parse(event.body)
        : event.body;
    } catch (parseError) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({
          error: 'Invalid JSON',
          message: 'Body da requisição não é um JSON válido'
        })
      };
    }

    // 3. Validar campos obrigatórios
    if (!body.nome) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({
          error: 'Validation Error',
          message: 'Campo "nome" é obrigatório'
        })
      };
    }

    // 4. Criar registro enriquecido
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

    // 5. Salvar no DynamoDB
    await putItem(item);

    // 6. Publicar notificação SNS
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

    // 7. Retornar resposta de sucesso
    return {
      statusCode: 201,
      headers,
      body: JSON.stringify({
        message: 'Registro criado com sucesso',
        id: itemId,
        timestamp: timestamp,
        data: item
      })
    };

  } catch (error) {
    console.error('❌ Erro ao criar registro:', error);

    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({
        error: 'Internal Server Error',
        message: error.message
      })
    };
  }
};
```

---

## **PASSO 6: Dados de Teste e Scripts**

### 6.1 Arquivo CSV de Teste (`data/input/produtos.csv`)

```csv
id,nome,categoria,preco,estoque
1,Notebook Dell XPS 15,Informática,8500.00,15
2,Mouse Logitech MX Master,Periféricos,450.00,50
3,Teclado Mecânico Keychron,Periféricos,890.00,30
4,Monitor LG UltraWide 34",Monitores,2800.00,20
5,Webcam Logitech C920,Acessórios,650.00,25
6,Headset HyperX Cloud,Áudio,780.00,40
7,SSD Samsung 1TB,Armazenamento,580.00,60
8,HD Externo Seagate 2TB,Armazenamento,420.00,35
9,Cadeira Gamer ThunderX3,Móveis,1200.00,12
10,Mesa Gamer Pro,Móveis,1800.00,8
```

### 6.2 Evento S3 Simulado (`tests/test-event.json`)

```json
{
  "Records": [
    {
      "eventVersion": "2.1",
      "eventSource": "aws:s3",
      "awsRegion": "us-east-1",
      "eventTime": "2024-01-15T12:00:00.000Z",
      "eventName": "ObjectCreated:Put",
      "s3": {
        "s3SchemaVersion": "1.0",
        "configurationId": "data-processor-trigger",
        "bucket": {
          "name": "data-processing-bucket",
          "arn": "arn:aws:s3:::data-processing-bucket"
        },
        "object": {
          "key": "input/produtos.csv",
          "size": 1024,
          "eTag": "d41d8cd98f00b204e9800998ecf8427e"
        }
      }
    }
  ]
}
```

### 6.3 Requisição API Simulada (`tests/test-api.json`)

```json
{
  "httpMethod": "POST",
  "path": "/records",
  "headers": {
    "Content-Type": "application/json"
  },
  "body": "{\"nome\":\"Produto de Teste API\",\"categoria\":\"Testes\",\"preco\":99.99,\"estoque\":100}",
  "requestContext": {
    "identity": {
      "sourceIp": "127.0.0.1"
    }
  }
}
```

### 6.4 Script de Teste Automatizado (`scripts/test-pipeline.js`)

```javascript
#!/usr/bin/env node

const AWS = require('aws-sdk');
const fs = require('fs');
const path = require('path');

/**
 * Script de Teste Automatizado do Pipeline
 *
 * Testa todo o fluxo serverless:
 * 1. Upload de CSV para S3
 * 2. Trigger automático da Lambda
 * 3. Verificação de dados no DynamoDB
 * 4. Teste de API REST
 */

// Configuração AWS LocalStack
const awsConfig = {
  endpoint: 'http://localhost:4566',
  region: 'us-east-1',
  accessKeyId: 'test',
  secretAccessKey: 'test',
  s3ForcePathStyle: true
};

const s3 = new AWS.S3(awsConfig);
const dynamodb = new AWS.DynamoDB.DocumentClient(awsConfig);
const lambda = new AWS.Lambda(awsConfig);

const BUCKET_NAME = 'data-processing-bucket';
const TABLE_NAME = 'ProcessedData';
const TEST_FILE = path.join(__dirname, '../data/input/produtos.csv');

// Cores para output no terminal
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m'
};

function log(message, color = colors.reset) {
  console.log(`${color}${message}${colors.reset}`);
}

function success(message) {
  log(`✅ ${message}`, colors.green);
}

function error(message) {
  log(`❌ ${message}`, colors.red);
}

function info(message) {
  log(`ℹ️  ${message}`, colors.blue);
}

function warning(message) {
  log(`⚠️  ${message}`, colors.yellow);
}

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Verificar se LocalStack está rodando
 */
async function checkLocalStack() {
  info('Verificando se LocalStack está ativo...');
  try {
    await s3.listBuckets().promise();
    success('LocalStack está ativo e respondendo');
    return true;
  } catch (err) {
    error('LocalStack não está respondendo. Verifique se está rodando com: docker-compose ps');
    return false;
  }
}

/**
 * Verificar se bucket existe
 */
async function checkBucket() {
  info(`Verificando bucket ${BUCKET_NAME}...`);
  try {
    await s3.headBucket({ Bucket: BUCKET_NAME }).promise();
    success(`Bucket ${BUCKET_NAME} existe`);
    return true;
  } catch (err) {
    error(`Bucket ${BUCKET_NAME} não existe. Execute: serverless deploy --stage local`);
    return false;
  }
}

/**
 * Verificar se tabela DynamoDB existe
 */
async function checkTable() {
  info(`Verificando tabela ${TABLE_NAME}...`);
  try {
    const params = {
      TableName: TABLE_NAME,
      Limit: 1
    };
    await dynamodb.scan(params).promise();
    success(`Tabela ${TABLE_NAME} existe e está acessível`);
    return true;
  } catch (err) {
    error(`Tabela ${TABLE_NAME} não está acessível: ${err.message}`);
    return false;
  }
}

/**
 * Upload de arquivo CSV para S3
 */
async function uploadTestFile() {
  info('Fazendo upload do arquivo de teste...');

  if (!fs.existsSync(TEST_FILE)) {
    error(`Arquivo de teste não encontrado: ${TEST_FILE}`);
    return false;
  }

  const fileContent = fs.readFileSync(TEST_FILE);
  const params = {
    Bucket: BUCKET_NAME,
    Key: 'input/produtos.csv',
    Body: fileContent,
    ContentType: 'text/csv'
  };

  try {
    await s3.putObject(params).promise();
    success('Arquivo uploaded com sucesso para s3://data-processing-bucket/input/produtos.csv');
    return true;
  } catch (err) {
    error(`Erro no upload: ${err.message}`);
    return false;
  }
}

/**
 * Aguardar Lambda processar (polling)
 */
async function waitForProcessing(maxAttempts = 10, interval = 2000) {
  info('Aguardando Lambda processar dados...');

  for (let i = 0; i < maxAttempts; i++) {
    try {
      const params = {
        TableName: TABLE_NAME,
        Limit: 1
      };

      const result = await dynamodb.scan(params).promise();

      if (result.Items && result.Items.length > 0) {
        success(`Dados processados encontrados no DynamoDB!`);
        return true;
      }

      warning(`Tentativa ${i + 1}/${maxAttempts}: Aguardando processamento...`);
      await sleep(interval);
    } catch (err) {
      warning(`Erro ao verificar DynamoDB: ${err.message}`);
    }
  }

  error('Timeout: Lambda não processou dados no tempo esperado');
  return false;
}

/**
 * Verificar dados no DynamoDB
 */
async function verifyData() {
  info('Verificando dados processados no DynamoDB...');

  try {
    const params = {
      TableName: TABLE_NAME,
      Limit: 100
    };

    const result = await dynamodb.scan(params).promise();
    const items = result.Items || [];

    success(`Total de registros no DynamoDB: ${items.length}`);

    if (items.length > 0) {
      info('\nExemplo de registro processado:');
      console.log(JSON.stringify(items[0], null, 2));

      // Validar campos esperados
      const requiredFields = ['id', 'timestamp', 'nome', 'preco', 'source_file'];
      const firstItem = items[0];
      const missingFields = requiredFields.filter(field => !(field in firstItem));

      if (missingFields.length === 0) {
        success('Todos os campos esperados estão presentes');
      } else {
        warning(`Campos faltando: ${missingFields.join(', ')}`);
      }

      return true;
    } else {
      warning('Nenhum registro encontrado no DynamoDB');
      return false;
    }
  } catch (err) {
    error(`Erro ao verificar dados: ${err.message}`);
    return false;
  }
}

/**
 * Testar API REST
 */
async function testApi() {
  info('Testando API REST para criar registro...');

  try {
    const params = {
      FunctionName: 'CreateRecordFunction',
      InvocationType: 'RequestResponse',
      Payload: JSON.stringify({
        httpMethod: 'POST',
        body: JSON.stringify({
          nome: 'Produto Teste API',
          categoria: 'Teste Automatizado',
          preco: 199.99,
          estoque: 50
        }),
        requestContext: {
          identity: {
            sourceIp: '127.0.0.1'
          }
        }
      })
    };

    const result = await lambda.invoke(params).promise();
    const response = JSON.parse(result.Payload);

    if (response.statusCode === 201) {
      success('API REST funcionando corretamente');
      const body = JSON.parse(response.body);
      info(`Registro criado com ID: ${body.id}`);
      return true;
    } else {
      error(`API retornou status ${response.statusCode}`);
      console.log(response.body);
      return false;
    }
  } catch (err) {
    error(`Erro ao testar API: ${err.message}`);
    return false;
  }
}

/**
 * Limpar dados de teste
 */
async function cleanup() {
  info('Limpando dados de teste (opcional)...');
  warning('Para limpar completamente, execute: serverless remove --stage local');
}

/**
 * Main
 */
async function main() {
  console.log('\n' + '='.repeat(60));
  log('🧪 TESTE AUTOMATIZADO DO PIPELINE SERVERLESS', colors.magenta);
  console.log('='.repeat(60) + '\n');

  let allPassed = true;

  // Passo 1: Verificar LocalStack
  if (!await checkLocalStack()) {
    error('\n❌ Falha crítica: LocalStack não está disponível');
    process.exit(1);
  }

  // Passo 2: Verificar recursos
  if (!await checkBucket() || !await checkTable()) {
    error('\n❌ Recursos não estão disponíveis. Execute deploy primeiro.');
    process.exit(1);
  }

  // Passo 3: Upload de arquivo
  if (!await uploadTestFile()) {
    allPassed = false;
  }

  // Passo 4: Aguardar processamento
  await sleep(3000); // Aguardar um pouco antes de começar polling
  if (!await waitForProcessing()) {
    allPassed = false;
  }

  // Passo 5: Verificar dados
  if (!await verifyData()) {
    allPassed = false;
  }

  // Passo 6: Testar API
  await sleep(2000);
  if (!await testApi()) {
    allPassed = false;
  }

  // Passo 7: Cleanup
  await cleanup();

  // Resultado final
  console.log('\n' + '='.repeat(60));
  if (allPassed) {
    log('🎉 TODOS OS TESTES PASSARAM COM SUCESSO!', colors.green);
  } else {
    log('⚠️  ALGUNS TESTES FALHARAM', colors.yellow);
  }
  console.log('='.repeat(60) + '\n');
}

// Executar
main().catch(err => {
  error(`Erro fatal: ${err.message}`);
  console.error(err);
  process.exit(1);
});
```

### 6.5 Script de Setup Inicial (`scripts/setup.js`)

```javascript
#!/usr/bin/env node

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

/**
 * Script de Setup Inicial do Projeto
 *
 * Automatiza configuração inicial:
 * 1. Verifica dependências instaladas
 * 2. Inicia LocalStack
 * 3. Faz deploy do Serverless
 * 4. Executa teste básico
 */

function execute(command, options = {}) {
  console.log(`\n🔧 Executando: ${command}`);
  try {
    execSync(command, {
      stdio: 'inherit',
      ...options
    });
    console.log('✅ Comando executado com sucesso\n');
    return true;
  } catch (error) {
    console.error(`❌ Erro ao executar comando: ${error.message}\n`);
    return false;
  }
}

function checkFile(filePath) {
  return fs.existsSync(filePath);
}

console.log('🚀 Setup do Projeto Serverless LocalStack\n');
console.log('='.repeat(60) + '\n');

// 1. Verificar se estamos no diretório correto
if (!checkFile('package.json')) {
  console.error('❌ Erro: package.json não encontrado. Execute este script do diretório raiz do projeto.');
  process.exit(1);
}

// 2. Instalar dependências Node.js
console.log('📦 Passo 1: Instalando dependências Node.js...');
if (!execute('npm install')) {
  console.error('❌ Falha ao instalar dependências');
  process.exit(1);
}

// 3. Verificar se Docker está rodando
console.log('🐳 Passo 2: Verificando Docker...');
if (!execute('docker ps', { stdio: 'pipe' })) {
  console.error('❌ Docker não está rodando. Inicie o Docker Desktop e tente novamente.');
  process.exit(1);
}

// 4. Iniciar LocalStack
console.log('🌐 Passo 3: Iniciando LocalStack...');
if (!execute('docker-compose up -d')) {
  console.error('❌ Falha ao iniciar LocalStack');
  process.exit(1);
}

// 5. Aguardar LocalStack ficar pronto
console.log('⏳ Aguardando LocalStack inicializar (30 segundos)...');
setTimeout(() => {}, 30000); // Aguardar sincronicamente
execSync('sleep 30', { stdio: 'inherit' });

// 6. Deploy do Serverless
console.log('☁️  Passo 4: Fazendo deploy do Serverless Framework...');
if (!execute('serverless deploy --stage local --verbose')) {
  console.error('❌ Falha no deploy');
  process.exit(1);
}

// 7. Executar teste básico
console.log('🧪 Passo 5: Executando teste básico...');
if (checkFile('scripts/test-pipeline.js')) {
  execute('node scripts/test-pipeline.js');
}

console.log('\n' + '='.repeat(60));
console.log('✅ Setup concluído com sucesso!');
console.log('='.repeat(60));
console.log('\nPróximos passos:');
console.log('  1. Testar pipeline: node scripts/test-pipeline.js');
console.log('  2. Ver logs: serverless logs -f dataProcessor --stage local -t');
console.log('  3. Ver dados: aws --endpoint-url=http://localhost:4566 dynamodb scan --table-name ProcessedData');
console.log('  4. Remover tudo: serverless remove --stage local\n');
```

---

## **PASSO 7: Configurações Adicionais**

### 7.1 Package.json

```json
{
  "name": "lab04-serverless-localstack",
  "version": "1.0.0",
  "description": "Pipeline de processamento de dados serverless com LocalStack",
  "main": "src/handlers/dataProcessor.js",
  "scripts": {
    "setup": "node scripts/setup.js",
    "test": "node scripts/test-pipeline.js",
    "deploy": "serverless deploy --stage local --verbose",
    "deploy:function": "serverless deploy function -f dataProcessor --stage local",
    "remove": "serverless remove --stage local",
    "logs": "serverless logs -f dataProcessor --stage local",
    "logs:tail": "serverless logs -f dataProcessor --stage local -t",
    "invoke": "serverless invoke -f dataProcessor --stage local --path tests/test-event.json",
    "invoke:api": "serverless invoke -f createRecord --stage local --path tests/test-api.json",
    "info": "serverless info --stage local",
    "docker:up": "docker-compose up -d",
    "docker:down": "docker-compose down",
    "docker:logs": "docker-compose logs -f localstack"
  },
  "keywords": [
    "serverless",
    "localstack",
    "aws",
    "lambda",
    "nodejs",
    "faas"
  ],
  "author": "Aluno PUC Minas",
  "license": "MIT",
  "dependencies": {
    "aws-sdk": "^2.1691.0",
    "uuid": "^9.0.1"
  },
  "devDependencies": {
    "serverless": "^3.38.0",
    "serverless-localstack": "^1.2.0",
    "serverless-offline": "^13.8.1",
    "@types/node": "^20.17.0",
    "@types/aws-lambda": "^8.10.145",
    "eslint": "^8.57.1"
  },
  "engines": {
    "node": ">=18.0.0",
    "npm": ">=9.0.0"
  }
}
```

### 7.2 Variáveis de Ambiente (`.env`)

```env
# LocalStack Configuration
LOCALSTACK_ENDPOINT=http://localhost:4566
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=us-east-1

# Service Configuration
TABLE_NAME=ProcessedData
BUCKET_NAME=data-processing-bucket
TOPIC_NAME=data-processing-notifications
STAGE=local

# Node.js Configuration
NODE_ENV=development
```

### 7.3 GitIgnore (`.gitignore`)

```gitignore
# Node.js
node_modules/
npm-debug.log*
yarn-error.log*
package-lock.json
yarn.lock

# Serverless Framework
.serverless/
.serverless-offline/
.build/

# Environment
.env
.env.local
.env.*.local

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Logs
logs/
*.log

# Temporary files
tmp/
temp/
*.tmp

# AWS
credentials
config
```

---

## **PASSO 8: Deploy e Execução**

### 8.1 Setup Completo Automatizado

```bash
# Método 1: Usando script de setup
npm run setup

# Método 2: Passo a passo manual
npm install
docker-compose up -d
sleep 30
serverless deploy --stage local --verbose
```

### 8.2 Verificar Recursos Criados

```bash
# Verificar bucket S3
aws --endpoint-url=http://localhost:4566 s3 ls

# Listar tabelas DynamoDB
aws --endpoint-url=http://localhost:4566 dynamodb list-tables

# Listar funções Lambda
aws --endpoint-url=http://localhost:4566 lambda list-functions --query 'Functions[*].FunctionName'

# Listar tópicos SNS
aws --endpoint-url=http://localhost:4566 sns list-topics

# Ver informações do stack
serverless info --stage local
```

### 8.3 Testar Pipeline Completo

```bash
# Método 1: Script automatizado (recomendado)
npm test

# Método 2: Teste manual
# Upload de arquivo
aws --endpoint-url=http://localhost:4566 s3 cp data/input/produtos.csv s3://data-processing-bucket/input/

# Aguardar processamento (10-20 segundos)
sleep 15

# Verificar dados processados
aws --endpoint-url=http://localhost:4566 dynamodb scan --table-name ProcessedData --query 'Items[*].[id.S, nome.S, preco.N]' --output table

# Ver logs da Lambda
serverless logs -f dataProcessor --stage local --tail
```

### 8.4 Testar API REST

```bash
# Método 1: Via Serverless
serverless invoke -f createRecord --stage local --path tests/test-api.json

# Método 2: Via curl (requer endpoint do API Gateway)
# Primeiro, obter URL do API Gateway
serverless info --stage local

# Então fazer requisição
curl -X POST http://localhost:4566/restapis/{api-id}/local/_user_request_/records \
  -H "Content-Type: application/json" \
  -d '{"nome":"Teste cURL","preco":150.00}'
```

---

## **PASSO 9: Monitoramento e Debug**

### 9.1 Visualizar Logs em Tempo Real

```bash
# Logs da função dataProcessor
serverless logs -f dataProcessor --stage local --tail

# Logs do LocalStack
docker-compose logs -f localstack

# Logs específicos do Lambda no container
docker logs localstack-serverless-lab -f
```

### 9.2 Invocar Função Manualmente

```bash
# Invocar com evento de teste
serverless invoke -f dataProcessor --stage local --path tests/test-event.json

# Invocar localmente (sem deploy)
serverless invoke local -f dataProcessor --path tests/test-event.json

# Invocar API
serverless invoke -f createRecord --stage local --path tests/test-api.json
```

### 9.3 Consultas DynamoDB

```bash
# Scan completo
aws --endpoint-url=http://localhost:4566 dynamodb scan --table-name ProcessedData

# Scan com projeção de campos específicos
aws --endpoint-url=http://localhost:4566 dynamodb scan --table-name ProcessedData \
  --projection-expression "id, nome, preco, source_file"

# Contar items
aws --endpoint-url=http://localhost:4566 dynamodb scan --table-name ProcessedData --select COUNT

# Query específica (requer partition key)
aws --endpoint-url=http://localhost:4566 dynamodb query --table-name ProcessedData \
  --key-condition-expression "id = :id" \
  --expression-attribute-values '{":id":{"S":"1"}}'
```

### 9.4 Operações S3

```bash
# Listar arquivos
aws --endpoint-url=http://localhost:4566 s3 ls s3://data-processing-bucket/input/

# Ver conteúdo de arquivo
aws --endpoint-url=http://localhost:4566 s3 cp s3://data-processing-bucket/input/produtos.csv -

# Deletar arquivo
aws --endpoint-url=http://localhost:4566 s3 rm s3://data-processing-bucket/input/produtos.csv
```

---

## **PASSO 10: Análise e Documentação**

### 10.1 Análise Arquitetural

**Características Implementadas:**

- ✅ Arquitetura event-driven completamente serverless
- ✅ Pipeline de processamento automático (S3 → Lambda → DynamoDB)
- ✅ API REST serverless com Lambda + API Gateway
- ✅ Notificações pub/sub com SNS
- ✅ Infrastructure as Code com Serverless Framework
- ✅ Desenvolvimento local com LocalStack (sem custos AWS)

**Métricas de Performance Esperadas:**

| Métrica          | Valor              | Observações                    |
| ---------------- | ------------------ | ------------------------------ |
| **Cold Start**   | 500-1500ms         | Primeira invocação após deploy |
| **Warm Start**   | 5-50ms             | Invocações subsequentes        |
| **Throughput**   | Ilimitado          | Auto-scaling automático        |
| **Concorrência** | 1000 (AWS default) | Configurável                   |
| **Timeout**      | 60s (configurado)  | Máximo 15 minutos              |
| **Memória**      | 256MB              | Ajustável por função           |

**Vantagens Demonstradas:**

1. **Pay-per-use**: Custo zero quando não há requisições
2. **Auto-scaling**: Escala automaticamente de 0 a milhões
3. **Zero Server Management**: Infraestrutura gerenciada
4. **Event-driven**: Reação automática a eventos S3
5. **Development Velocity**: Foco em código de negócio

**Limitações Identificadas:**

1. **Cold Start Latency**: ~1 segundo inicial
2. **Vendor Lock-in**: Forte dependência de AWS
3. **Debugging Complexity**: Rastreamento distribuído complexo
4. **Stateless**: Cada invocação é independente
5. **Timeout Limits**: 15 minutos máximo por função

### 10.2 Comparação com Arquiteturas Anteriores

| Aspecto            | Tradicional (Roteiro 1) | gRPC (Roteiro 2)      | Serverless (Roteiro 4) |
| ------------------ | ----------------------- | --------------------- | ---------------------- |
| **Infraestrutura** | Servidor sempre ativo   | Servidor sempre ativo | Sem servidor           |
| **Custo**          | Fixo (24/7)             | Fixo (24/7)           | Por execução           |
| **Escalabilidade** | Manual/Limitada         | Manual/Boa            | Automática/Infinita    |
| **Manutenção**     | Alta                    | Alta                  | Mínima                 |
| **Cold Start**     | N/A                     | N/A                   | 500-1500ms             |
| **Throughput**     | Limitado                | Alto                  | Ilimitado              |
| **Complexidade**   | Baixa                   | Média                 | Média-Alta             |
| **Debugging**      | Fácil                   | Médio                 | Difícil                |
| **Event-driven**   | Manual                  | Manual                | Nativo                 |
| **Vendor Lock-in** | Baixo                   | Baixo                 | Alto                   |

### 10.3 Quando Usar Serverless

**✅ Use Serverless quando:**

1. **Workloads Intermitentes**
   ```
   - Processamento batch noturno
   - Webhooks esporádicos
   - Tarefas agendadas
   - Picos de tráfego imprevisíveis
   ```

2. **Event-driven Applications**
   ```
   - Processamento de uploads
   - Streams de dados
   - IoT data processing
   - Real-time file processing
   ```

3. **Microservices Stateless**
   ```
   - APIs REST simples
   - Data transformation
   - Image processing
   - Notification services
   ```

4. **Prototipação Rápida**
   ```
   - MVPs
   - Proof of concepts
   - Experimentos
   ```

**❌ Evite Serverless quando:**

1. **Aplicações Stateful**
   ```
   - WebSocket servers
   - Game servers
   - Long-running connections
   ```

2. **Workloads Constantes**
   ```
   - Tráfego 24/7 constante
   - Background workers contínuos
   - Pode ser mais caro que servidor dedicado
   ```

3. **Processamento de Longa Duração**
   ```
   - Tarefas > 15 minutos
   - Video encoding complexo
   - Large batch processing
   ```

4. **Requisitos Baixíssimos de Latência**
   ```
   - Trading algorithms
   - Real-time gaming
   - Cold start inaceitável
   ```

### 10.4 Best Practices Implementadas

**1. Separação de Responsabilidades**
```javascript
// ✅ Bom: Funções focadas
- dataProcessor: Apenas processa CSV
- createRecord: Apenas cria registros

// ❌ Evitar: Funções monolíticas que fazem tudo
```

**2. Configuração Externa**
```javascript
// ✅ Bom: Variáveis de ambiente
const tableName = process.env.TABLE_NAME;

// ❌ Evitar: Hardcoded
const tableName = 'ProcessedData';
```

**3. Tratamento de Erros Robusto**
```javascript
// ✅ Bom: Try-catch com logging
try {
  await putItem(item);
} catch (error) {
  console.error('Erro:', error);
  await notifyError(error);
  throw error;
}
```

**4. Princípio de Menor Privilégio (IAM)**
```yaml
# ✅ Bom: Apenas permissões necessárias
- Effect: Allow
  Action:
    - dynamodb:PutItem
  Resource: !GetAtt ProcessedDataTable.Arn

# ❌ Evitar: Permissões amplas
- Effect: Allow
  Action: '*'
  Resource: '*'
```

**5. Timeout e Memory Sizing**
```yaml
# ✅ Bom: Ajustado para workload
timeout: 60
memorySize: 256

# ❌ Evitar: Valores padrão sem otimização
```

### 10.5 Troubleshooting Comum

**Problema 1: Lambda não é invocada pelo S3**
```bash
# Solução: Recriar trigger
serverless deploy --stage local --force

# Verificar permissões
aws --endpoint-url=http://localhost:4566 lambda get-policy --function-name DataProcessorFunction
```

**Problema 2: Erro "Cannot find module"**
```bash
# Solução: Reinstalar dependências
rm -rf node_modules
npm install

# Redeploy
serverless deploy --stage local
```

**Problema 3: LocalStack não inicia**
```bash
# Solução: Limpar e reiniciar
docker-compose down -v
docker-compose up -d

# Aguardar inicialização
sleep 30
```

**Problema 4: DynamoDB não recebe dados**
```bash
# Verificar logs da Lambda
serverless logs -f dataProcessor --stage local

# Verificar se função foi invocada
aws --endpoint-url=http://localhost:4566 lambda get-function --function-name DataProcessorFunction

# Testar manualmente
serverless invoke -f dataProcessor --stage local --path tests/test-event.json
```

---

## **Exercícios Complementares**

1. **Implementar Retry Logic**: Adicionar lógica de retry com exponential backoff para falhas no DynamoDB

2. **Dead Letter Queue**: Configurar DLQ para processar eventos com falha

3. **Métricas Customizadas**: Enviar métricas customizadas para CloudWatch

4. **Caching**: Implementar caching de leituras frequentes do DynamoDB

5. **Batch Processing**: Modificar para processar múltiplos arquivos em paralelo

6. **API Authentication**: Adicionar autenticação JWT ou API Keys no API Gateway

7. **Data Validation**: Implementar validação de schema mais robusta com Joi ou Ajv

8. **Lambda Layers**: Criar Lambda Layer para código compartilhado

9. **Step Functions**: Orquestrar pipeline complexo com AWS Step Functions

10. **Performance Monitoring**: Implementar tracing distribuído com X-Ray

---

## **Entregáveis**

### Checklist de Implementação

**Configuração:**
- [ ] LocalStack rodando via Docker Compose
- [ ] Serverless Framework configurado corretamente
- [ ] Todas as dependências Node.js instaladas
- [ ] Variáveis de ambiente configuradas

**Funções Lambda:**
- [ ] dataProcessor implementada e funcional
- [ ] createRecord implementada e funcional
- [ ] Helpers (DynamoDB, S3, SNS) implementados
- [ ] Tratamento de erros robusto em todas funções

**Infraestrutura:**
- [ ] Bucket S3 criado
- [ ] Tabela DynamoDB criada
- [ ] Tópico SNS criado
- [ ] API Gateway configurado
- [ ] Triggers S3 → Lambda funcionando

**Testes:**
- [ ] Upload de CSV dispara Lambda automaticamente
- [ ] Dados são processados e salvos no DynamoDB
- [ ] Notificações SNS são enviadas
- [ ] API REST responde corretamente
- [ ] Script de teste automatizado executa sem erros

**Documentação:**
- [ ] README.md completo
- [ ] Comentários no código
- [ ] Diagrama de arquitetura
- [ ] Análise comparativa com outras arquiteturas
- [ ] Identificação de casos de uso apropriados

---

## **Comandos Úteis**

### Deploy e Remoção
```bash
# Deploy completo
npm run deploy
# ou
serverless deploy --stage local

# Deploy apenas de uma função
serverless deploy function -f dataProcessor --stage local

# Remover tudo
npm run remove
# ou
serverless remove --stage local
```

### Testes e Debugging
```bash
# Executar teste automatizado
npm test

# Ver logs em tempo real
npm run logs:tail

# Invocar função manualmente
npm run invoke

# Testar API
npm run invoke:api

# Ver informações do stack
npm run info
```

### Docker/LocalStack
```bash
# Iniciar LocalStack
npm run docker:up

# Parar LocalStack
npm run docker:down

# Ver logs do LocalStack
npm run docker:logs
```

### AWS CLI (LocalStack)
```bash
# S3
aws --endpoint-url=http://localhost:4566 s3 ls
aws --endpoint-url=http://localhost:4566 s3 cp arquivo.csv s3://data-processing-bucket/input/
aws --endpoint-url=http://localhost:4566 s3 rm s3://data-processing-bucket/input/arquivo.csv

# DynamoDB
aws --endpoint-url=http://localhost:4566 dynamodb list-tables
aws --endpoint-url=http://localhost:4566 dynamodb scan --table-name ProcessedData
aws --endpoint-url=http://localhost:4566 dynamodb describe-table --table-name ProcessedData

# Lambda
aws --endpoint-url=http://localhost:4566 lambda list-functions
aws --endpoint-url=http://localhost:4566 lambda get-function --function-name DataProcessorFunction
aws --endpoint-url=http://localhost:4566 lambda invoke --function-name DataProcessorFunction output.json

# SNS
aws --endpoint-url=http://localhost:4566 sns list-topics
aws --endpoint-url=http://localhost:4566 sns list-subscriptions
```

---

## **Conclusão**

Este roteiro demonstrou a implementação completa de uma arquitetura serverless usando AWS Lambda, S3, DynamoDB e SNS, com desenvolvimento local via LocalStack. Os principais conceitos abordados incluem:

1. **Function as a Service (FaaS)**: Execução de código sem gerenciar servidores
2. **Event-driven Architecture**: Reação automática a eventos do sistema
3. **Infrastructure as Code**: Definição declarativa de toda infraestrutura
4. **Pay-per-use Model**: Custos baseados apenas em execuções reais
5. **Auto-scaling**: Escalamento transparente e automático

**Próximos Passos:**

- Experimentar com outros triggers (DynamoDB Streams, SQS, etc)
- Implementar orquestração complexa com Step Functions
- Adicionar monitoramento e alertas com CloudWatch
- Explorar Lambda Layers para otimização
- Migrar para produção na AWS real

---

## **Referências**

<sup>[1]</sup> ROBERTS, Mike. **Serverless Architectures**. Martin Fowler, 2018. Disponível em: https://martinfowler.com/articles/serverless.html

<sup>[2]</sup> BALDINI, Ioana et al. **Serverless Computing: Current Trends and Open Problems**. Research Advances in Cloud Computing, Singapore: Springer, 2017.

<sup>[3]</sup> **LocalStack Documentation**. Disponível em: https://docs.localstack.cloud/

**AWS Lambda Developer Guide**. Amazon Web Services. Disponível em: https://docs.aws.amazon.com/lambda/

**Serverless Framework Documentation**. Disponível em: https://www.serverless.com/framework/docs

**KLEPPMANN, Martin.** Designing Data-Intensive Applications. O'Reilly Media, 2017.
