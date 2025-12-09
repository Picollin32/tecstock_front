# 🚀 Guia Completo - Deploy TecStock no Dokploy

Este guia mostra como fazer deploy do TecStock no Dokploy usando **3 aplicações separadas** (Database, Backend, Frontend).

## 📋 Pré-requisitos

- ✅ VPS Hostinger com Dokploy instalado
- ✅ Repositórios Git: `tecstock_front` e `tecstock_spring`
- ✅ Domínio configurado (opcional, mas recomendado)
- ✅ Acesso ao painel Dokploy

---

## 🎯 Arquitetura do Deploy

```
┌─────────────────────────────────────────┐
│     DOKPLOY - 3 Aplicações Separadas    │
├─────────────────────────────────────────┤
│                                         │
│  1️⃣ PostgreSQL Database (Gerenciado)    │
│     Nome: tecstock-db                   │
│     Porta: 5432 (interna)               │
│                                         │
│  2️⃣ Backend Spring Boot (Dockerfile)    │
│     Repo: tecstock_spring               │
│     Porta: 8081 → api.seudominio.com    │
│                                         │
│  3️⃣ Frontend Flutter Web (Dockerfile)   │
│     Repo: tecstock_front                │
│     Porta: 80 → seudominio.com          │
│                                         │
└─────────────────────────────────────────┘
```

---

## 🔐 Passo 0: Preparar Credenciais

Antes de começar, gere as credenciais necessárias:

### Senha do Banco de Dados
```powershell
# PowerShell (Windows)
-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | % {[char]$_})
```

### JWT Secret
```bash
openssl rand -base64 64
```

**📝 Anote estas informações:**
```
DB_PASSWORD: ____________________
JWT_SECRET: ____________________
```

---

## 1️⃣ CRIAR DATABASE (PostgreSQL)

### Passo 1.1: Acessar Dokploy
1. Acesse seu Dokploy: `https://seu-servidor:3000`
2. Faça login

### Passo 1.2: Criar Database
1. Clique em **"Create"** ou **"New"**
2. Selecione **"Database"**
3. Escolha **"Postgres"**

### Passo 1.3: Configurar Database
```yaml
Nome da Aplicação: tecstock-db
Database Name: TecStock
Username: tecstock_user
Password: [Cole a senha que você gerou]
PostgreSQL Version: 16 (ou mais recente)
```

### Passo 1.4: Configurações Adicionais
- **Persistent Volume:** ✅ Habilitado (para manter dados)
- **Memory Limit:** 512MB (ajuste conforme necessário)

### Passo 1.5: Deploy
1. Clique em **"Create"** ou **"Deploy"**
2. Aguarde ~2 minutos
3. Status deve ficar **"Running"** ✅

### Passo 1.6: Anotar Informações de Conexão
O Dokploy mostrará:
```
Internal Connection:
  Host: tecstock-db
  Port: 5432
  Database: TecStock
  Username: tecstock_user
  Password: [sua senha]
```

**💡 Importante:** Use o hostname `tecstock-db` para conexão interna!

---

## 2️⃣ CRIAR BACKEND (Spring Boot)

### Passo 2.1: Criar Nova Aplicação
1. No Dokploy, clique em **"Create"** → **"Application"**
2. Nome: `tecstock-backend`

### Passo 2.2: Configurar Source (Git)
```yaml
Source Type: Git
Repository URL: https://github.com/Picollin32/tecstock_spring.git
Branch: main
Auto Deploy: ✅ Habilitado (opcional)
```

**Se repositório privado:**
- Adicione Deploy Key ou Personal Access Token

### Passo 2.3: Configurar Build
```yaml
Build Type: Dockerfile
Dockerfile Path: ./Dockerfile
Context Path: .
Build Args: (nenhum necessário)
```

### Passo 2.4: Configurar Environment Variables
Clique em **"Environment"** e adicione:

```bash
# Profile
SPRING_PROFILES_ACTIVE=prod

# Database Connection
DB_URL=jdbc:postgresql://tecstock-db:5432/TecStock
DB_USERNAME=tecstock_user
DB_PASSWORD=[Cole a senha do banco que você gerou]

# Server
SERVER_PORT=8081

# JWT
JWT_SECRET=[Cole o JWT Secret que você gerou]
JWT_EXPIRATION=86400000
```

