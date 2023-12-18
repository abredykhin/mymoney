FROM node:latest

COPY ["package.json", "/opt/server/"]
COPY ["package-lock.json", "/opt/server/"]

WORKDIR /opt/server

RUN npm install

COPY ["./", "/opt/server/"]

CMD ["npm", "start"]