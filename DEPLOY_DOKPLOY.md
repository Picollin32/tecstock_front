# 🚀 Tutorial Completo: Deploy TecStock no Hostinger com Dokploy

## 📋 Índice
1. [Preparação Inicial](#1-preparação-inicial)
2. [Configurar VPS Hostinger](#2-configurar-vps-hostinger)
3. [Instalar Dokploy](#3-instalar-dokploy)
4. [Preparar Repositório](#4-preparar-repositório)
5. [Deploy no Dokploy](#5-deploy-no-dokploy)
6. [Configurar Domínio e SSL](#6-configurar-domínio-e-ssl)
7. [Verificação e Testes](#7-verificação-e-testes)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. Preparação Inicial

### 1.1 Verificar Requisitos

✅ **Você tem:**
- VPS Hostinger com 8GB RAM
- KVM 2 habilitado
- Acesso SSH à VPS

✅ **Você precisa:**
- Domínio configurado (opcional, mas recomendado)
- Conta GitHub com o código
- Cliente SSH (PuTTY no Windows ou terminal)

---

## 2. Configurar VPS Hostinger

### 2.1 Acessar VPS via SSH

**No PowerShell (Windows):**
```powershell
ssh root@seu-ip-vps
```

Substitua `seu-ip-vps` pelo IP da sua VPS Hostinger.

### 2.2 Atualizar Sistema

```bash
apt update && apt upgrade -y
```

### 2.3 Instalar Docker

```bash
# Remover versões antigas (se existirem)
apt remove docker docker-engine docker.io containerd runc

# Instalar dependências
apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Adicionar chave GPG oficial do Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Adicionar repositório Docker
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Verificar instalação
docker --version
docker compose version
```

### 2.4 Configurar Firewall

```bash
# Instalar UFW se não estiver instalado
apt install -y ufw

# Configurar regras
ufw allow 22/tcp      # SSH
ufw allow 80/tcp      # HTTP
ufw allow 443/tcp     # HTTPS
ufw allow 3000/tcp    # Dokploy Dashboard

# Ativar firewall
ufw enable
ufw status
```

---

## 3. Instalar Dokploy

### 3.1 Verificar Porta 80

Antes de instalar, verifique se algo está usando a porta 80:

```bash
# Verificar o que está rodando na porta 80
lsof -i :80

# Ou usar netstat
netstat -tulpn | grep :80

# Ou usar ss
ss -tulpn | grep :80
```

**Se encontrar algo (geralmente Apache ou Nginx):**

```bash
# Parar Apache
systemctl stop apache2
systemctl disable apache2

# OU parar Nginx
systemctl stop nginx
systemctl disable nginx

# Verificar se a porta está livre
lsof -i :80
```

### 3.2 Executar Instalação

```bash
curl -sSL https://dokploy.com/install.sh | sh
```

**Aguarde 5-10 minutos** para a instalação completar.

### 3.3 Verificar Instalação

```bash
docker ps
```

Você deve ver containers do Dokploy rodando.

### 3.4 Acessar Dashboard

Abra no navegador:
```
http://SEU-IP-VPS:3000
```

**Primeira vez:**
1. Crie uma conta de administrador
2. Defina email e senha forte
3. Faça login

---

## 4. Preparar Repositório

### 4.1 Adicionar .env ao .gitignore

No arquivo `tecstock_front/.gitignore`, adicione:

```
.env
```

### 4.2 Commitar Arquivos Docker

**No seu computador (PowerShell):**

```powershell
cd d:\Projetos\tecstock_front

git add .
git commit -m "feat: adicionar configuração Docker para Dokploy"
git push origin main
```

### 4.3 Verificar Estrutura no GitHub

Confirme que existe no repositório:
- ✅ `docker-compose.yml`
- ✅ `Dockerfile`
- ✅ `nginx.conf`
- ✅ `.env.example`
- ✅ `../tecstock_spring/Dockerfile`

---

## 5. Deploy no Dokploy

### 5.1 Criar Novo Projeto

1. No Dokploy Dashboard, clique em **"Create Project"**
2. **Project Name:** `TecStock`
3. **Description:** `Sistema de Gestão TecStock - Flutter Web + Spring Boot`
4. Clique em **"Create"**

### 5.2 Adicionar Serviço Compose

1. Dentro do projeto TecStock, clique em **"Create Service"**
2. Selecione **"Docker Compose"**
3. Preencha:
   - **Name:** `tecstock-app`
   - **Repository:** `https://github.com/Picollin32/tecstock_front.git`
   - **Branch:** `main`
   - **Compose Path:** `docker-compose.yml`

### 5.3 Configurar Variáveis de Ambiente

1. Na aba **"Environment"**, clique em **"Add Variable"**
2. Adicione as seguintes variáveis:

```env
SPRING_PROFILES_ACTIVE=prod
DB_HOST_PROD=postgres
DB_PORT_PROD=5432
DB_NAME_PROD=TecStock
DB_USERNAME_PROD=postgres
DB_PASSWORD_PROD=SuaSenhaSegura123!
JWT_SECRET=TecStockSecretKeyPROD2024!@#ChangeMeToSecureValue$%^&*
JWT_EXPIRATION=86400000
```

**⚠️ IMPORTANTE:**
- Altere `DB_PASSWORD_PROD` para uma senha forte!
- Altere `JWT_SECRET` para uma chave única e complexa!

### 5.4 Configurar Build Settings

1. Na aba **"Advanced"**, configure:
   - **Restart Policy:** `unless-stopped`
   - **Memory Limit:** `6GB` (deixar margem para o sistema)

### 5.5 Iniciar Deploy

1. Clique em **"Deploy"**
2. Aguarde o build (primeira vez: 10-15 minutos)
3. Acompanhe os logs em tempo real

**Progresso esperado:**
```
✅ Cloning repository...
✅ Building backend (Spring Boot)...
✅ Building frontend (Flutter Web)...
✅ Starting PostgreSQL...
✅ Starting backend...
✅ Starting frontend...
✅ All services healthy!
```

---

## 6. Configurar Domínio e SSL

### 6.1 Adicionar Domínio no Dokploy

1. No projeto TecStock, vá em **"Domains"**
2. Clique em **"Add Domain"**

**Para o Frontend:**
- **Domain:** `tecstock.seudominio.com`
- **Service:** `frontend`
- **Port:** `80`
- **SSL:** ✅ Enable (Let's Encrypt automático)

**Para o Backend (API):**
- **Domain:** `api.tecstock.seudominio.com`
- **Service:** `backend`
- **Port:** `8081`
- **SSL:** ✅ Enable

### 6.2 Configurar DNS no Provedor

No painel do seu provedor de domínio, adicione:

**Registro A para Frontend:**
```
Tipo: A
Nome: tecstock
Valor: [IP da sua VPS]
TTL: 3600
```

**Registro A para Backend:**
```
Tipo: A
Nome: api.tecstock
Valor: [IP da sua VPS]
TTL: 3600
```

### 6.3 Aguardar Propagação DNS

- Propagação pode levar 5 minutos a 24 horas
- Verifique em: https://dnschecker.org

---

## 7. Verificação e Testes

### 7.1 Verificar Status dos Serviços

No Dokploy:
1. Vá em **"Services"**
2. Todos devem estar **"Running"** com ✅ verde

### 7.2 Testar Endpoints

**Frontend:**
```
http://tecstock.seudominio.com
ou
http://SEU-IP-VPS
```

**Backend Health Check:**
```
http://api.tecstock.seudominio.com/actuator/health
ou
http://SEU-IP-VPS:8081/actuator/health
```

Resposta esperada:
```json
{"status":"UP"}
```

### 7.3 Verificar Logs

No Dokploy, para cada serviço:
1. Clique no serviço
2. Vá em **"Logs"**
3. Verifique se não há erros

**Logs esperados:**

**PostgreSQL:**
```
database system is ready to accept connections
```

**Backend:**
```
Started Main in X.XXX seconds
```

**Frontend:**
```
/docker-entrypoint.sh: Configuration complete; ready for start up
```

### 7.4 Testar Login

1. Acesse o frontend
2. Tente fazer login
3. Verifique se a aplicação funciona normalmente

---

## 8. Troubleshooting

### Problema 1: Backend não inicia

**Sintomas:**
- Backend sempre reiniciando
- Erro nos logs: "Connection refused"

**Solução:**
```bash
# SSH na VPS
ssh root@SEU-IP-VPS

# Verificar logs do PostgreSQL
docker logs tecstock-db

# Verificar se PostgreSQL está pronto
docker exec tecstock-db pg_isready -U postgres

# Se necessário, reiniciar PostgreSQL
docker restart tecstock-db

# Aguardar 30 segundos e reiniciar backend
docker restart tecstock-backend
```

### Problema 2: Erro de build - Flutter

**Sintomas:**
- Build do frontend falha
- Erro: "Flutter SDK not found"

**Solução:**
- Verificar se o Dockerfile do frontend está correto
- No Dokploy, force um rebuild:
  1. Vá em "Builds"
  2. Clique em "Rebuild"
  3. Aguarde novo build

### Problema 3: Erro 502 Bad Gateway

**Sintomas:**
- Ao acessar domínio, aparece erro 502

**Solução:**
```bash
# Verificar se todos os containers estão rodando
docker ps

# Verificar logs do nginx/traefik
docker logs dokploy-traefik

# Reiniciar Dokploy
systemctl restart dokploy
```

### Problema 4: Banco de dados vazio

**Sintomas:**
- Aplicação não encontra dados
- Erro: "Table not found"

**Solução:**
```bash
# Acessar banco
docker exec -it tecstock-db psql -U postgres -d TecStock

# Verificar tabelas
\dt

# Se vazio, verificar logs do backend para ver se migration rodou
docker logs tecstock-backend | grep -i hibernate

# Verificar application-prod.properties
# Deve ter: spring.jpa.hibernate.ddl-auto=update
```

### Problema 5: JWT Token inválido

**Sintomas:**
- Login falha
- Erro: "Invalid JWT signature"

**Solução:**
- Verificar se `JWT_SECRET` está configurado corretamente
- Garantir que backend e frontend usam a mesma secret
- No Dokploy, vá em Environment e verifique a variável

### Problema 6: Sem espaço em disco

**Sintomas:**
- Build falha
- Erro: "No space left on device"

**Solução:**
```bash
# Limpar imagens Docker não usadas
docker system prune -a --volumes

# Verificar espaço
df -h

# Se necessário, aumentar disco da VPS no painel Hostinger
```

---

## 📊 Monitoramento

### Verificar Uso de Recursos

```bash
# Ver uso de CPU/RAM de cada container
docker stats

# Ver tamanho dos volumes
docker system df
```

**Uso esperado com 8GB RAM:**
- PostgreSQL: ~300-500MB
- Backend: ~1-1.5GB
- Frontend: ~50-100MB
- Dokploy: ~300-500MB
- Sistema: ~1GB
- **Livre: ~4-5GB** ✅

---

## 🔐 Segurança Pós-Deploy

### Checklist de Segurança

```bash
# 1. Desabilitar login root via SSH
nano /etc/ssh/sshd_config
# Alterar: PermitRootLogin no
systemctl restart sshd

# 2. Criar usuário não-root
adduser tecstock
usermod -aG sudo tecstock
usermod -aG docker tecstock

# 3. Configurar fail2ban
apt install -y fail2ban
systemctl enable fail2ban
systemctl start fail2ban

# 4. Atualizar sistema regularmente
apt update && apt upgrade -y
```

### Backup Automático

```bash
# Criar script de backup
nano /root/backup-tecstock.sh
```

Adicione:
```bash
#!/bin/bash
BACKUP_DIR="/root/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup do banco
docker exec tecstock-db pg_dump -U postgres TecStock > "$BACKUP_DIR/tecstock_$DATE.sql"

# Manter apenas últimos 7 dias
find $BACKUP_DIR -name "tecstock_*.sql" -mtime +7 -delete

echo "Backup completo: $DATE"
```

Tornar executável e agendar:
```bash
chmod +x /root/backup-tecstock.sh

# Adicionar ao crontab (diário às 2AM)
crontab -e
# Adicione: 0 2 * * * /root/backup-tecstock.sh
```

---

## 🎯 URLs Finais

Após deploy completo:

- **Frontend:** https://tecstock.seudominio.com
- **Backend API:** https://api.tecstock.seudominio.com
- **Dokploy Dashboard:** http://SEU-IP-VPS:3000
- **Health Check:** https://api.tecstock.seudominio.com/actuator/health

---

## 📞 Próximos Passos

1. ✅ Configurar backup automático
2. ✅ Configurar monitoramento (Uptime Robot, etc)
3. ✅ Configurar CI/CD para deploy automático
4. ✅ Adicionar domínio de email profissional
5. ✅ Documentar API (Swagger)

---

## 🆘 Suporte

**Documentação Oficial:**
- Dokploy: https://docs.dokploy.com
- Docker: https://docs.docker.com
- Hostinger VPS: https://support.hostinger.com

**Comandos Úteis:**
```bash
# Ver status de todos os serviços
docker ps -a

# Reiniciar tudo
docker-compose restart

# Ver logs de todos os serviços
docker-compose logs -f

# Parar tudo
docker-compose down

# Iniciar tudo novamente
docker-compose up -d
```

---

**✨ Parabéns! Seu TecStock está no ar! 🚀**