**⚠️ Importante:** Use `tecstock-db` como hostname (nome da aplicação do banco)!

### Passo 2.5: Configurar Networking
```yaml
Port: 8081
Protocol: HTTP
```

### Passo 2.6: Configurar Domínio
1. Clique em **"Domains"** ou **"Add Domain"**
2. Domain: `api.seudominio.com`
3. **Enable SSL/TLS:** ✅ Sim
4. Certificate: Let's Encrypt (automático)

### Passo 2.7: Configurar Health Check (Opcional)
```yaml
Path: /actuator/health
Port: 8081
Interval: 30s
Timeout: 10s
Retries: 3
```

### Passo 2.8: Deploy Backend
1. Clique em **"Deploy"**
2. Acompanhe os logs de build (5-10 minutos)
3. Aguarde status **"Running"** ✅

### Passo 2.9: Testar Backend
Acesse: `https://api.seudominio.com/actuator/health`

Resposta esperada:
```json
{"status":"UP"}
```

---

## 3️⃣ CRIAR FRONTEND (Flutter Web)

### Passo 3.1: Criar Nova Aplicação
1. No Dokploy, clique em **"Create"** → **"Application"**
2. Nome: `tecstock-frontend`

### Passo 3.2: Configurar Source (Git)
```yaml
Source Type: Git
Repository URL: https://github.com/Picollin32/tecstock_front.git
Branch: main
Auto Deploy: ✅ Habilitado (opcional)
```

### Passo 3.3: Configurar Build
```yaml
Build Type: Dockerfile
Dockerfile Path: ./Dockerfile
Context Path: .
```

### Passo 3.4: Configurar Build Arguments
**Importante!** O frontend precisa saber a URL da API:

```yaml
Build Args:
  API_BASE_URL=https://api.seudominio.com
```

**💡 Nota:** Isso define a URL da API em tempo de build do Flutter.

### Passo 3.5: Configurar Networking
```yaml
Port: 80
Protocol: HTTP
```

### Passo 3.6: Configurar Domínio
1. Clique em **"Domains"** ou **"Add Domain"**
2. Adicione **dois domínios**:
   - Domain 1: `seudominio.com`
   - Domain 2: `www.seudominio.com`
3. **Enable SSL/TLS:** ✅ Sim (em ambos)
4. Certificate: Let's Encrypt (automático)

### Passo 3.7: Deploy Frontend
1. Clique em **"Deploy"**
2. Acompanhe os logs de build (5-10 minutos)
3. Aguarde status **"Running"** ✅

### Passo 3.8: Testar Frontend
Acesse: `https://seudominio.com`

Você deve ver a tela de login do TecStock! 🎉

---

## 🌐 Configurar DNS (Hostinger)

Antes de SSL funcionar, configure o DNS:

### Passo DNS.1: Acessar hPanel Hostinger
1. Login no hPanel
2. Vá em **Domínios** → Seu domínio
3. Clique em **DNS / Nameservers**

### Passo DNS.2: Adicionar Registros
Adicione os seguintes registros A:

```
Tipo: A
Nome: @
Aponta para: [IP do seu VPS]
TTL: 14400

Tipo: A
Nome: www
Aponta para: [IP do seu VPS]
TTL: 14400

Tipo: A
Nome: api
Aponta para: [IP do seu VPS]
TTL: 14400
```

### Passo DNS.3: Aguardar Propagação
- Tempo: 10 minutos a 48 horas (geralmente 1-2 horas)
- Verificar: `nslookup seudominio.com`

---

## ✅ Verificação Final

### Checklist de Funcionamento

```bash
# 1. Database rodando?
Status: ✅ Running

# 2. Backend rodando e conectado ao banco?
curl https://api.seudominio.com/actuator/health
Resposta: {"status":"UP"}

# 3. Frontend rodando?
curl https://seudominio.com
Resposta: HTML do TecStock

# 4. SSL funcionando?
Navegador: 🔒 Cadeado verde em ambos domínios

# 5. Login funciona?
Tela de login → Backend → Database → ✅
```

---

## 🔄 Ordem de Inicialização

O Dokploy não precisa de dependências explícitas, mas inicie nesta ordem:

