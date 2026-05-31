FROM node:20-alpine
WORKDIR /app

# 의존성 먼저 (레이어 캐시)
COPY package.json ./
RUN npm install --omit=dev

# 앱 소스
COPY server.js ./
COPY public ./public

ENV PORT=8080
EXPOSE 8080

# 비루트 실행
USER node

CMD ["node", "server.js"]
