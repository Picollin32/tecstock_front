# ⚡ Guia Rápido - Deploy TecStock no Dokploy

## 🎯 3 Aplicações Separadas

```
📦 tecstock-db (PostgreSQL)
📦 tecstock-backend (Spring Boot)
📦 tecstock-frontend (Flutter Web)
```

---

## 🚀 Passo a Passo Rápido

### 1️⃣ Database (5 minutos)

```
Dokploy → Create → Database → Postgres

Nome: tecstock-db
Database: TecStock
User: tecstock_user
Password: [senha forte]
Version: 16

→ Deploy
```

### 2️⃣ Backend (10 minutos)

```
Dokploy → Create → Application

Nome: tecstock-backend
Git: https://github.com/Picollin32/tecstock_spring.git
Branch: main
Build: Dockerfile

Environment Variables:
  SPRING_PROFILES_ACTIVE=prod
  DB_URL=jdbc:postgresql://tecstock-db:5432/TecStock
  DB_USERNAME=tecstock_user
  DB_PASSWORD=[sua senha do passo 1]
  SERVER_PORT=8081
  JWT_SECRET=[openssl rand -base64 64]
  JWT_EXPIRATION=86400000

Port: 8081
Domain: api.seudominio.com
SSL: ✅ Enabled

→ Deploy
```

### 3️⃣ Frontend (10 minutos)

```
Dokploy → Create → Application

Nome: tecstock-frontend
Git: https://github.com/Picollin32/tecstock_front.git
Branch: main
Build: Dockerfile

Build Args:
  API_BASE_URL=https://api.seudominio.com

Port: 80
Domains: 
  - seudominio.com (SSL ✅)
  - www.seudominio.com (SSL ✅)

→ Deploy
```

---

## 🌐 DNS (Hostinger)

```
Registro A:
  @ → [IP do VPS]
  www → [IP do VPS]
  api → [IP do VPS]

Aguardar propagação: 1-2 horas
```

---

## ✅ Testar

```bash
# Backend
https://api.seudominio.com/actuator/health
→ {"status":"UP"}

# Frontend
https://seudominio.com
→ Tela de login
```

---

## 📋 Credenciais para Gerar

```powershell
# Senha do Banco (PowerShell)
-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | % {[char]$_})

# JWT Secret (qualquer terminal com OpenSSL)
openssl rand -base64 64
```

---

## 🔧 Comandos Úteis

```bash
# Ver logs
Dokploy → Application → Logs

# Redeploy após alteração
Dokploy → Application → Redeploy

# Backup banco
Dokploy → tecstock-db → Backups
```

---

## 🆘 Problemas Comuns

| Problema | Solução |
|----------|---------|
| Backend não conecta ao banco | Verificar DB_URL: `jdbc:postgresql://tecstock-db:5432/TecStock` |
| Frontend erro 404 na API | Verificar API_BASE_URL no build args |
| SSL não funciona | Aguardar propagação DNS (1-2h) |
| Container reiniciando | Ver logs: Dokploy → Logs |

---

## 📖 Guia Completo

Para instruções detalhadas, veja: [DOKPLOY_GUIDE.md](./DOKPLOY_GUIDE.md)

---

**Tempo total estimado:** 30-40 minutos + propagação DNS

Bom deploy! 🚀