1. ✅ Database (tecstock-db)
2. ✅ Backend (tecstock-backend) - aguarda ~30s após DB
3. ✅ Frontend (tecstock-frontend)

---

## 📊 Resumo das Aplicações

| Aplicação | Tipo | Porta | Domínio | SSL |
|-----------|------|-------|---------|-----|
| tecstock-db | Postgres | 5432 (interno) | - | N/A |
| tecstock-backend | Dockerfile | 8081 | api.seudominio.com | ✅ |
| tecstock-frontend | Dockerfile | 80 | seudominio.com | ✅ |

---

## 🔧 Manutenção

### Atualizar Backend
1. Faça commit no repo `tecstock_spring`
2. No Dokploy → tecstock-backend → **"Redeploy"**
3. Aguarde rebuild

### Atualizar Frontend
1. Faça commit no repo `tecstock_front`
2. No Dokploy → tecstock-frontend → **"Redeploy"**
3. Aguarde rebuild

### Ver Logs
- Database: Dokploy → tecstock-db → **Logs**
- Backend: Dokploy → tecstock-backend → **Logs**
- Frontend: Dokploy → tecstock-frontend → **Logs**

### Backup do Banco
1. Dokploy → tecstock-db → **Backups**
2. Configure backup automático diário
3. Ou manualmente via terminal do container

---

## 🐛 Troubleshooting

### Backend não conecta ao banco
```bash
# Verificar se database está rodando
Status da aplicação tecstock-db: Running?

# Verificar variáveis de ambiente do backend
DB_URL deve ser: jdbc:postgresql://tecstock-db:5432/TecStock
DB_USERNAME: tecstock_user
DB_PASSWORD: [conferir se está correto]

# Ver logs do backend
Dokploy → tecstock-backend → Logs
Procurar por: "connection refused" ou "authentication failed"
```

### Frontend não conecta ao backend
```bash
# Verificar build arg
API_BASE_URL deve ser: https://api.seudominio.com

# Testar API diretamente
curl https://api.seudominio.com/actuator/health

# Se necessário, rebuildar frontend com build arg correto
```

### SSL não funciona
```bash
# Verificar DNS
nslookup seudominio.com
nslookup api.seudominio.com

# Aguardar propagação DNS (até 48h, geralmente 1-2h)

# Force renovação no Dokploy
Dokploy → Application → Domains → Renew Certificate
```

### Container reiniciando
```bash
# Ver logs
Dokploy → Application → Logs

# Verificar memória
Dokploy → Application → Resources
Aumente Memory Limit se necessário
```

---

## 🔐 Segurança

### Checklist de Segurança

- [x] Senhas fortes configuradas
- [x] JWT Secret único e seguro
- [x] PostgreSQL não exposto publicamente (apenas interno)
- [x] SSL/HTTPS habilitado em produção
- [x] Variáveis sensíveis em Environment Variables (não no código)
- [x] CORS já configurado no backend
- [x] Auto-deploy apenas se repositório privado

---

## 💾 Backup

### Configurar Backup Automático

**Via Dokploy:**
1. tecstock-db → **Backups**
2. Enable Automatic Backup
3. Frequency: Daily
4. Retention: 7 days (ou mais)

**Manual via SSH:**
```bash
# Conectar ao servidor
ssh root@seu-ip-hostinger

# Listar containers
docker ps

# Backup do banco
docker exec [container-id-do-postgres] pg_dump -U tecstock_user TecStock > backup.sql
```

---

## 🎉 Conclusão

Seu TecStock agora está rodando no Dokploy com:

✅ Database PostgreSQL gerenciado  
✅ Backend Spring Boot com auto-deploy  
✅ Frontend Flutter Web com SSL  
✅ Arquitetura escalável e modular  

**Próximos passos:**
- Configure monitoramento
- Configure backups automáticos
- Adicione alertas de downtime
- Otimize performance conforme necessário

---

## 📞 Recursos Adicionais

- **Dokploy Docs:** https://docs.dokploy.com
- **Docker Docs:** https://docs.docker.com
- **PostgreSQL Docs:** https://www.postgresql.org/docs

**Dúvidas?** Consulte os logs de cada aplicação no painel Dokploy!

Bom deploy! 🚀
