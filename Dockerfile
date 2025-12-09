# Multi-stage build para Flutter Web

# Stage 1: Build do Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

# Copiar arquivos de dependências
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copiar o resto do código
COPY . .

# Build para web com release mode
RUN flutter build web --release

# Stage 2: Servidor Nginx
FROM nginx:alpine
WORKDIR /usr/share/nginx/html

# Remover conteúdo padrão do nginx
RUN rm -rf ./*

# Copiar build do Flutter
COPY --from=build /app/build/web .

# Copiar configuração customizada do nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expor porta
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

# Comando para iniciar nginx
CMD ["nginx", "-g", "daemon off;"]
