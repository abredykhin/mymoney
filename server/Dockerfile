FROM node:21-alpine

ENV NODE_ENV=production

COPY ["package.json", "/opt/server/"]
COPY ["package-lock.json", "/opt/server/"]

WORKDIR /opt/server
COPY ["package.json", "package-lock.json", "./"]

RUN npm cache clean --force && rm -rf node_modules && npm install
RUN npm install -g knex
# Run migrations
RUN knex migrate:latest  

COPY . .

# Ensure logs directory exists
RUN mkdir -p /opt/server/logs

CMD ["npm", "start"]
