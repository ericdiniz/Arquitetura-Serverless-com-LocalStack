# Roteiro de Demonstração — LocalStack + Task Manager

> Roteiro da Demonstração (Sala de Aula). [Pular instalações]

## Preparação (apenas comandos)

## 1. Subir LocalStack (janela 1)

```bash
cd /Users/ericdiniz/Documents/GitHub/Arquitetura-Serverless-com-LocalStack
docker compose -f docker-compose.localstack.yml up -d
docker ps --filter name=localstack -a
docker logs -f localstack
```

## 2. Backend (janela 2)

```bash
cd /Users/ericdiniz/Documents/GitHub/Arquitetura-Serverless-com-LocalStack/backend-localstack
npm install
# manter este terminal aberto para ver logs do backend
LOCALSTACK_ENDPOINT=http://localhost:4566 node index.js
```

## 3. Cópia limpa do app (janela 3)

```bash
# recriar cópia limpa em /tmp
rm -rf /tmp/task_manager_clean
COPYFILE_DISABLE=1 rsync -avh --delete --progress /Users/ericdiniz/Documents/GitHub/Arquitetura-Serverless-com-LocalStack/lab07-flutter/task_manager/ /tmp/task_manager_clean/
cd /tmp/task_manager_clean
/opt/homebrew/bin/flutter pub get
cd ios
pod install --repo-update
cd ..
```

## 4. Simulator e app (janela 4)

```bash
# listar dispositivos e escolher UDID (ex.: AB84DDBF-...)
xcrun simctl list devices available
# bootar e abrir simulator
xcrun simctl boot <UDID>
open -a Simulator
# rodar app (a partir de /tmp/task_manager_clean)
cd /tmp/task_manager_clean
/opt/homebrew/bin/flutter run -d <UDID>
```

## Roteiro de Teste (na frente do professor)

## 1) Infraestrutura — mostrar LocalStack

```bash
# em terminal 1
docker ps --filter name=localstack -a
docker logs --tail 50 localstack
```

## 2) Configuração — listar buckets

```bash
aws --endpoint-url http://localhost:4566 s3api list-buckets --query 'Buckets[].Name' --output json
```

## 3) Ação — no app (Simulator)

- Abra o app, clique para criar nova tarefa, tire/adicione uma foto e salve.

## 4) Validação — listar objetos e baixar a foto

```bash
# listar objetos
aws --endpoint-url http://localhost:4566 s3 ls s3://shopping-images --recursive

# baixar o objeto mais recente (substitua <KEY> pelo nome listado)
aws --endpoint-url http://localhost:4566 s3api get-object --bucket shopping-images --key <KEY> /tmp/photo.jpg
open /tmp/photo.jpg
```
