const express = require('express');
const morgan = require('morgan');
const cors = require('cors');
const path = require('path');
const http = require('http');
const debug = require('debug')('app');
require('dotenv').config();

// Routes
const auth = require('./routes/auth');
const banks = require('./routes/banks');
const budget = require('./routes/budget');
const transactions = require('./routes/transactions');
const linkTokens = require('./routes/linkTokens');
const webhook = require('./routes/webhook');
const items = require('./routes/items');

// Middleware and services
const { errorHandler } = require('./middleware');
const { createAndInitializeRefreshService } = require('./controllers/dataRefresher');

// Configuration
const app = express();
const PORT = process.env.PORT || 3000;
const isProduction = process.env.APP_ENV === 'production';
let refreshServiceInstance; 

/**
 * Configures Express middleware and routes
 */
const configureApp = () => {
  // Logging middleware based on environment
  app.use(morgan(isProduction ? 'common' : 'dev'));

  // Standard middleware
  app.use(cors());
  app.use(express.json());
  app.use(express.urlencoded({ extended: false }));
  app.disable('etag');

  // Serve static files
  app.use('/.well-known', express.static(path.join(__dirname, 'static')));

  // Basic status endpoint
  app.get('/status', (req, res) => {
    res.send({ Status: 'Running' });
  });

  // Register routes
  app.use('/users', auth);
  app.use('/link-token', linkTokens);
  app.use('/plaid', webhook);

  // Routes requiring authentication
  app.use('/items', items);
  app.use('/banks', banks);
  app.use('/transactions', transactions);
  app.use('/budget', budget);

  // Error handling
  app.use((err, req, res, next) => {
    console.error('Error caught:', err);
    errorHandler(err, req, res, next);
  });
};

/**
 * Starts HTTP server
 */
const startHttpServer = () => {
  return new Promise(resolve => {
    const server = http.createServer(app).listen(PORT, () => {
      debug(`HTTP Server running on port ${PORT}`);
      resolve(server);
    });
  });
};


/**
 * Initializes services and scheduled tasks
 */
const initializeServices = async () => {
  if (isProduction) {
    try {      
      debug('Initializing RefreshService...');
      refreshServiceInstance = await createAndInitializeRefreshService(); 

      await refreshServiceInstance.initializeScheduledRefreshes();
      debug('Refresh services initialized successfully!');
    } catch (err) {
      console.error('Failed to initialize refresh service:', err);
      process.exit(1); 
    }
  } else {
    debug('Skipping refresh service initialization in non-production mode.');
  }
};

/**
 * Main application startup function
 */
const startApp = async () => {
  // Configure the Express app
  configureApp();

  // Start servers based on environment
  debug(`Starting in ${isProduction ? 'production' : 'dev'} mode`);

  // Only start HTTP server - Nginx will handle HTTPS
  await startHttpServer();

  // Initialize background services
  await initializeServices();
};

// Start the application
startApp().catch(err => {
  console.error('Failed to start application:', err);
  process.exit(1);
});

module.exports = app;
