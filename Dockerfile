# Dockerfile para Flutter Web
# Stage 1: Build da aplicação Flutter
FROM ghcr.io/cirruslabs/flutter:stable AS build-env

# Define o diretório de trabalho
WORKDIR /app

# Copia os arquivos de configuração do projeto
COPY pubspec.yaml pubspec.lock ./

# Baixa as dependências
RUN flutter pub get --no-example

# Copia todo o código fonte
COPY . .

# Build da aplicação web para produção (sem símbolos de debug)
RUN flutter build web --release --dart-define=FLUTTER_WEB_CANVASKIT_URL=https://cdn.jsdelivr.net/npm/canvaskit-wasm@0.37.0/bin/ && \
    rm -rf .dart_tool .git .gitignore

# Stage 2: Servidor Node.js leve para servir arquivos estáticos
FROM node:20-alpine

# Define o diretório de trabalho
WORKDIR /app

# Instala um servidor HTTP simples e rápido
RUN npm install -g serve

# Copia os arquivos buildados do stage anterior
COPY --from=build-env /app/build/web ./build/web

# Expõe a porta 3000
EXPOSE 3000

# Inicia o servidor
CMD ["serve", "-s", "build/web", "-l", "3000"]
