const express = require('express');
const morgan = require('morgan');
const cors = require('cors');
const fs = require('fs');
const auth = require('./routes/auth');
const banks = require('./routes/banks');
const budget = require('./routes/budget');
const transactions = require('./routes/transactions');
const linkTokens = require('./routes/linkTokens');
const webhook = require('./routes/webhook');
const items = require('./routes/items');
const { errorHandler } = require('./middleware');
const path = require('path'); // Add this line
const http = require('http');
const https = require('https');
const debug = require('debug')('app');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;
const isProduction = process.env.APP_ENV === 'production';

// Serve static files
app.use('/.well-known', express.static(path.join(__dirname, 'static')));

// Function to start the HTTP server
const startHttpServer = () => {
  http.createServer(app).listen(PORT, () => {
    debug(`HTTP Server running on port ${PORT}`);
  });
};

// Function to start the HTTPS server
const startHttpsServer = () => {
  const certKey = process.env.SSL_KEY_PATH; // Read from .env
  const certFullChain = process.env.SSL_CERT_PATH; // Read from .env

  // Check if certificate files exist
  if (fs.existsSync(certKey) && fs.existsSync(certFullChain)) {
    const options = {
      key: fs.readFileSync(certKey),
      cert: fs.readFileSync(certFullChain),
    };

    https.createServer(options, app).listen(443, () => {
      debug('HTTPS Server running on port 443');
    });
  } else {
    debug('SSL certificates not found. HTTPS server not started.');
  }
};

// Start both HTTP and HTTPS
if (isProduction) {
  debug('Starting in production mode');
  startHttpsServer();
  startHttpServer(); // Optionally serve HTTP for non-SSL requests
} else {
  debug('Starting in dev mode');
  startHttpServer(); // In development, only serve HTTP
}

if (isProduction) {
  app.use(morgan('common'));
} else {
  app.use(morgan('dev'));
}
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.disable('etag');

app.get('/status', (request, response) => {
  const status = {
    Status: 'Running',
  };

  response.send(status);
});

app.use('/users', auth);
app.use('/link-token', linkTokens);
app.use('/plaid', webhook);
// The rest of routes require token
app.use('/items', items);
app.use('/banks', banks);
app.use('/transactions', transactions);
app.use('/budget', budget);

app.use((err, req, res, next) => {
  console.error('Error caught:', err);
  errorHandler(err, req, res, next);
});
