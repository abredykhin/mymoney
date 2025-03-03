FROM node:21-alpine

# Use ARG to accept build-time variables
ARG NODE_ENV=production
ENV NODE_ENV=$NODE_ENV

# Add this line for debugging
RUN echo "Building with NODE_ENV=$NODE_ENV"

WORKDIR /opt/server

COPY . . 

RUN npm cache clean --force && rm -rf node_modules && npm install
RUN npm install -g knex

# Ensure logs directory exists
RUN mkdir -p /opt/server/logs

CMD ["npm", "start"]
