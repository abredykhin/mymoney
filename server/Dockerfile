FROM node:21-alpine

# Use ARG to accept build-time variables
ARG NODE_ENV=production
ENV NODE_ENV=$NODE_ENV

# Add this line for debugging
RUN echo "Building with NODE_ENV=$NODE_ENV"

WORKDIR /opt/server

# Copy package files first for better layer caching
COPY package*.json ./

# Install dependencies
RUN npm install

# Then copy the rest of the application
COPY . .

# Ensure logs directory exists
RUN mkdir -p /opt/server/logs

CMD ["npm", "start"]
