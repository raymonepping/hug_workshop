# backend/Dockerfile
FROM node:20-alpine
WORKDIR /app

# Copy only manifests first for better caching
COPY package*.json ./
RUN npm ci --omit=dev

# Copy source
COPY . .

EXPOSE 3004
# No .env baked in; you pass --env-file at runtime
CMD ["node", "server.js"]
