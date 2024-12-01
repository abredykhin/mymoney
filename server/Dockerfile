FROM node:21-alpine

ENV NODE_ENV=production

WORKDIR /opt/server

COPY . . 

RUN npm cache clean --force && rm -rf node_modules && npm install
RUN npm install -g knex

# Ensure logs directory exists
RUN mkdir -p /opt/server/logs

CMD ["npm", "start"]
