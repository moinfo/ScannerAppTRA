const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const salesRoutes = require('./sales_api');

const app = express();
const PORT = process.env.PORT || 8000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// API routes
app.use('/api/sales', salesRoutes);

// Root route
app.get('/', (req, res) => {
  res.json({
    message: 'TRA Scanner App API is running',
    version: '1.0.0'
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});

module.exports = app;