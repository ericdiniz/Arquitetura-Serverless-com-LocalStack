## ☁️ Simulação de Cloud com LocalStack (31 Pontos)

**Contexto:** Introdução a Cloud AWS em ambiente local.
**Objetivo:** Substituir o armazenamento de arquivos locais ou introduzir armazenamento de objetos (S3) para as fotos tiradas, utilização do SQS/SNS e DynamoDB.

### 📝 Especificação

Atualmente, as fotos tiradas no App Mobile ficam apenas no celular. O aluno deve configurar o **LocalStack** para simular um bucket S3 da AWS. Assim como serão utilizados o SQS/SNS e DynamoDB para demais elementos manipulados.

### Requisitos Técnicos:

1.  **Docker Compose:** Configurar um container do LocalStack no `docker-compose.yml` expondo as portas necessárias.
2.  **Serviço de Upload (Backend):** Criar um endpoint no Backend (pode ser no API Gateway ) que recebe a imagem em Base64 ou Multipart, e utiliza o SDK da AWS (aws-sdk) para salvar no bucket S3 do LocalStack.
3.  **Integração Mobile:** Quando o usuário tirar uma foto e salvar a tarefa (online), o app deve enviar a foto para o backend, que a salvará no "S3". Assim como as demais informações nos serviços SQS/SNS e DynamoDB.

### 🎬 Roteiro da Demonstração (Sala de Aula):

1.  **Infraestrutura:** Rodar `docker-compose up` e mostrar o LocalStack subindo.
2.  **Configuração:** Executar comando via terminal (AWS CLI apontando para local) para listar os buckets e mostrar que o bucket `shopping-images` existe.
3.  **Ação:** No app mobile, tirar uma foto de um produto e salvar.
4.  **Validação:** Via terminal ou navegador de S3 local, listar os objetos do bucket e provar que a imagem foi salva lá "na nuvem local".

---
