FROM node:21-alpine

COPY ["package.json", "/opt/server/"]
COPY ["package-lock.json", "/opt/server/"]

WORKDIR /opt/server

RUN npm cache clean --force && rm -rf node_modules && npm install

COPY ["./", "/opt/server/"]

CMD ["npm", "start"]
