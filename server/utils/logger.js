const winston = require('winston');
const DailyRotateFile = require('winston-daily-rotate-file');
const path = require('path');
const fs = require('fs');
const debug = require('debug');

// Format configuration
const alignedWithColorsAndTime = winston.format.combine(
  winston.format.colorize(),
  winston.format.timestamp(),
  winston.format.splat(),
  winston.format.printf(
    info => `${info.timestamp} ${info.level}: ${info.message}`
  )
);

// Initialize the logger with basic configuration
const logger = winston.createLogger({
  level: 'info',
  format: alignedWithColorsAndTime,
  transports: [],
});

// Add file transports only in production
if (process.env.NODE_ENV === 'production') {
  const logDir = '/opt/server/logs';
  // Create log directory if it doesn't exist
  if (!fs.existsSync(logDir)) {
    fs.mkdirSync(logDir, { recursive: true });
  }
  // Add file transports
  logger.add(
    new winston.transports.File({
      filename: path.join(logDir, 'error.log'),
      level: 'error',
    })
  );
  logger.add(
    new DailyRotateFile({
      filename: path.join(logDir, '%DATE%-app.log'),
      datePattern: 'YYYY-MM-DD',
      maxSize: '20m',
      maxFiles: '14d',
    })
  );
  // Add exception and rejection handlers
  logger.exceptions.handle(
    new winston.transports.File({
      filename: path.join(logDir, 'exceptions.log'),
    })
  );
  logger.rejections.handle(
    new winston.transports.File({
      filename: path.join(logDir, 'rejections.log'),
    })
  );
  // Always add console transport for errors even in production
  logger.add(
    new winston.transports.Console({
      format: alignedWithColorsAndTime,
      level: 'error', // Only log errors to console in production
    })
  );
}

// Add full console transport for non-production environments
if (process.env.NODE_ENV !== 'production') {
  logger.add(
    new winston.transports.Console({
      format: alignedWithColorsAndTime,
    })
  );
}

// Add exception and rejection handlers to console in all environments
logger.exceptions.handle(
  new winston.transports.Console({
    format: alignedWithColorsAndTime,
  })
);
logger.rejections.handle(
  new winston.transports.Console({
    format: alignedWithColorsAndTime,
  })
);

// Cache for debuggers to avoid creating duplicates
const debugInstances = {};

// Create a factory function that returns the logger interface
const createLogger = function (namespace) {
  // Create or get cached debug instance
  if (!debugInstances[namespace]) {
    debugInstances[namespace] = debug(namespace);
  }
  const debugInstance = debugInstances[namespace];

  // Return logger object with all methods
  return {
    debug: (message, ...args) => {
      debugInstance(message, ...args);
    },

    info: (message, ...args) => {
      logger.info(`[${namespace}] ${message}`, ...args);
    },

    warn: (message, ...args) => {
      logger.warn(`[${namespace}] ${message}`, ...args);
    },

    error: (message, ...args) => {
      logger.error(`[${namespace}] ${message}`, ...args);
    },
  };
};

// Make sure we're exporting a function
module.exports = createLogger;
