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

# Argumento para a URL da API (pode ser sobrescrito no build)
ARG API_BASE_URL=https://api.tecstock.app

# Build da aplicação web para produção (sem símbolos de debug)
# Passa a URL da API como variável de ambiente em tempo de compilação
RUN flutter build web --release \
    --base-href=/ \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --dart-define=FLUTTER_WEB_CANVASKIT_URL=https://cdn.jsdelivr.net/npm/canvaskit-wasm@0.37.0/bin/ && \
    mkdir -p build/web/assets/images && \
    cp -r build/web/assets/assets/images/* build/web/assets/images/ 2>/dev/null || true && \
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

# Inicia o servidor com rewrite para assets
CMD ["serve", "-s", "build/web", "-l", "3000", "--single"]
