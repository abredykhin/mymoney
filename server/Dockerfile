FROM node:21-alpine

COPY ["package.json", "/opt/server/"]
COPY ["package-lock.json", "/opt/server/"]

WORKDIR /opt/server
COPY ["package.json", "package-lock.json", "./"]

RUN npm cache clean --force && rm -rf node_modules && npm install

COPY . .

# Ensure logs directory exists
RUN mkdir -p /opt/server/logs

CMD ["npm", "start"]
