FROM docker.io/library/node:22.21.1-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund
COPY . .
EXPOSE 3004
CMD ["node", "server.js"]
